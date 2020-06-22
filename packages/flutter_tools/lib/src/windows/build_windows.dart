// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../artifacts.dart';
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/process.dart';
import '../base/utils.dart';
import '../build_info.dart';
import '../cache.dart';
import '../globals.dart' as globals;
import '../linux/cmake.dart';  // XXX Move, obviously.
import '../plugins.dart';
import '../project.dart';
import 'property_sheet.dart';
import 'visual_studio.dart';

/// Builds the Windows project using msbuild.
Future<void> buildWindows(WindowsProject windowsProject, BuildInfo buildInfo, {
  String target,
  VisualStudio visualStudioOverride,
}) async {
  if (!windowsProject.solutionFile.existsSync()) {
    throwToolExit(
      'No Windows desktop project configured. '
      'See https://github.com/flutter/flutter/wiki/Desktop-shells#create '
      'to learn about adding Windows support to a project.');
  }

  // Check for incompatibility between the Flutter tool version and the project
  // template version, since the tempalte isn't stable yet.
  final int templateCompareResult = _compareTemplateVersions(windowsProject);
  if (templateCompareResult < 0) {
    throwToolExit('The Windows runner was created with an earlier version of '
      'the template, which is not yet stable.\n\n'
      'Delete the windows/ directory and re-run \'flutter create .\', '
      're-applying any previous changes.');
  } else if (templateCompareResult > 0) {
    throwToolExit('The Windows runner was created with a newer version of the '
      'template, which is not yet stable.\n\n'
      'Upgrade Flutter and try again.');
  }

  // Ensure that necessary emphemeral files are generated and up to date.
  _writeGeneratedFlutterProperties(windowsProject, buildInfo, target);
  createPluginSymlinks(windowsProject.parent);

  final VisualStudio visualStudio = visualStudioOverride ?? VisualStudio(
    fileSystem: globals.fs,
    platform: globals.platform,
    logger: globals.logger,
    processManager: globals.processManager,
  );
  final String vcvarsScript = visualStudio.vcvarsPath;
  if (vcvarsScript == null) {
    throwToolExit('Unable to find suitable Visual Studio toolchain. '
        'Please run `flutter doctor` for more details.');
  }

  final String buildScript = globals.fs.path.join(
    Cache.flutterRoot,
    'packages',
    'flutter_tools',
    'bin',
    'vs_build.bat',
  );

  final String buildModeName = getNameForBuildMode(buildInfo.mode ?? BuildMode.release);
  final String configuration = toTitleCase(getNameForBuildMode(buildInfo.mode ?? BuildMode.release));
  final Directory buildDirectory = globals.fs.directory(getWindowsBuildDirectory()).childDirectory(buildModeName); // XXX
  //final String solutionPath = windowsProject.solutionFile.path;
  final String solutionPath = buildDirectory.childFile('cmaketest.sln').path; // XXX Read from cmake.
  final Stopwatch sw = Stopwatch()..start();
  final Status status = globals.logger.startProgress(
    'Building Windows application...',
    timeout: null,
  );
  int result;
  try {
    await _runCmake(visualStudio.cmakePath, buildModeName, windowsProject.cmakeFile.parent, buildDirectory);
    // XXX Use cmake --build <dir> instead?
    // Run the script with a relative path to the project using the enclosing
    // directory as the workingDirectory, to avoid hitting the limit on command
    // lengths in batch scripts if the absolute path to the project is long.
    result = await processUtils.stream(
      <String>[
        buildScript,
        vcvarsScript,
        globals.fs.path.basename(solutionPath),
        configuration,
      ],
      environment: <String, String>{
        if (globals.logger.isVerbose)
          'VERBOSE_SCRIPT_LOGGING': 'true'
      },
      workingDirectory: globals.fs.path.dirname(solutionPath),
      trace: true,
    );
  } finally {
    status.cancel();
  }
  if (result != 0) {
    throwToolExit('Build process failed. To view the stack trace, please run `flutter run -d windows -v`.');
  }
  await _runInstall(visualStudio.cmakePath, buildDirectory, buildModeName);
  globals.flutterUsage.sendTiming('build', 'vs_build', Duration(milliseconds: sw.elapsedMilliseconds));
}

