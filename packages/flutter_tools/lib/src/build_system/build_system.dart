// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:pool/pool.dart';

import '../base/file_system.dart';
import '../base/platform.dart';
import '../build_info.dart';
import '../cache.dart';
import '../convert.dart';
import '../globals.dart';

/// An input function produces a list of additional input files for an
/// environment.
typedef InputFunction = List<FileSystemEntity> Function(Environment environment);

/// The function signature of a build target which can be invoked to perform
/// the underlying task.
typedef BuildInvocation = Future<void> Function(List<FileSystemEntity> inputs, Environment environment);

/// An exception thrown when a rule declares an output that was not produced
/// by the invocation.
class MissingOutputException implements Exception {
  const MissingOutputException(this.file, this.target);

  /// The file we expected to find.
  final File file;

  /// The name of the target this file should have been output from.
  final String target;

  @override
  String toString() {
    return '${file.path} was declared as an output, but was not generated by '
    'the invocation. Check the definition of target:$target for errors';
  }
}

/// An exception thrown when a rule declares an input that does not exist on
/// disk.
class MissingInputException implements Exception {
  const MissingInputException(this.file, this.target);

  /// The file we expected to find.
  final File file;

  /// The name of the target this file should have been output from.
  final String target;

  @override
  String toString() {
    return '${file.path} was declared as an input, but does not exist on '
    'disk. Check the definition of target:$target for errors';
  }
}

/// A visitor for the [Source] types.
abstract class SourceVisitor {
  /// Visit a source which contains a file uri with some magic environment
  /// variables.
  void visitPattern(String pattern);

  /// Visit a source which contains a function.
  void visitFunction(InputFunction function);
}

/// Collects sources for a [Target] into a single list of [FileSystemEntities].
class SourceCollector extends SourceVisitor {
  /// Create a new [SourceCollector] from an [Environment].
  SourceCollector(this.environment);

  /// The current environment.
  final Environment environment;

  /// The entities are populated after visiting each source.
  final List<FileSystemEntity> sources = <FileSystemEntity>[];

  @override
  void visitFunction(InputFunction function) {
    sources.addAll(function(environment));
  }

  @override
  void visitPattern(String pattern) {
    // perform substitution of the environmental values and then
    // of the local values.
    final String value = pattern
      .replaceAll('{PROJECT_DIR}', environment.projectDir.absolute.uri.toString())
      .replaceAll('{BUILD_DIR}', environment.buildDir.absolute.uri.toString())
      .replaceAll('{CACHE_DIR}', environment.cacheDir.absolute.uri.toString())
      .replaceAll('{COPY_DIR}', environment.copyDir.absolute.uri.toString())
      .replaceAll('{platform}', getNameForTargetPlatform(environment.targetPlatform))
      .replaceAll('{mode}', getNameForBuildMode(environment.buildMode));
    final String filePath = Uri.parse(value).toFilePath(windows: platform.isWindows);
    if (value.endsWith(platform.pathSeparator)) {
      sources.add(fs.directory(fs.path.normalize(filePath)));
    } else {
      sources.add(fs.file(fs.path.normalize(filePath)));
    }
  }
}

/// A description of an input or output of a [Target].
abstract class Source {
  /// This source is a file-uri which contains some references to magic
  /// environment variables.
  const factory Source.pattern(String pattern) = _PatternSource;

  /// This source is produced by invoking the provided function.
  const factory Source.function(InputFunction function) = _FunctionSource;

  /// Visit the particular source type.
  void accept(SourceVisitor visitor);
}

class _FunctionSource implements Source {
  const _FunctionSource(this.value);

  final InputFunction value;

  @override
  void accept(SourceVisitor visitor) => visitor.visitFunction(value);
}

class _PatternSource implements Source {
  const _PatternSource(this.value);

  final String value;

  @override
  void accept(SourceVisitor visitor) => visitor.visitPattern(value);
}

/// A Target describes a single step during a flutter build.
///
/// The target inputs are required to be files discoverable via a combination
/// of at least one of the magic ambient value and zero or more magic local
/// values.
///
/// To determine if a target needs to be executed, the [BuildSystem] performs
/// an md5 hash of the file contents.
///
/// Because the set of inputs or outputs might change based on the invocation,
/// each target stores a JSON file containing the input hash for each input.
/// The name of each stamp is the target name joined with target platform and
/// mode. The output files are also stored to protect against deleted files.
///
///
///  file: `example_target.debug.android_arm64`
///
/// {
///   "build_number": 12345,
///   "inputs": [
///      ["absolute/path/foo", "abcdefg"],
///      ["absolute/path/bar", "12345g"],
///      ...
///    ],
///    "outputs": [
///      "absolute/path/fizz"
///    ]
/// }
///
/// We don't re-run if the target or mode change because we expect that these
/// invocations will produce different outputs. For example, if I separately run
/// a target which produces the gen_snapshot output for `android_arm` and
/// `android_arm64`, this should not produce files which overwrite eachother.
/// This is not currently the case and will need to be adjusted.
///
/// For more information on the `build_number` field, see
/// [Environment.buildNumber].
class Target {
  const Target({
    @required this.name,
    @required this.inputs,
    @required this.outputs,
    @required this.invocation,
    this.dependencies,
    this.platforms,
    this.modes,
    this.phony = false,
  });

