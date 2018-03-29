// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/runner/flutter_command_runner.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/version.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:test/test.dart';

import '../src/common.dart';
import '../src/context.dart';
import 'flutter_command_test.dart';

const String _kFlutterRoot = '/flutter/flutter';
const String _kEngineRoot = '/flutter/engine';
const String _kProjectRoot = '/project';
const String _kDotPackages = '.packages';

void main() {
  group('FlutterCommandRunner', () {
    MemoryFileSystem fs;
    Platform platform;
    FlutterCommandRunner runner;

    setUpAll(() {
      Cache.disableLocking();
    });

    setUp(() {
      fs = new MemoryFileSystem();
      fs.directory(_kFlutterRoot).createSync(recursive: true);
      fs.directory(_kProjectRoot).createSync(recursive: true);
      fs.currentDirectory = _kProjectRoot;

      platform = new FakePlatform(environment: <String, String>{
        'FLUTTER_ROOT': _kFlutterRoot,
      });

      runner = createTestCommandRunner(new DummyFlutterCommand());
    });

    group('run', () {
      testUsingContext('checks that Flutter installation is up-to-date', () async {
        final MockFlutterVersion version = FlutterVersion.instance;
        bool versionChecked = false;
        when(version.checkFlutterVersionFreshness()).thenAnswer((_) async {
          versionChecked = true;
        });

        await runner.run(<String>['dummy']);

        expect(versionChecked, isTrue);
      }, overrides: <Type, Generator>{
        FileSystem: () => fs,
        Platform: () => platform,
      }, initializeFlutterRoot: false);

      testUsingContext('works if --local-engine is specified', () async {
        fs.file(_kDotPackages).writeAsStringSync('sky_engine:file://$_kFlutterRoot/bin/cache/pkg/sky_engine/lib/');
        fs.directory('$_kEngineRoot/src/out/ios_debug').createSync(recursive: true);
        fs.directory('$_kEngineRoot/src/out/host_debug').createSync(recursive: true);
        await runner.run(<String>['dummy', '--local-engine=ios_debug']);
      }, overrides: <Type, Generator>{
        FileSystem: () => fs,
        Platform: () => platform,
      }, initializeFlutterRoot: false);
    });

    group('getRepoPackages', () {
      setUp(() {
        fs.directory(fs.path.join(_kFlutterRoot, 'examples'))
            .createSync(recursive: true);
        fs.directory(fs.path.join(_kFlutterRoot, 'packages'))
            .createSync(recursive: true);
        fs.directory(fs.path.join(_kFlutterRoot, 'dev', 'tools', 'aatool'))
            .createSync(recursive: true);

        fs.file(fs.path.join(_kFlutterRoot, 'dev', 'tools', 'pubspec.yaml'))
            .createSync();
        fs.file(fs.path.join(_kFlutterRoot, 'dev', 'tools', 'aatool', 'pubspec.yaml'))
            .createSync();
      });

      testUsingContext('', () {
        final List<String> packagePaths = runner.getRepoPackages()
            .map((Directory d) => d.path).toList();
        expect(packagePaths, <String>[
          fs.directory(fs.path.join(_kFlutterRoot, 'dev', 'tools', 'aatool')).path,
          fs.directory(fs.path.join(_kFlutterRoot, 'dev', 'tools')).path,
        ]);
      }, overrides: <Type, Generator>{
        FileSystem: () => fs,
        Platform: () => platform,
      }, initializeFlutterRoot: false);
    });
  });
}