Future<void> _runInstall(String cmakePath, Directory buildDir, String buildModeName) async {
  final Stopwatch sw = Stopwatch()..start();

  int result;
  try {
    result = await processUtils.stream(
      <String>[
        cmakePath,
        '--install',
        buildDir.path,
        '--config',
        toTitleCase(buildModeName),
      ],
      trace: true,
    );
  } on ArgumentError {
    throwToolExit("cmake not found. Run 'flutter doctor' for more information.");
  }
  if (result != 0) {
    throwToolExit('Build process failed');
  }
  globals.flutterUsage.sendTiming('build', 'windows-cmake-install', Duration(milliseconds: sw.elapsedMilliseconds));
}

/// Writes the generatedPropertySheetFile with the configuration for the given build.
void _writeGeneratedFlutterProperties(
  WindowsProject windowsProject,
  BuildInfo buildInfo,
  String target,
) {
  final Map<String, String> environment = <String, String>{
    'FLUTTER_ROOT': Cache.flutterRoot,
    'FLUTTER_EPHEMERAL_DIR': windowsProject.ephemeralDirectory.path,
    'PROJECT_DIR': windowsProject.parent.directory.path,
    if (target != null)
      'FLUTTER_TARGET': target,
    ...buildInfo.toEnvironmentConfig(),
  };
  if (globals.artifacts is LocalEngineArtifacts) {
    final LocalEngineArtifacts localEngineArtifacts = globals.artifacts as LocalEngineArtifacts;
    final String engineOutPath = localEngineArtifacts.engineOutPath;
    environment['FLUTTER_ENGINE'] = globals.fs.path.dirname(globals.fs.path.dirname(engineOutPath));
    environment['LOCAL_ENGINE'] = globals.fs.path.basename(engineOutPath);
  }

  final File propsFile = windowsProject.generatedPropertySheetFile;
  propsFile.createSync(recursive: true);
  propsFile.writeAsStringSync(PropertySheet(environmentVariables: environment).toString());
  writeGeneratedCmakeConfig(Cache.flutterRoot, windowsProject, environment);
}

Future<void> _runCmake(String cmakePath, String buildModeName, Directory sourceDir, Directory buildDir) async {
  final Stopwatch sw = Stopwatch()..start();

  await buildDir.create(recursive: true);
  final String buildFlag = toTitleCase(buildModeName);
  int result;
  try {
    result = await processUtils.stream(
      <String>[
        cmakePath,
        '-S',
        sourceDir.path,
        '-B',
        buildDir.path,
        '-G',
        'Visual Studio 16 2019',
        '-DCMAKE_BUILD_TYPE=$buildFlag',
      ],
      environment: <String, String>{
        'CC': 'clang',
        'CXX': 'clang++'
      },
      trace: true,
    );
  } on ArgumentError {
    throwToolExit("cmake not found. Run 'flutter doctor' for more information.");
  }
  if (result != 0) {
    throwToolExit('Unable to generate build files');
  }
  globals.flutterUsage.sendTiming('build', 'cmake-windows', Duration(milliseconds: sw.elapsedMilliseconds));
}

// Checks the template version of [project] against the current template
// version. Returns < 0 if the project is older than the current template, > 0
// if it's newer, and 0 if they match.
int _compareTemplateVersions(WindowsProject project) {
  const String projectVersionBasename = '.template_version';
  final int expectedVersion = int.parse(globals.fs.file(globals.fs.path.join(
    globals.fs.path.absolute(Cache.flutterRoot),
    'packages',
    'flutter_tools',
    'templates',
    'app',
    'windows.tmpl',
    'flutter',
    projectVersionBasename,
  )).readAsStringSync());
  final File projectVersionFile = project.managedDirectory.childFile(projectVersionBasename);
  final int version = projectVersionFile.existsSync()
      ? int.tryParse(projectVersionFile.readAsStringSync())
      : 0;
  return version.compareTo(expectedVersion);
}
