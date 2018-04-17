// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../android/android_sdk.dart';
import '../artifacts.dart';
import '../base/build.dart';
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/process.dart';
import '../base/process_manager.dart';
import '../base/utils.dart';
import '../build_info.dart';
import '../compile.dart';
import '../dart/package_map.dart';
import '../globals.dart';
import '../resident_runner.dart';
import '../runner/flutter_command.dart';
import 'build.dart';

// Files generated by the ahead-of-time snapshot builder.
const List<String> kAotSnapshotFiles = const <String>[
  'vm_snapshot_data', 'vm_snapshot_instr', 'isolate_snapshot_data', 'isolate_snapshot_instr',
];

class BuildAotCommand extends BuildSubCommand {
  BuildAotCommand({bool verboseHelp: false}) {
    usesTargetOption();
    addBuildModeFlags();
    usesPubOption();
    argParser
      ..addOption('output-dir', defaultsTo: getAotBuildDirectory())
      ..addOption('target-platform',
        defaultsTo: 'android-arm',
        allowed: <String>['android-arm', 'android-arm64', 'ios']
      )
      ..addFlag('interpreter')
      ..addFlag('quiet', defaultsTo: false)
      ..addFlag('preview-dart-2',
        defaultsTo: true,
        hide: !verboseHelp,
        help: 'Preview Dart 2.0 functionality.',
      )
      ..addMultiOption(FlutterOptions.kExtraFrontEndOptions,
        splitCommas: true,
        hide: true,
      )
      ..addMultiOption(FlutterOptions.kExtraGenSnapshotOptions,
        splitCommas: true,
        hide: true,
      )
      ..addFlag('prefer-shared-library',
        negatable: false,
        help: 'Whether to prefer compiling to a *.so file (android only).');
  }

  @override
  final String name = 'aot';

  @override
  final String description = "Build an ahead-of-time compiled snapshot of your app's Dart code.";

  @override
  Future<Null> runCommand() async {
    await super.runCommand();
    final String targetPlatform = argResults['target-platform'];
    final TargetPlatform platform = getTargetPlatformForName(targetPlatform);
    if (platform == null)
      throwToolExit('Unknown platform: $targetPlatform');

    final String typeName = artifacts.getEngineType(platform, getBuildMode());
    Status status;
    if (!argResults['quiet']) {
      status = logger.startProgress('Building AOT snapshot in ${getModeName(getBuildMode())} mode ($typeName)...',
          expectSlowOperation: true);
    }
    final String outputPath = await buildAotSnapshot(
      findMainDartFile(targetFile),
      platform,
      getBuildMode(),
      outputPath: argResults['output-dir'],
      interpreter: argResults['interpreter'],
      previewDart2: argResults['preview-dart-2'],
      extraFrontEndOptions: argResults[FlutterOptions.kExtraFrontEndOptions],
      extraGenSnapshotOptions: argResults[FlutterOptions.kExtraGenSnapshotOptions],
      preferSharedLibrary: argResults['prefer-shared-library'],
    );
    status?.stop();

    if (outputPath == null)
      throwToolExit(null);

    final String builtMessage = 'Built to $outputPath${fs.path.separator}.';
    if (argResults['quiet']) {
      printTrace(builtMessage);
    } else {
      printStatus(builtMessage);
    }
  }
}

String _getPackagePath(PackageMap packageMap, String package) {
  return fs.path.dirname(packageMap.map[package].toFilePath());
}

/// Build an AOT snapshot. Return null (and log to `printError`) if the method
/// fails.
Future<String> buildAotSnapshot(
  String mainPath,
  TargetPlatform platform,
  BuildMode buildMode, {
  String outputPath,
  bool interpreter: false,
  bool previewDart2: false,
  List<String> extraFrontEndOptions,
  List<String> extraGenSnapshotOptions,
  bool preferSharedLibrary: false,
}) async {
  outputPath ??= getAotBuildDirectory();
  try {
    return _buildAotSnapshot(
      mainPath,
      platform,
      buildMode,
      outputPath: outputPath,
      interpreter: interpreter,
      previewDart2: previewDart2,
      extraFrontEndOptions: extraFrontEndOptions,
      extraGenSnapshotOptions: extraGenSnapshotOptions,
      preferSharedLibrary: preferSharedLibrary,
    );
  } on String catch (error) {
    // Catch the String exceptions thrown from the `runCheckedSync` methods below.
    printError(error);
    return null;
  }
}

