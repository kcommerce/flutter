// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:test/test.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';

import 'src/context.dart';

void main() {
  group('Project', () {
    testInMemory('knows location', () {
      final Directory directory = fs.directory('myproject');
      expect(new FlutterProject(directory).directory, directory);
    });
    group('organization names set', () {
      testInMemory('is empty, if project not created', () async {
        final FlutterProject project = someProject();
        expect(await project.organizationNames(), isEmpty);
      });
      testInMemory('is empty, if no platform folders exist', () async {
        final FlutterProject project = someProject();
        project.directory.createSync();
        expect(await project.organizationNames(), isEmpty);
      });
      testInMemory('is populated from iOS bundle identifier', () async {
        final FlutterProject project = someProject();
        addIosWithBundleId(project.directory, 'io.flutter.someProject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is populated from Android application ID', () async {
        final FlutterProject project = someProject();
        addAndroidWithApplicationId(project.directory, 'io.flutter.someproject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is populated from iOS bundle identifier in plugin example', () async {
        final FlutterProject project = someProject();
        addIosWithBundleId(project.example.directory, 'io.flutter.someProject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is populated from Android application ID in plugin example', () async {
        final FlutterProject project = someProject();
        addAndroidWithApplicationId(project.example.directory, 'io.flutter.someproject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is populated from Android group in plugin', () async {
        final FlutterProject project = someProject();
        addAndroidWithGroup(project.directory, 'io.flutter.someproject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is singleton, if sources agree', () async {
        final FlutterProject project = someProject();
        addIosWithBundleId(project.directory, 'io.flutter.someProject');
        addAndroidWithApplicationId(project.directory, 'io.flutter.someproject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is non-singleton, if sources disagree', () async {
        final FlutterProject project = someProject();
        addIosWithBundleId(project.directory, 'io.flutter.someProject');
        addAndroidWithApplicationId(project.directory, 'io.clutter.someproject');
        expect(
          await project.organizationNames(),
          <String>['io.flutter', 'io.clutter'],
        );
      });
    });
  });
}

FlutterProject someProject() =>
    new FlutterProject(fs.directory('some_project'));

void testInMemory(String description, Future<Null> testMethod()) {
  testUsingContext(
    description,
    testMethod,
    overrides: <Type, Generator>{
      FileSystem: () => new MemoryFileSystem(),
    },
  );
}

void addIosWithBundleId(Directory directory, String id) {
  directory
      .childDirectory('ios')
      .childDirectory('Runner.xcodeproj')
      .childFile('project.pbxproj')
        ..createSync(recursive: true)
        ..writeAsStringSync(projectFileWithBundleId(id));
}

void addAndroidWithApplicationId(Directory directory, String id) {
  directory
      .childDirectory('android')
      .childDirectory('app')
      .childFile('build.gradle')
        ..createSync(recursive: true)
        ..writeAsStringSync(gradleFileWithApplicationId(id));
}

void addAndroidWithGroup(Directory directory, String id) {
  directory.childDirectory('android').childFile('build.gradle')
    ..createSync(recursive: true)
    ..writeAsStringSync(gradleFileWithGroupId(id));
}

String projectFileWithBundleId(String id) {
  return '''
97C147061CF9000F007C117D /* Debug */ = {
  isa = XCBuildConfiguration;
  baseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;
  buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = $id;
    PRODUCT_NAME = "\$(TARGET_NAME)";
  };
  name = Debug;
};
''';
}

String gradleFileWithApplicationId(String id) {
  return '''
apply plugin: 'com.android.application'
android {
    compileSdkVersion 27

    defaultConfig {
        applicationId '$id'
    }
}
''';
}

String gradleFileWithGroupId(String id) {
  return '''
group '$id'
version '1.0-SNAPSHOT'

apply plugin: 'com.android.library'

android {
    compileSdkVersion 27
}
''';
}