  final String name;
  final List<Target> dependencies;
  final List<Source> inputs;
  final List<Source> outputs;
  final BuildInvocation invocation;
  final bool phony;

  /// The target platform this target supports.
  ///
  /// If left empty, this supports all platforms.
  final List<TargetPlatform> platforms;

  /// The build modes this target supports.
  ///
  /// If left empty, this supports all modes.
  final List<BuildMode> modes;

  /// Check if we can skip the target invocation and collect shas for all inputs.
  _InvocationEvaluation _canSkipInvocation(List<FileSystemEntity> inputs, Environment environment) {
    // A phony target can never be skipped. This might be necessary if we're
    // not aware of its inputs or outputs, or they are tracked by a separate
    //  system.
    if (phony) {
      return _InvocationEvaluation(false, const <String, String>{});
    }

    bool canSkip = true;
    final File stamp = _findStampFile(name, environment);
    final Map<String, String> previousStamps = <String, String>{};
    final Map<String, String> currentStamps = <String, String>{};

    // If the stamp file doesn't exist, we haven't run this step before.
    if (!stamp.existsSync()) {
      canSkip = false;
    } else {
      final String content = stamp.readAsStringSync();
      // Something went wrong writing the stamp file.
      if (content == null || content.isEmpty) {
        stamp.deleteSync();
        canSkip = false;
      } else {
        final Map<String, Object> values = json.decode(content);
        for (List<Object> pair in values['inputs']) {
          assert(pair.length == 2);
          previousStamps[pair.first] = pair.last;
        }
        // Check that the last set of output files have not been deleted since the
        // last invocation. While the set of output files can vary based on inputs,
        // it should be safe to skip if none of the inputs changed.
        for (String absoluteOutputPath in values['outputs']) {
          final FileStat fileStat = fs.statSync(absoluteOutputPath);
          // Case 5: output was deleted for some reason.
          if (fileStat == null) {
            canSkip = false;
          }
        }
      }
    }

    // We've added or removed files, so we can't skip.
    if (inputs.length != previousStamps.length) {
      canSkip = false;
    }

    // Check that the current input files have not been changed since the last
    // invocation.
    for (FileSystemEntity inputEntity in inputs) {
      if (!inputEntity.existsSync()) {
        throw MissingInputException(inputEntity, name);
      }
      final String absolutePath = inputEntity.absolute.path;
      final String previousSha = previousStamps[absolutePath];
      // TODO(jonahwilliams): implement framework copy in dart so we don't need
      // to shell out to cp.
      String currentSha;
      if (inputEntity is File) {
        currentSha = md5.convert(inputEntity.readAsBytesSync()).bytes.toString();
      } else if (inputEntity is Directory) {
        // In case of a directory use the stat for now.
        currentSha = inputEntity.statSync().modified.toIso8601String();
      }
      // Shas are not identical or old sha was missing.
      if (currentSha != previousSha) {
        canSkip = false;
      }
      currentStamps[absolutePath] = currentSha;
    }
    return _InvocationEvaluation(canSkip, currentStamps);
  }

  void writeStamp(
    List<FileSystemEntity> inputs,
    List<FileSystemEntity> outputs,
    Environment environment,
    Map<String, String> shas,
  ) {
    if (phony) {
      return;
    }
    final File stamp = _findStampFile(name, environment);
    final List<List<Object>> inputStamps = <List<Object>>[];
    for (FileSystemEntity input in inputs) {
      assert(shas[input.absolute.path] != null);
      inputStamps.add(<Object>[
        input.absolute.path,
        shas[input.absolute.path],
      ]);
    }
    final List<String> outputStamps = <String>[];
    for (FileSystemEntity output in outputs) {
      if (!output.existsSync()) {
        throw Exception('$name: Did not produce expected output ${output.path}');
      }
      outputStamps.add(output.absolute.path);
    }
    final Map<String, Object> result = <String, Object>{
      'inputs': inputStamps,
      'outputs': outputStamps,
    };
    if (!stamp.existsSync()) {
      stamp.createSync(recursive: true);
    }
    stamp.writeAsStringSync(json.encode(result));
  }

