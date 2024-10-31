// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:file/memory.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/build_targets.dart';
import 'package:flutter_tools/src/build_system/targets/localizations.dart';
import 'package:flutter_tools/src/dart/generate_synthetic_packages.dart';
import 'package:flutter_tools/src/isolated/build_targets.dart';

import '../../src/common.dart';
import '../../src/fake_process_manager.dart';
import '../../src/test_build_system.dart';

void main() {
  testWithoutContext('calls buildSystem.build with blank l10n.yaml file', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);

    // Create an l10n.yaml file
    fileSystem.file('l10n.yaml').createSync();

    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Artifacts artifacts = Artifacts.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: artifacts,
      processManager: FakeProcessManager.any(),
    );
    final Completer<void> completer = Completer<void>();
    final BuildResult exception = BuildResult(success: false, exceptions: <String, ExceptionMeasurement>{
      'hello': ExceptionMeasurement('hello', const FormatException('illegal character in input string'), StackTrace.current),
    });
    final TestBuildSystem buildSystem = TestBuildSystem.all(exception, (Target target, Environment environment) {
      expect(target, const GenerateLocalizationsTarget());
      expect(environment, environment);
      completer.complete();
    });

    await expectLater(
      () => generateLocalizationsSyntheticPackage(
        environment: environment,
        buildSystem: buildSystem,
        buildTargets: const BuildTargetsImpl(),
      ),
      throwsToolExit(message:
        'Generating synthetic localizations package failed with 1 error:'
        '\n\n'
        'FormatException: illegal character in input string',
      ),
    );
    await completer.future;
  });

  testWithoutContext('calls buildSystem.build with l10n.yaml synthetic-package: true', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);

    // Create an l10n.yaml file
    fileSystem.file('l10n.yaml').writeAsStringSync('synthetic-package: true');

    final FakeProcessManager fakeProcessManager = FakeProcessManager.any();
    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Artifacts artifacts = Artifacts.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: artifacts,
      processManager: fakeProcessManager,
    );
    final Completer<void> completer = Completer<void>();
    final BuildResult exception = BuildResult(success: false, exceptions: <String, ExceptionMeasurement>{
      'hello': ExceptionMeasurement('hello', const FormatException('illegal character in input string'), StackTrace.current),
    });
    final TestBuildSystem buildSystem = TestBuildSystem.all(exception, (Target target, Environment environment) {
      expect(target, const GenerateLocalizationsTarget());
      expect(environment, environment);
      completer.complete();
    });

    await expectLater(
      () => generateLocalizationsSyntheticPackage(
        environment: environment,
        buildSystem: buildSystem,
        buildTargets: const BuildTargetsImpl(),
      ),
      throwsToolExit(message:
        'Generating synthetic localizations package failed with 1 error:'
        '\n\n'
        'FormatException: illegal character in input string',
      ),
    );
    await completer.future;
  });

  testWithoutContext('calls buildSystem.build with l10n.yaml synthetic-package: null', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);

    // Create an l10n.yaml file
    fileSystem.file('l10n.yaml').writeAsStringSync('synthetic-package: null');

    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: Artifacts.test(),
      processManager: FakeProcessManager.any(),
    );
    final Completer<void> completer = Completer<void>();
    final BuildResult exception = BuildResult(success: false, exceptions: <String, ExceptionMeasurement>{
      'hello': ExceptionMeasurement('hello', const FormatException('illegal character in input string'), StackTrace.current),
    });
    final TestBuildSystem buildSystem = TestBuildSystem.all(exception, (Target target, Environment environment) {
      expect(target, const GenerateLocalizationsTarget());
      expect(environment, environment);
      completer.complete();
    });

    await expectLater(
      () => generateLocalizationsSyntheticPackage(
        environment: environment,
        buildSystem: buildSystem,
        buildTargets: const BuildTargetsImpl(),
      ),
      throwsToolExit(message:
        'Generating synthetic localizations package failed with 1 error:'
        '\n\n'
        'FormatException: illegal character in input string',
      ),
    );
    await completer.future;
  });

  testWithoutContext('does not call buildSystem.build when l10n.yaml is not present', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);

    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: Artifacts.test(),
      processManager: FakeProcessManager.any(),
    );
    // Will throw if build is called.
    final TestBuildSystem buildSystem = TestBuildSystem.all(null);

    await generateLocalizationsSyntheticPackage(
      environment: environment,
      buildSystem: buildSystem,
      buildTargets: const NoOpBuildTargets(),
    );
  });

  testWithoutContext('does not call buildSystem.build with incorrect l10n.yaml format', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);

    // Create an l10n.yaml file
    fileSystem.file('l10n.yaml').writeAsStringSync('helloWorld');

    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: Artifacts.test(),
      processManager: FakeProcessManager.any(),
    );
    // Will throw if build is called.
    final TestBuildSystem buildSystem = TestBuildSystem.all(null);

    await expectLater(
      () => generateLocalizationsSyntheticPackage(
        environment: environment,
        buildSystem: buildSystem,
        buildTargets: const NoOpBuildTargets(),
      ),
      throwsToolExit(message: 'to contain a map, instead was helloWorld'),
    );
  });

  testWithoutContext('does not call buildSystem.build with non-bool "synthetic-package" value', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);

    // Create an l10n.yaml file
    fileSystem.file('l10n.yaml').writeAsStringSync('synthetic-package: nonBoolValue');

    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: Artifacts.test(),
      processManager: FakeProcessManager.any(),
    );
    // Will throw if build is called.
    final TestBuildSystem buildSystem = TestBuildSystem.all(null);

    await expectLater(
      () => generateLocalizationsSyntheticPackage(
        environment: environment,
        buildSystem: buildSystem,
        buildTargets: const NoOpBuildTargets(),
      ),
      throwsToolExit(message: 'to have a bool value, instead was "nonBoolValue"'),
    );
  });

  testWithoutContext('synthetic-package: true (implicit) logs a deprecation warning', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);

    // Create a blank l10n.yaml file
    fileSystem.file('l10n.yaml').writeAsStringSync('');

    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: Artifacts.test(),
      processManager: FakeProcessManager.any(),
    );
    final TestBuildSystem buildSystem = TestBuildSystem.all(BuildResult(success: true));

    await generateLocalizationsSyntheticPackage(
      environment: environment,
      buildSystem: buildSystem,
      buildTargets: const BuildTargetsImpl(),
    );

    expect(
      mockBufferLogger.warningText,
      contains('https://flutter.dev/to/flutter-gen-deprecation'),
    );
  });

  testWithoutContext('synthetic-package: true (explicit) logs a deprecation warning', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);
    fileSystem.file('l10n.yaml').writeAsStringSync('synthetic-package: true');

    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: Artifacts.test(),
      processManager: FakeProcessManager.any(),
    );
    final TestBuildSystem buildSystem = TestBuildSystem.all(BuildResult(success: true));

    await generateLocalizationsSyntheticPackage(
      environment: environment,
      buildSystem: buildSystem,
      buildTargets: const BuildTargetsImpl(),
    );

    expect(
      mockBufferLogger.warningText,
      contains('https://flutter.dev/to/flutter-gen-deprecation'),
    );
  });

  testWithoutContext('synthetic-package: false has no deprecation warning', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);
    fileSystem.file('l10n.yaml').writeAsStringSync('synthetic-package: false');

    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: Artifacts.test(),
      processManager: FakeProcessManager.any(),
    );
    final TestBuildSystem buildSystem = TestBuildSystem.all(BuildResult(success: true));

    await generateLocalizationsSyntheticPackage(
      environment: environment,
      buildSystem: buildSystem,
      buildTargets: const BuildTargetsImpl(),
    );

    expect(
      mockBufferLogger.warningText,
      isNot(contains('https://flutter.dev/to/flutter-gen-deprecation')),
    );
  });

  testWithoutContext('synthetic-package: true with --no-implicit-pubspec-resolution is an error', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);

    // Create an l10n.yaml file
    fileSystem.file('l10n.yaml').writeAsStringSync('synthetic-package: true');

    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: Artifacts.test(),
      processManager: FakeProcessManager.any(),
      useImplicitPubspecResolution: false,
    );
    // Will throw if build is called.
    final TestBuildSystem buildSystem = TestBuildSystem.all(null);

    await expectLater(
      () => generateLocalizationsSyntheticPackage(
        environment: environment,
        buildSystem: buildSystem,
        buildTargets: const NoOpBuildTargets(),
      ),
      throwsToolExit(message: 'Cannot generate a synthetic package when --no-implicit-pubspec-resolution is passed'),
    );
  });

  testWithoutContext('synthetic-package defaults to false if --no-implicit-pubspec-resolution is passed', () async {
    // Project directory setup for gen_l10n logic
    final MemoryFileSystem fileSystem = MemoryFileSystem.test();

    // Add generate:true to pubspec.yaml.
    final File pubspecFile = fileSystem.file('pubspec.yaml')..createSync();
    final String content = pubspecFile.readAsStringSync().replaceFirst(
      '\nflutter:\n',
      '\nflutter:\n  generate: true\n',
    );
    pubspecFile.writeAsStringSync(content);

    // Create an l10n.yaml file
    fileSystem.file('l10n.yaml').writeAsStringSync('');

    final BufferLogger mockBufferLogger = BufferLogger.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: mockBufferLogger,
      artifacts: Artifacts.test(),
      processManager: FakeProcessManager.any(),
      useImplicitPubspecResolution: false,
    );
    // Will throw if build is called.
    final TestBuildSystem buildSystem = TestBuildSystem.all(null);

    await expectLater(
      () => generateLocalizationsSyntheticPackage(
        environment: environment,
        buildSystem: buildSystem,
        buildTargets: const NoOpBuildTargets(),
      ),
      returnsNormally,
    );
  });
}
