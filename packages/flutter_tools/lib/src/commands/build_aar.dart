// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../android/aar.dart';
import '../base/context.dart';
import '../base/file_system.dart';
import '../build_info.dart';
import '../project.dart';
import '../runner/flutter_command.dart' show DevelopmentArtifact, FlutterCommandResult;
import '../usage.dart';
import 'build.dart';

/// The AAR builder in the current context.
AarBuilder get aarBuilder => context.get<AarBuilder>() ?? AarBuilderImpl();

class BuildAarCommand extends BuildSubCommand {
  BuildAarCommand({bool verboseHelp = false}) {
    usesTargetOption();
    addBuildModeFlags(verboseHelp: verboseHelp);
    usesFlavorOption();
    usesPubOption();
    argParser
      ..addMultiOption('target-platform',
        splitCommas: true,
        defaultsTo: <String>['android-arm', 'android-arm64'],
        allowed: <String>['android-arm', 'android-arm64', 'android-x86', 'android-x64'],
        help: 'The target platform for which the project is compiled.',
      )
      ..addOption('output-dir',
        help: 'The absolute path to the directory where the repository is generated.'
              'By default, this is \'<current-directory>android/build\'. ',
      );
  }

  @override
  final String name = 'aar';

  /// Returns the [FlutterProject] depending on the target flag.
  FlutterProject _getProject() {
    final String projectDir = fs.file(targetFile).parent.parent.path;
    return FlutterProject.fromPath(projectDir);
  }

  @override
  Future<Map<String, String>> get usageValues async {
    final Map<String, String> usage = <String, String>{};
    final FlutterProject futterProject = _getProject();
    if (futterProject == null) {
      return usage;
    }
    if (futterProject.manifest.isModule) {
      usage[kCommandBuildAarProjectType] = 'module';
    } else if (futterProject.manifest.isPlugin) {
      usage[kCommandBuildAarProjectType] = 'plugin';
    } else {
      usage[kCommandBuildAarProjectType] = 'app';
    }
    usage[kCommandBuildAarTargetPlatform] =
        (argResults['target-platform'] as List<String>).join(',');
    return usage;
  }

  @override
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async => const <DevelopmentArtifact>{
    DevelopmentArtifact.universal,
    DevelopmentArtifact.android,
  };

  @override
  final String description = 'Build a repository containing an AAR and a POM file.\n\n'
      'The POM file is used to include the dependencies that the AAR was compiled against.\n\n'
      'To learn more about how to use these artifacts, see '
      'https://docs.gradle.org/current/userguide/repository_types.html#sub:maven_local';

  @override
  Future<FlutterCommandResult> runCommand() async {
    final BuildInfo buildInfo = getBuildInfo();
    final AndroidBuildInfo androidBuildInfo = AndroidBuildInfo(buildInfo,
        targetArchs: argResults['target-platform'].map<AndroidArch>(getAndroidArchForName));

    await aarBuilder.build(
      project: _getProject(),
      target: targetFile,
      androidBuildInfo: androidBuildInfo,
      outputDir: argResults['output-dir'],
    );
    return null;
  }
}