  /// Resolve the set of input patterns and functions into a concrete list of
  /// files.
  List<FileSystemEntity> resolveInputs(
    Environment environment,
  ) {
    return _resolveConfiguration(inputs, environment);
  }

  /// Find the current set of declared outputs, including wildcard directories.
  List<FileSystemEntity> resolveOutputs(
    Environment environment,
  ) {
    return _resolveConfiguration(outputs, environment);
  }

  /// Performs a fold across this target and its dependencies.
  T fold<T>(T initialValue, T combine(T previousValue, Target target)) {
    final T dependencyResult = dependencies.fold(initialValue, (T prev, Target t) => t.fold(prev, combine));
    return combine(dependencyResult, this);
  }

  /// Convert the target to a JSON structure appropriate for consumption by
  /// external systems.
  ///
  /// This requires an environment variable to resolve the paths of inputs
  /// and outputs.
  Map<String, Object> toJson(Environment environment) {
    return <String, Object>{
      'name': name,
      'phony': phony,
      'dependencies': dependencies.map((Target target) => target.name).toList(),
      'inputs': resolveInputs(environment).map((FileSystemEntity file) => file.absolute.path).toList(),
      'outputs': resolveOutputs(environment).map((FileSystemEntity file) => file.absolute.path).toList(),
    };
  }

  /// Locate the stamp file for a particular target `name` and `environment`.
  static File _findStampFile(String name, Environment environment) {
    final String platform = getNameForTargetPlatform(environment.targetPlatform);
    final String mode = getNameForBuildMode(environment.buildMode);
    final String fileName = '$name.$mode.$platform';
    return environment.stampDir.childFile(fileName);
  }

  static List<FileSystemEntity> _resolveConfiguration(List<Source> config, Environment environment) {
    final SourceCollector collector = SourceCollector(environment);
    for (Source source in config)  {
      source.accept(collector);
    }
    return collector.sources;
  }
}

class _InvocationEvaluation {
  _InvocationEvaluation(this.canSkip, this.shas);

  /// Whether this invocation can be skipped.
  final bool canSkip;

  /// The sha for each input file.
  final Map<String, String> shas;
}

/// The [Environment] contains specical paths configured by the user.
///
/// These are defined by a top level configuration or build arguments
/// passed to the flutter tool. The intention is that  it makes it easier
/// to integrate it into existing arbitrary build systems, while keeping
/// the build backwards compatible.
///
/// # Magic Ambient Values:
///
/// ## PROJECT_DIR
///
///   The root of the flutter project where a pubspec and dart files can be
///   found.
///
///   This value is computed from the location of the relevant pubspec. Most
///   other ambient value defaults are defined relative to this directory.
///
/// ## BUILD_DIR
///
///   the root of the output directory where build step intermediates and
///   products are written.
///
///   Defaults to {PROJECT_DIR}/build/
///
/// ## STAMP_DIR
///
/// The root of the directory where timestamp output is stored. Defaults to
/// {PROJECT_DIR}/.stamp/
///
/// # Magic local values
///
/// These are defined by the particular invocation of the target itself.
///
/// ## platform
///
/// The current platform the target is being executed for. Certain targets do
/// not require a target at all, in which case this value will be null and
/// substitution will fail.
///
/// ## build_mode
///
/// The current build mode the target is being executed for, one of `release`,
/// `debug`, and `profile`. Defaults to `debug` if not specified.
///
/// # Flavors
///
/// TBD based on understanding how these work now.
class Environment {
  /// Create a new [Environment] object.
  ///
  /// Only [projectDir] is required. The remaining environment locations have
  /// defaults based on it.
  ///
  /// If [targetPlatform] and/or [buildMode] are not defined, they will often
  /// default to `any`.
  factory Environment({
    @required Directory projectDir,
    Directory stampDir,
    Directory buildDir,
    Directory cacheDir,
    Directory copyDir,
    TargetPlatform targetPlatform,
    BuildMode buildMode,
  }) {
    assert(projectDir != null);
    return Environment._(
      projectDir: projectDir,
      stampDir: stampDir ?? projectDir.childDirectory('build'),
      buildDir: buildDir ?? projectDir.childDirectory('build'),
      cacheDir: cacheDir ?? Cache.instance.getCacheArtifacts().childDirectory('engine'),
      copyDir: copyDir ?? projectDir
        .childDirectory(getHostFolderForTargetPlaltform(targetPlatform))
        .childDirectory('flutter'),
      targetPlatform: targetPlatform,
      buildMode: buildMode,
    );
  }

