// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:process/process.dart';
import 'package:yaml/yaml.dart';

import '../../src/common.dart';
import '../test_utils.dart';
import '../transition_test_utils.dart';
import 'native_assets_test_utils.dart';

// Regression test as part of https://github.com/flutter/flutter/pull/150742.
void main() {
  if (!platform.isMacOS && !platform.isLinux && !platform.isWindows) {
    // TODO(dacoharkes): Implement Fuchsia. https://github.com/flutter/flutter/issues/129757
    return;
  }

  const ProcessManager processManager = LocalProcessManager();
  final String nativeAssetsCliVersionConstraint =
      _getPackageFfiTemplatePubspecVersion();

  for (final String buildCommand in <String>[
    // Current (Host) OS.
    platform.operatingSystem,

    // On macOS, also test iOS.
    if (platform.isMacOS) 'ios',

    // On every host platform, test Android.
    'apk',
  ]) {
    _testBuildCommand(
      buildCommand: buildCommand,
      processManager: processManager,
      nativeAssetsCliVersionConstraint: nativeAssetsCliVersionConstraint,
    );
  }
}

void _testBuildCommand({
  required String buildCommand,
  required String nativeAssetsCliVersionConstraint,
  required ProcessManager processManager,
}) {
  testWithoutContext(
    'flutter build "$buildCommand" succeeds without libraries',
    () async {
      await inTempDir((Directory tempDirectory) async {
        const String packageName = 'uses_package_native_assets_cli';

        // Create a new (plain Dart SDK) project.
        await expectLater(
          processManager.run(
            <String>[
              flutterBin,
              'create',
              '--no-pub',
              packageName,
            ],
            workingDirectory: tempDirectory.path,
          ),
          completion(const ProcessResultMatcher()),
        );

        final Directory packageDirectory = tempDirectory.childDirectory(
          packageName,
        );

        // Add native_assets_cli and resolve implicitly (pub add does pub get).
        // See https://dart.dev/tools/pub/cmd/pub-add#version-constraint.
        await expectLater(
          processManager.run(
            <String>[
              flutterBin,
              'packages',
              'add',
              'native_assets_cli:$nativeAssetsCliVersionConstraint',
            ],
            workingDirectory: packageDirectory.path,
          ),
          completion(const ProcessResultMatcher()),
        );

        // Add a build hook that does nothing to the package.
        packageDirectory.childDirectory('hook').childFile('build.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('''
import 'package:native_assets_cli/native_assets_cli.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {});
}
''');

        // Try building.
        await expectLater(
          processManager.run(
            <String>[
              flutterBin,
              'build',
              'macos',
              '--debug',
            ],
            workingDirectory: packageDirectory.path,
          ),
          completion(const ProcessResultMatcher()),
        );
      });
    },
  );
}

/// Reads `templates/package_ffi/pubspec.yaml.tmpl` to use the package version.
///
/// For example, if the template would output:
/// ```yaml
/// dependencies:
///   native_assets_cli: ^0.8.0
/// ```
///
/// ... theh this function would return `'^0.8.0'`.
String _getPackageFfiTemplatePubspecVersion() {
  final String path = Context().join(
    getFlutterRoot(),
    'packages',
    'flutter_tools',
    'templates',
    'package_ffi',
    'pubspec.yaml.tmpl',
  );
  final YamlDocument yaml = loadYamlDocument(
    io.File(path).readAsStringSync(),
    sourceUrl: Uri.parse(path),
  );
  final YamlMap rootNode = yaml.contents as YamlMap;
  final YamlMap dependencies = rootNode.nodes['dependencies']! as YamlMap;
  final String version = dependencies['native_assets_cli']! as String;
  return version;
}
