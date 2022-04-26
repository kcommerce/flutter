// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/update_packages.dart';
import 'package:flutter_tools/src/dart/pub.dart';
import 'package:meta/meta.dart';
import 'package:test/fake.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/test_flutter_command_runner.dart';

// An example pubspec.yaml from flutter, not necessary for it to be up to date.
const String kFlutterPubspecYaml = r'''
name: flutter
description: A framework for writing Flutter applications
homepage: http://flutter.dev

environment:
  sdk: ">=2.2.2 <3.0.0"

dependencies:
  # To update these, use "flutter update-packages --force-upgrade".
  collection: 1.14.11
  meta: 1.1.8
  typed_data: 1.1.6
  vector_math: 2.0.8

  sky_engine:
    sdk: flutter

  gallery:
    git:
      url: https://github.com/flutter/gallery.git
      ref: d00362e6bdd0f9b30bba337c358b9e4a6e4ca950

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_goldens:
    sdk: flutter

  archive: 2.0.11 # THIS LINE IS AUTOGENERATED - TO UPDATE USE "flutter update-packages --force-upgrade"

# PUBSPEC CHECKSUM: 1234
''';

// An example pubspec.yaml, not necessary for it to be up to date.
const String kExamplesPubspecYaml = r'''
name: examples
description: Examples for flutter
homepage: http://flutter.dev

version: 1.0.0

environment:
  sdk: ">=2.14.0-383.0.dev <3.0.0"
  flutter: ">=2.5.0-6.0.pre.30 <3.0.0"

dependencies:
  cupertino_icons: 1.0.4
  flutter:
    sdk: flutter

  archive: 2.0.11 # THIS LINE IS AUTOGENERATED - TO UPDATE USE "flutter update-packages --force-upgrade"

# PUBSPEC CHECKSUM: 6543
''';

void main() {
  testWithoutContext('kManuallyPinnedDependencies pins are actually pins', () {
    expect(
      kManuallyPinnedDependencies.values,
      isNot(contains(anyOf('any', startsWith('^'), startsWith('>'), startsWith('<')))),
      reason: 'Version pins in kManuallyPinnedDependencies must be specific pins, not ranges.',
    );
  });

  group('update-packages', () {
    FileSystem fileSystem;
    Directory flutterSdk;
    Directory flutter;
    FakePub pub;

    setUpAll(() {
      Cache.disableLocking();
    });

    setUp(() {
      fileSystem = MemoryFileSystem.test();
      flutterSdk = fileSystem.directory('flutter')..createSync();
      flutterSdk.childFile('version').writeAsStringSync('1.2.3');
      flutter = flutterSdk.childDirectory('packages').childDirectory('flutter')
        ..createSync(recursive: true);
      flutterSdk.childDirectory('dev').createSync(recursive: true);
      flutterSdk.childDirectory('examples').childFile('pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync(kExamplesPubspecYaml);
      flutter.childFile('pubspec.yaml').writeAsStringSync(kFlutterPubspecYaml);
      Cache.flutterRoot = flutterSdk.absolute.path;
      pub = FakePub(fileSystem);
    });

    testUsingContext('updates packages', () async {
      final UpdatePackagesCommand command = UpdatePackagesCommand();
      await createTestCommandRunner(command).run(<String>['update-packages']);
      expect(pub.pubGetDirectories, equals(<String>[
        '/.tmp_rand0/flutter_update_packages.rand0',
        '/flutter/examples',
        '/flutter/packages/flutter',
      ]));
      expect(pub.pubBatchDirectories, isEmpty);
    }, overrides: <Type, Generator>{
      Pub: () => pub,
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
      Cache: () => Cache.test(
        processManager: FakeProcessManager.any(),
      ),
    });

    testUsingContext('force updates packages', () async {
      final UpdatePackagesCommand command = UpdatePackagesCommand();
      await createTestCommandRunner(command).run(<String>[
        'update-packages',
        '--force-upgrade',
      ]);
      expect(pub.pubGetDirectories, equals(<String>[
        '/.tmp_rand0/flutter_update_packages.rand0',
        '/flutter/examples',
        '/flutter/packages/flutter',
      ]));
      expect(pub.pubBatchDirectories, equals(<String>[
        '/.tmp_rand0/flutter_update_packages.rand0',
      ]));
    }, overrides: <Type, Generator>{
      Pub: () => pub,
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
      Cache: () => Cache.test(
        processManager: FakeProcessManager.any(),
      ),
    });

    testUsingContext('force updates packages --jobs=1', () async {
      final UpdatePackagesCommand command = UpdatePackagesCommand();
      await createTestCommandRunner(command).run(<String>[
        'update-packages',
        '--force-upgrade',
        '--jobs=1',
      ]);
      expect(pub.pubGetDirectories, equals(<String>[
        '/.tmp_rand0/flutter_update_packages.rand0',
        '/flutter/examples',
        '/flutter/packages/flutter',
      ]));
      expect(pub.pubBatchDirectories, equals(<String>[
        '/.tmp_rand0/flutter_update_packages.rand0',
      ]));
    }, overrides: <Type, Generator>{
      Pub: () => pub,
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
      Cache: () => Cache.test(
        processManager: FakeProcessManager.any(),
      ),
    });
  });
}

class FakePub extends Fake implements Pub {
  FakePub(this.fileSystem);

  final FileSystem fileSystem;
  final List<String> pubGetDirectories = <String>[];
  final List<String> pubBatchDirectories = <String>[];

  @override
  Future<void> get({
    @required PubContext context,
    String directory,
    bool skipIfAbsent = false,
    bool upgrade = false,
    bool offline = false,
    bool generateSyntheticPackage = false,
    String flutterRootOverride,
    bool checkUpToDate = false,
    bool shouldSkipThirdPartyGenerator = true,
    bool printProgress = true,
  }) async {
    pubGetDirectories.add(directory);
    fileSystem.directory(directory).childFile('pubspec.lock')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
# Generated by pub
# See https://dart.dev/tools/pub/glossary#lockfile
packages:
  async:
    dependency: "direct dev"
    description:
      name: async
      url: "https://pub.dartlang.org"
    source: hosted
    version: "2.8.2"
sdks:
  dart: ">=2.14.0 <3.0.0"
''');
    fileSystem.currentDirectory
        .childDirectory('.dart_tool')
        .childFile('package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"configVersion":2,"packages":[]}');
  }

  @override
  Future<void> batch(
      List<String> arguments, {
        @required PubContext context,
        String directory,
        MessageFilter filter,
        String failureMessage = 'pub failed',
        @required bool retry,
        bool showTraceForErrors,
      }) async {
    pubBatchDirectories.add(directory);

'''
Dart SDK 2.16.0-144.0.dev
Flutter SDK 2.9.0-1.0.pre.263
flutter_api_samples 1.0.0

dependencies:
- cupertino_icons 1.0.4
- collection 1.15.0
- meta 1.7.0
- typed_data 1.3.0 [collection]
- vector_math 2.1.1

dev dependencies:

transitive dependencies:
- platform 3.1.0
- process 4.2.4 [file path platform]
'''.split('\n').forEach(filter);
  }
}