  Environment._({
    @required this.projectDir,
    @required this.stampDir,
    @required this.buildDir,
    @required this.cacheDir,
    @required this.copyDir,
    @required this.targetPlatform,
    @required this.buildMode,
  });

  /// The `PROJECT_DIR` magic environment varaible.
  final Directory projectDir;

  /// The `STAMP_DIR` magic environment variable.
  ///
  /// Defaults to `{PROJECT_ROOT}/build`.
  final Directory stampDir;

  /// The `BUILD_DIR` magic environment variable.
  ///
  /// Defaults to `{PROJECT_ROOT}/build`.
  final Directory buildDir;

  /// The `CACHE_DIR` magic environment variable.
  ///
  /// Defaults to `{FLUTTER_ROOT}/bin/cache`.
  final Directory cacheDir;

  /// The `COPY_DIR` magic environment variable.
  ///
  /// Defaults to `{PROJECT_ROOT}/{host_folder}/flutter`
  final Directory copyDir;

  /// The currently selected build mode.
  final BuildMode buildMode;

  /// The current target platform, or `null` if none.
  final TargetPlatform targetPlatform;
}

/// The build system is responsible for invoking and ordering [Target]s.
class BuildSystem {
  const BuildSystem([this.targets]);

  final List<Target> targets;

  /// Build the target `name` and all of its dependencies.
  Future<void> build(
    String name,
    Environment environment,
  ) async {
    final Target target = _getNamedTarget(name);

    // Initialize any destination directories that don't currently exist.
    if (!environment.cacheDir.existsSync()) {
      environment.cacheDir.createSync(recursive: true);
    }
    if (!environment.copyDir.existsSync()) {
      environment.copyDir.createSync(recursive: true);
    }

    checkCycles(target);
    final Pool resourcePool = Pool(platform?.numberOfProcessors ?? 1);
    final Set<Target> completed = <Target>{};

    Future<void> invokeTarget(Target target) async {
      if (completed.contains(target)) {
        return;
      }
      await Future.wait(target.dependencies.map(invokeTarget));
      final PoolResource resource = await resourcePool.request();
      final List<FileSystemEntity> inputs = target.resolveInputs(environment);
      final _InvocationEvaluation evaluation = target._canSkipInvocation(inputs, environment);
      if (evaluation.canSkip) {
        printTrace('Skipping target: ${target.name}');
      } else {
        printTrace('${target.name}: Starting');
        await target.invocation(inputs, environment);

        printTrace('${target.name}: Complete');
        final List<FileSystemEntity> outputs = target.resolveOutputs(environment);
        target.writeStamp(inputs, outputs, environment, evaluation.shas);
      }
      resource.release();
    }
    await invokeTarget(target);
  }

  /// Describe the target `name` and all of its dependencies.
  List<Map<String, Object>> describe(
    String name,
    Environment environment,
  ) {
    final Target target = _getNamedTarget(name);
    checkCycles(target);
    // Cheat a bit and re-use the same map.
    Map<String, Map<String, Object>> fold(Map<String, Map<String, Object>> accumulation, Target current) {
      accumulation[current.name] = current.toJson(environment);
      return accumulation;
    }
    final Map<String, Map<String, Object>> result = <String, Map<String, Object>>{};
    final Map<String, Map<String, Object>> targets = target.fold(result, fold);
    return targets.values.toList();
  }

  // Returns the corresponding target or throws.
  Target _getNamedTarget(String name) {
    final Target target = targets.firstWhere((Target target) => target.name  == name, orElse: () => null);
    if (target == null) {
      throw Exception('No registered target named $name.');
    }
    return target;
  }
}

/// Check if there are any dependency cycles in the target.
///
/// Throws a [CycleException] if one is encountered.
void checkCycles(Target initial) {
  void checkInternal(Target target, Set<Target> visited, Set<Target> stack) {
    if (stack.contains(target)) {
      throw CycleException(stack..add(target));
    }
    if (visited.contains(target)) {
      return;
    }
    visited.add(target);
    stack.add(target);
    for (Target dependency in target.dependencies) {
      checkInternal(dependency, visited, stack);
    }
    stack.remove(target);
  }
  checkInternal(initial, <Target>{}, <Target>{});
}

/// An exception thrown if we detect a cycle in the dependencies of a target.
class CycleException implements Exception {
  CycleException(this.targets);

  final Set<Target> targets;

  @override
  String toString() => 'Dependency cycle detected in build: '
    '${targets.map((Target target) => target.name).join(' -> ')}';
}