// TODO(cbracken): split AOT and Assembly AOT snapshotting logic and migrate to Snapshotter class.
Future<String> _buildAotSnapshot(
  String mainPath,
  TargetPlatform platform,
  BuildMode buildMode, {
  String outputPath,
  bool interpreter: false,
  bool previewDart2: false,
  List<String> extraFrontEndOptions,
  List<String> extraGenSnapshotOptions,
  bool preferSharedLibrary: false,
}) async {
  outputPath ??= getAotBuildDirectory();
  if (!isAotBuildMode(buildMode) && !interpreter) {
    printError('${toTitleCase(getModeName(buildMode))} mode does not support AOT compilation.');
    return null;
  }

  if (!(platform == TargetPlatform.android_arm ||
        platform == TargetPlatform.android_arm64 ||
        platform == TargetPlatform.ios)) {
    printError('${getNameForTargetPlatform(platform)} does not support AOT compilation.');
    return null;
  }

  final String genSnapshot = artifacts.getArtifactPath(Artifact.genSnapshot, platform, buildMode);

  final Directory outputDir = fs.directory(outputPath);
  outputDir.createSync(recursive: true);
  final String vmSnapshotData = fs.path.join(outputDir.path, 'vm_snapshot_data');
  final String vmSnapshotInstructions = fs.path.join(outputDir.path, 'vm_snapshot_instr');
  final String isolateSnapshotData = fs.path.join(outputDir.path, 'isolate_snapshot_data');
  final String isolateSnapshotInstructions = fs.path.join(outputDir.path, 'isolate_snapshot_instr');
  final String dependencies = fs.path.join(outputDir.path, 'snapshot.d');
  final String assembly = fs.path.join(outputDir.path, 'snapshot_assembly.S');
  final String assemblyO = fs.path.join(outputDir.path, 'snapshot_assembly.o');
  final String assemblySo = fs.path.join(outputDir.path, 'app.so');
  final bool compileToSharedLibrary =
      preferSharedLibrary && androidSdk.ndkCompiler != null;

  if (preferSharedLibrary && !compileToSharedLibrary) {
    printStatus(
        'Could not find NDK compiler. Not building in shared library mode');
  }

  final String vmEntryPoints = artifacts.getArtifactPath(
    Artifact.dartVmEntryPointsTxt,
    platform,
    buildMode,
  );
  final String ioEntryPoints = artifacts.getArtifactPath(Artifact.dartIoEntriesTxt, platform, buildMode);

  final List<String> entryPointsJsonFiles = <String>[];
  if (previewDart2 && !interpreter) {
    entryPointsJsonFiles.addAll(<String>[
      artifacts.getArtifactPath(Artifact.entryPointsJson, platform, buildMode),
      artifacts.getArtifactPath(Artifact.entryPointsExtraJson, platform, buildMode),
    ]);
  }

  final PackageMap packageMap = new PackageMap(PackageMap.globalPackagesPath);
  final String packageMapError = packageMap.checkValid();
  if (packageMapError != null) {
    printError(packageMapError);
    return null;
  }

  final String skyEnginePkg = _getPackagePath(packageMap, 'sky_engine');
  final String uiPath = fs.path.join(skyEnginePkg, 'lib', 'ui', 'ui.dart');
  final String vmServicePath = fs.path.join(skyEnginePkg, 'sdk_ext', 'vmservice_io.dart');

  final List<String> inputPaths = <String>[
    vmEntryPoints,
    ioEntryPoints,
    uiPath,
    vmServicePath,
    mainPath,
  ];

  inputPaths.addAll(entryPointsJsonFiles);

  final Set<String> outputPaths = new Set<String>();

  // These paths are used only on iOS.
  String snapshotDartIOS;

  switch (platform) {
    case TargetPlatform.android_arm:
    case TargetPlatform.android_arm64:
    case TargetPlatform.android_x64:
    case TargetPlatform.android_x86:
      if (compileToSharedLibrary) {
        outputPaths.add(assemblySo);
      } else {
        outputPaths.addAll(<String>[
          vmSnapshotData,
          isolateSnapshotData,
        ]);
      }
      break;
    case TargetPlatform.ios:
      snapshotDartIOS = artifacts.getArtifactPath(Artifact.snapshotDart, platform, buildMode);
      inputPaths.add(snapshotDartIOS);
      break;
    case TargetPlatform.darwin_x64:
    case TargetPlatform.linux_x64:
    case TargetPlatform.windows_x64:
    case TargetPlatform.fuchsia:
    case TargetPlatform.tester:
      assert(false);
  }

  final Iterable<String> missingInputs = inputPaths.where((String p) => !fs.isFileSync(p));
  if (missingInputs.isNotEmpty) {
    printError('Missing input files: $missingInputs');
    return null;
  }
  if (!processManager.canRun(genSnapshot)) {
    printError('Cannot locate the genSnapshot executable');
    return null;
  }

  final List<String> genSnapshotCmd = <String>[];
  // iOS gen_snapshot is a multi-arch binary. Running as an i386 binary will
  // generate armv7 code. Running as an x86_64 binary will generate arm64
  // code. /usr/bin/arch can be used to run binaries with the specified
  // architecture.
  //
  // TODO(cbracken): update the GenSnapshot class to handle AOT builds.
  if (platform == TargetPlatform.ios)
    genSnapshotCmd.addAll(<String>['arch', '-x86_64']);
  genSnapshotCmd.addAll(<String>[
    genSnapshot,
    '--await_is_keyword',
    '--vm_snapshot_data=$vmSnapshotData',
    '--isolate_snapshot_data=$isolateSnapshotData',
    '--packages=${packageMap.packagesPath}',
    '--url_mapping=dart:ui,$uiPath',
    '--url_mapping=dart:vmservice_io,$vmServicePath',
    '--print_snapshot_sizes',
    '--dependencies=$dependencies',
    '--causal_async_stacks',
  ]);

  if ((extraFrontEndOptions != null) && extraFrontEndOptions.isNotEmpty)
    printTrace('Extra front-end options: $extraFrontEndOptions');

  if ((extraGenSnapshotOptions != null) && extraGenSnapshotOptions.isNotEmpty) {
    printTrace('Extra gen-snapshot options: $extraGenSnapshotOptions');
    genSnapshotCmd.addAll(extraGenSnapshotOptions);
  }

  if (!interpreter) {
    genSnapshotCmd.add('--embedder_entry_points_manifest=$vmEntryPoints');
    genSnapshotCmd.add('--embedder_entry_points_manifest=$ioEntryPoints');
  }

  // iOS symbols used to load snapshot data in the engine.
  const String kVmSnapshotData = 'kDartVmSnapshotData';
  const String kIsolateSnapshotData = 'kDartIsolateSnapshotData';

  // iOS snapshot generated files, compiled object files.
  final String kVmSnapshotDataC = fs.path.join(outputDir.path, '$kVmSnapshotData.c');
  final String kIsolateSnapshotDataC = fs.path.join(outputDir.path, '$kIsolateSnapshotData.c');
  final String kVmSnapshotDataO = fs.path.join(outputDir.path, '$kVmSnapshotData.o');
  final String kIsolateSnapshotDataO = fs.path.join(outputDir.path, '$kIsolateSnapshotData.o');
  final String kApplicationKernelPath = fs.path.join(getBuildDirectory(), 'app.dill');

  switch (platform) {
    case TargetPlatform.android_arm:
    case TargetPlatform.android_arm64:
    case TargetPlatform.android_x64:
    case TargetPlatform.android_x86:
      if (compileToSharedLibrary) {
        genSnapshotCmd.add('--snapshot_kind=app-aot-assembly');
        genSnapshotCmd.add('--assembly=$assembly');
        outputPaths.add(assemblySo);
      } else {
        genSnapshotCmd.addAll(<String>[
          '--snapshot_kind=app-aot-blobs',
          '--vm_snapshot_instructions=$vmSnapshotInstructions',
          '--isolate_snapshot_instructions=$isolateSnapshotInstructions',
        ]);
      }
      if (platform == TargetPlatform.android_arm) {
        genSnapshotCmd.addAll(<String>[
          '--no-sim-use-hardfp', // Android uses the softfloat ABI.
          '--no-use-integer-division', // Not supported by the Pixel in 32-bit mode.
        ]);
      }
      break;
    case TargetPlatform.ios:
      if (interpreter) {
        genSnapshotCmd.add('--snapshot_kind=core');
        genSnapshotCmd.add(snapshotDartIOS);
        outputPaths.addAll(<String>[
          kVmSnapshotDataO,
          kIsolateSnapshotDataO,
        ]);
      } else {
        genSnapshotCmd.add('--snapshot_kind=app-aot-assembly');
        genSnapshotCmd.add('--assembly=$assembly');
        outputPaths.add(assemblyO);
      }
      break;
    case TargetPlatform.darwin_x64:
    case TargetPlatform.linux_x64:
    case TargetPlatform.windows_x64:
    case TargetPlatform.fuchsia:
    case TargetPlatform.tester:
      assert(false);
  }

  if (buildMode != BuildMode.release) {
    genSnapshotCmd.addAll(<String>[
      '--no-checked',
      '--conditional_directives',
    ]);
  }

  final String entryPoint = mainPath;
  final SnapshotType snapshotType = new SnapshotType(platform, buildMode);
  Future<Fingerprint> makeFingerprint() async {
    final Set<String> snapshotInputPaths = await readDepfile(dependencies)
      ..add(entryPoint)
      ..addAll(outputPaths);
    return Snapshotter.createFingerprint(snapshotType, entryPoint, snapshotInputPaths);
  }

  final File fingerprintFile = fs.file('$dependencies.fingerprint');
  final List<File> fingerprintFiles = <File>[fingerprintFile, fs.file(dependencies)]
    ..addAll(inputPaths.map(fs.file))
    ..addAll(outputPaths.map(fs.file));
  if (fingerprintFiles.every((File file) => file.existsSync())) {
    try {
      final String json = await fingerprintFile.readAsString();
      final Fingerprint oldFingerprint = new Fingerprint.fromJson(json);
      if (oldFingerprint == await makeFingerprint()) {
        printStatus('Skipping AOT snapshot build. Fingerprint match.');
        return outputPath;
      }
    } catch (e) {
      // Log exception and continue, this step is a performance improvement only.
      printTrace('Rebuilding snapshot due to fingerprint check error: $e');
    }
  }

  if (previewDart2) {
    final CompilerOutput compilerOutput = await compile(
      sdkRoot: artifacts.getArtifactPath(Artifact.flutterPatchedSdkPath),
      mainPath: mainPath,
      outputFilePath: kApplicationKernelPath,
      depFilePath: dependencies,
      extraFrontEndOptions: extraFrontEndOptions,
      linkPlatformKernelIn : true,
      aot : !interpreter,
      entryPointsJsonFiles: entryPointsJsonFiles,
      trackWidgetCreation: false,
    );
    mainPath = compilerOutput?.outputFilename;
    if (mainPath == null) {
      printError('Compiler terminated unexpectedly.');
      return null;
    }
    // Write path to frontend_server, since things need to be re-generated when
    // that changes.
    await outputDir.childFile('frontend_server.d')
        .writeAsString('frontend_server.d: ${artifacts.getArtifactPath(Artifact.frontendServerSnapshotForEngineDartSdk)}\n');

    genSnapshotCmd.addAll(<String>[
      '--reify-generic-functions',
      '--strong',
    ]);
  }

  genSnapshotCmd.add(mainPath);

  final RunResult results = await runAsync(genSnapshotCmd);
  if (results.exitCode != 0) {
    printError('Dart snapshot generator failed with exit code ${results.exitCode}');
    printError(results.toString());
    return null;
  }

  // Write path to gen_snapshot, since snapshots have to be re-generated when we roll
  // the Dart SDK.
  await outputDir.childFile('gen_snapshot.d').writeAsString('snapshot.d: $genSnapshot\n');

  // On iOS, we use Xcode to compile the snapshot into a dynamic library that the
  // end-developer can link into their app.
  if (platform == TargetPlatform.ios) {
    printStatus('Building App.framework...');

    final List<String> commonBuildOptions = <String>['-arch', 'arm64', '-miphoneos-version-min=8.0'];

    if (interpreter) {
      await runCheckedAsync(<String>['mv', vmSnapshotData, fs.path.join(outputDir.path, kVmSnapshotData)]);
      await runCheckedAsync(<String>['mv', isolateSnapshotData, fs.path.join(outputDir.path, kIsolateSnapshotData)]);

      await runCheckedAsync(<String>[
        'xxd', '--include', kVmSnapshotData, fs.path.basename(kVmSnapshotDataC)
      ], workingDirectory: outputDir.path);
      await runCheckedAsync(<String>[
        'xxd', '--include', kIsolateSnapshotData, fs.path.basename(kIsolateSnapshotDataC)
      ], workingDirectory: outputDir.path);

      await runCheckedAsync(<String>['xcrun', 'cc']
        ..addAll(commonBuildOptions)
        ..addAll(<String>['-c', kVmSnapshotDataC, '-o', kVmSnapshotDataO]));
      await runCheckedAsync(<String>['xcrun', 'cc']
        ..addAll(commonBuildOptions)
        ..addAll(<String>['-c', kIsolateSnapshotDataC, '-o', kIsolateSnapshotDataO]));
    } else {
      await runCheckedAsync(<String>['xcrun', 'cc']
        ..addAll(commonBuildOptions)
        ..addAll(<String>['-c', assembly, '-o', assemblyO]));
    }

    final String frameworkDir = fs.path.join(outputDir.path, 'App.framework');
    fs.directory(frameworkDir).createSync(recursive: true);
    final String appLib = fs.path.join(frameworkDir, 'App');
    final List<String> linkCommand = <String>['xcrun', 'clang']
      ..addAll(commonBuildOptions)
      ..addAll(<String>[
        '-dynamiclib',
        '-Xlinker', '-rpath', '-Xlinker', '@executable_path/Frameworks',
        '-Xlinker', '-rpath', '-Xlinker', '@loader_path/Frameworks',
        '-install_name', '@rpath/App.framework/App',
        '-o', appLib,
    ]);
    if (interpreter) {
      linkCommand.add(kVmSnapshotDataO);
      linkCommand.add(kIsolateSnapshotDataO);
    } else {
      linkCommand.add(assemblyO);
    }
    await runCheckedAsync(linkCommand);
  } else {
    if (compileToSharedLibrary) {
      // A word of warning: Instead of compiling via two steps, to a .o file and
      // then to a .so file we use only one command. When using two commands
      // gcc will end up putting a .eh_frame and a .debug_frame into the shared
      // library. Without stripping .debug_frame afterwards, unwinding tools
      // based upon libunwind use just one and ignore the contents of the other
      // (which causes it to not look into the other section and therefore not
      // find the correct unwinding information).
      await runCheckedAsync(<String>[androidSdk.ndkCompiler]
          ..addAll(androidSdk.ndkCompilerArgs)
          ..addAll(<String>[ '-shared', '-nostdlib', '-o', assemblySo, assembly ]));
    }
  }

  // Compute and record build fingerprint.
  try {
    final Fingerprint fingerprint = await makeFingerprint();
    await fingerprintFile.writeAsString(fingerprint.toJson());
  } catch (e, s) {
    // Log exception and continue, this step is a performance improvement only.
    printStatus('Error during AOT snapshot fingerprinting: $e\n$s');
  }

  return outputPath;
}
