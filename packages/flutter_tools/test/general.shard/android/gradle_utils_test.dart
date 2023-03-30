// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/android/gradle_utils.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/project.dart';
import '../../src/common.dart';
import '../../src/fake_process_manager.dart';
import '../../src/fakes.dart';

void main() {
  group('injectGradleWrapperIfNeeded', () {
    late MemoryFileSystem fileSystem;
    late Directory gradleWrapperDirectory;
    late GradleUtils gradleUtils;

    setUp(() {
      fileSystem = MemoryFileSystem.test();
      gradleWrapperDirectory =
          fileSystem.directory('cache/bin/cache/artifacts/gradle_wrapper');
      gradleWrapperDirectory.createSync(recursive: true);
      gradleWrapperDirectory
          .childFile('gradlew')
          .writeAsStringSync('irrelevant');
      gradleWrapperDirectory
          .childDirectory('gradle')
          .childDirectory('wrapper')
          .createSync(recursive: true);
      gradleWrapperDirectory
          .childDirectory('gradle')
          .childDirectory('wrapper')
          .childFile('gradle-wrapper.jar')
          .writeAsStringSync('irrelevant');
      gradleUtils = GradleUtils(
        cache: Cache.test(
            processManager: FakeProcessManager.any(), fileSystem: fileSystem),
        fileSystem: fileSystem,
        platform: FakePlatform(environment: <String, String>{}),
        logger: BufferLogger.test(),
        operatingSystemUtils: FakeOperatingSystemUtils(),
      );
    });

    testWithoutContext('injects the wrapper when all files are missing', () {
      final Directory sampleAppAndroid =
          fileSystem.directory('/sample-app/android');
      sampleAppAndroid.createSync(recursive: true);

      gradleUtils.injectGradleWrapperIfNeeded(sampleAppAndroid);

      expect(sampleAppAndroid.childFile('gradlew').existsSync(), isTrue);

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.jar')
              .existsSync(),
          isTrue);

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.properties')
              .existsSync(),
          isTrue);

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.properties')
              .readAsStringSync(),
          'distributionBase=GRADLE_USER_HOME\n'
          'distributionPath=wrapper/dists\n'
          'zipStoreBase=GRADLE_USER_HOME\n'
          'zipStorePath=wrapper/dists\n'
          'distributionUrl=https\\://services.gradle.org/distributions/gradle-7.5-all.zip\n');
    });

    testWithoutContext('injects the wrapper when some files are missing', () {
      final Directory sampleAppAndroid =
          fileSystem.directory('/sample-app/android');
      sampleAppAndroid.createSync(recursive: true);

      // There's an existing gradlew
      sampleAppAndroid
          .childFile('gradlew')
          .writeAsStringSync('existing gradlew');

      gradleUtils.injectGradleWrapperIfNeeded(sampleAppAndroid);

      expect(sampleAppAndroid.childFile('gradlew').existsSync(), isTrue);
      expect(sampleAppAndroid.childFile('gradlew').readAsStringSync(),
          equals('existing gradlew'));

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.jar')
              .existsSync(),
          isTrue);

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.properties')
              .existsSync(),
          isTrue);

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.properties')
              .readAsStringSync(),
          'distributionBase=GRADLE_USER_HOME\n'
          'distributionPath=wrapper/dists\n'
          'zipStoreBase=GRADLE_USER_HOME\n'
          'zipStorePath=wrapper/dists\n'
          'distributionUrl=https\\://services.gradle.org/distributions/gradle-7.5-all.zip\n');
    });

    testWithoutContext(
        'injects the wrapper and the Gradle version is derivated from the AGP version',
        () {
      const Map<String, String> testCases = <String, String>{
        // AGP version : Gradle version
        '1.0.0': '2.3',
        '3.3.1': '4.10.2',
        '3.0.0': '4.1',
        '3.0.5': '4.1',
        '3.0.9': '4.1',
        '3.1.0': '4.4',
        '3.2.0': '4.6',
        '3.3.0': '4.10.2',
        '3.4.0': '5.6.2',
        '3.5.0': '5.6.2',
        '4.0.0': '6.7',
        '4.0.5': '6.7',
        '4.1.0': '6.7',
      };

      for (final MapEntry<String, String> entry in testCases.entries) {
        final Directory sampleAppAndroid =
            fileSystem.systemTempDirectory.createTempSync('flutter_android.');
        sampleAppAndroid.childFile('build.gradle').writeAsStringSync('''
  buildscript {
      dependencies {
          classpath 'com.android.tools.build:gradle:${entry.key}'
      }
  }
  ''');
        gradleUtils.injectGradleWrapperIfNeeded(sampleAppAndroid);

        expect(sampleAppAndroid.childFile('gradlew').existsSync(), isTrue);

        expect(
            sampleAppAndroid
                .childDirectory('gradle')
                .childDirectory('wrapper')
                .childFile('gradle-wrapper.jar')
                .existsSync(),
            isTrue);

        expect(
            sampleAppAndroid
                .childDirectory('gradle')
                .childDirectory('wrapper')
                .childFile('gradle-wrapper.properties')
                .existsSync(),
            isTrue);

        expect(
            sampleAppAndroid
                .childDirectory('gradle')
                .childDirectory('wrapper')
                .childFile('gradle-wrapper.properties')
                .readAsStringSync(),
            'distributionBase=GRADLE_USER_HOME\n'
            'distributionPath=wrapper/dists\n'
            'zipStoreBase=GRADLE_USER_HOME\n'
            'zipStorePath=wrapper/dists\n'
            'distributionUrl=https\\://services.gradle.org/distributions/gradle-${entry.value}-all.zip\n');
      }
    });

    testWithoutContext('returns the gradlew path', () {
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      androidDirectory.childFile('gradlew').createSync();
      androidDirectory.childFile('gradlew.bat').createSync();
      androidDirectory.childFile('gradle.properties').createSync();

      final FlutterProject flutterProject = FlutterProjectFactory(
        logger: BufferLogger.test(),
        fileSystem: fileSystem,
      ).fromDirectory(fileSystem.currentDirectory);

      expect(
        gradleUtils.getExecutable(flutterProject),
        androidDirectory.childFile('gradlew').path,
      );
    });

    testWithoutContext('returns the gradle wrapper version', () async {
      const String expectedVersion = '7.4.2';
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      final Directory wrapperDirectory = androidDirectory
          .childDirectory('gradle')
          .childDirectory('wrapper')
        ..createSync(recursive: true);
      wrapperDirectory
          .childFile('gradle-wrapper.properties')
          .writeAsStringSync('''
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-$expectedVersion-all.zip
''');

      expect(
        await getGradleVersion(
            androidDirectory, BufferLogger.test(), FakeProcessManager.empty()),
        expectedVersion,
      );
    });

    testWithoutContext('returns the installed gradle version', () async {
      const String expectedVersion = '7.4.2';
      const String gradleOutput = '''

------------------------------------------------------------
Gradle $expectedVersion
------------------------------------------------------------

Build time:   2022-03-31 15:25:29 UTC
Revision:     540473b8118064efcc264694cbcaa4b677f61041

Kotlin:       1.5.31
Groovy:       3.0.9
Ant:          Apache Ant(TM) version 1.10.11 compiled on July 10 2021
JVM:          11.0.18 (Azul Systems, Inc. 11.0.18+10-LTS)
OS:           Mac OS X 13.2.1 aarch64
''';
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      final ProcessManager processManager = FakeProcessManager.empty()
        ..addCommand(const FakeCommand(
            command: <String>['gradle', gradleVersionFlag],
            stdout: gradleOutput));

      expect(
        await getGradleVersion(
          androidDirectory,
          BufferLogger.test(),
          processManager,
        ),
        expectedVersion,
      );
    });
    testWithoutContext('returns the AGP version when set', () async {
      const String expectedVersion = '7.3.0';
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      androidDirectory.childFile('build.gradle').writeAsStringSync('''
buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:$expectedVersion'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
''');

      expect(
        getAgpVersion(androidDirectory, BufferLogger.test()),
        expectedVersion,
      );
    });
    testWithoutContext('returns null when AGP version not set', () async {
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      androidDirectory.childFile('build.gradle').writeAsStringSync('''
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
    }
}
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
''');

      expect(
        getAgpVersion(androidDirectory, BufferLogger.test()),
        null,
      );
    });

    testWithoutContext('validates gradle/agp versions', () async {
      final List<GradleAgpTestData> testData = <GradleAgpTestData>[
        // Values too new *these need to update* when
        // max known gradle and max known agp versions are updated:
        // Newer tools version supports max gradle version.
        GradleAgpTestData(true, agpVersion: '8.2', gradleVersion: '8.0'),
        // Newer tools version does not even meet current gradle version requiremnts.
        GradleAgpTestData(false, agpVersion: '8.2', gradleVersion: '7.3'),
        // Newer tools version requires newer gradle version.
        GradleAgpTestData(true, agpVersion: '8.3', gradleVersion: '8.1'),

        // Minimims as defined in
        // https://developer.android.com/studio/releases/gradle-plugin#updating-gradle
        GradleAgpTestData(true, agpVersion: '8.1', gradleVersion: '8.0'),
        GradleAgpTestData(true, agpVersion: '8.0', gradleVersion: '8.0'),
        GradleAgpTestData(true, agpVersion: '7.4', gradleVersion: '7.5'),
        GradleAgpTestData(true, agpVersion: '7.3', gradleVersion: '7.4'),
        GradleAgpTestData(true, agpVersion: '7.2', gradleVersion: '7.3.3'),
        GradleAgpTestData(true, agpVersion: '7.1', gradleVersion: '7.2'),
        GradleAgpTestData(true, agpVersion: '7.0', gradleVersion: '7.0'),
        GradleAgpTestData(true, agpVersion: '4.2.0', gradleVersion: '6.7.1'),
        GradleAgpTestData(true, agpVersion: '4.1.0', gradleVersion: '6.5'),
        GradleAgpTestData(true, agpVersion: '4.0.0', gradleVersion: '6.1.1'),
        GradleAgpTestData(true, agpVersion: '3.6.0', gradleVersion: '5.6.4'),
        GradleAgpTestData(true, agpVersion: '3.5.0', gradleVersion: '5.4.1'),
        GradleAgpTestData(true, agpVersion: '3.4.0', gradleVersion: '5.1.1'),
        GradleAgpTestData(true, agpVersion: '3.3.0', gradleVersion: '4.10.1'),
        // Values too old:
        GradleAgpTestData(false, agpVersion: '3.3.0', gradleVersion: '4.9'),
        GradleAgpTestData(false, agpVersion: '7.3', gradleVersion: '7.2'),
        GradleAgpTestData(false, agpVersion: '3.0.0', gradleVersion: '7.2'),
        // Null values:
        // ignore: avoid_redundant_argument_values
        GradleAgpTestData(false, agpVersion: null, gradleVersion: '7.2'),
        // ignore: avoid_redundant_argument_values
        GradleAgpTestData(false, agpVersion: '3.0.0', gradleVersion: null),
        // ignore: avoid_redundant_argument_values
        GradleAgpTestData(false, agpVersion: null, gradleVersion: null),
        // Middle AGP cases:
        GradleAgpTestData(true, agpVersion: '8.0.1', gradleVersion: '8.0'),
        GradleAgpTestData(true, agpVersion: '7.4.1', gradleVersion: '7.5'),
        GradleAgpTestData(true, agpVersion: '7.3.1', gradleVersion: '7.4'),
        GradleAgpTestData(true, agpVersion: '7.2.1', gradleVersion: '7.3.3'),
        GradleAgpTestData(true, agpVersion: '7.1.1', gradleVersion: '7.2'),
        GradleAgpTestData(true, agpVersion: '7.0.1', gradleVersion: '7.0'),
        GradleAgpTestData(true, agpVersion: '4.2.1', gradleVersion: '6.7.1'),
        GradleAgpTestData(true, agpVersion: '4.1.1', gradleVersion: '6.5'),
        GradleAgpTestData(true, agpVersion: '4.0.1', gradleVersion: '6.1.1'),
        GradleAgpTestData(true, agpVersion: '3.6.1', gradleVersion: '5.6.4'),
        GradleAgpTestData(true, agpVersion: '3.5.1', gradleVersion: '5.4.1'),
        GradleAgpTestData(true, agpVersion: '3.4.1', gradleVersion: '5.1.1'),
        GradleAgpTestData(true, agpVersion: '3.3.1', gradleVersion: '4.10.1'),

        // Higher gradle cases:
        GradleAgpTestData(true, agpVersion: '7.4', gradleVersion: '8.0'),
        GradleAgpTestData(true, agpVersion: '7.3', gradleVersion: '7.5'),
        GradleAgpTestData(true, agpVersion: '7.2', gradleVersion: '7.4'),
        GradleAgpTestData(true, agpVersion: '7.1', gradleVersion: '7.3.3'),
        GradleAgpTestData(true, agpVersion: '7.0', gradleVersion: '7.2'),
        GradleAgpTestData(true, agpVersion: '4.2.0', gradleVersion: '7.0'),
        GradleAgpTestData(true, agpVersion: '4.1.0', gradleVersion: '6.7.1'),
        GradleAgpTestData(true, agpVersion: '4.0.0', gradleVersion: '6.5'),
        GradleAgpTestData(true, agpVersion: '3.6.0', gradleVersion: '6.1.1'),
        GradleAgpTestData(true, agpVersion: '3.5.0', gradleVersion: '5.6.4'),
        GradleAgpTestData(true, agpVersion: '3.4.0', gradleVersion: '5.4.1'),
        GradleAgpTestData(true, agpVersion: '3.3.0', gradleVersion: '5.1.1'),
      ];
      for (final GradleAgpTestData data in testData) {
        expect(
          validateGradleAndAgp(
            BufferLogger.test(),
            gradleV: data.gradleVersion,
            agpV: data.agpVersion,
          ),
          data.validPair ? isTrue : isFalse,
          reason: 'G: ${data.gradleVersion}, AGP: ${data.agpVersion}'
        );
      }
    });

    // TODO add test for _isWithinVersionRange

    testWithoutContext('validates gradle/agp versions', () async {
      expect(
          validateJavaGradle(javaV: '11', gradleV: '7.5'),
          isFalse,
        );
    });
  });
}

class GradleAgpTestData {
  GradleAgpTestData(this.validPair, {this.gradleVersion, this.agpVersion});
  final String? gradleVersion;
  final String? agpVersion;
  final bool validPair;
}
