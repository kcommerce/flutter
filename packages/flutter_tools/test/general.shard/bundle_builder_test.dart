// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/build_system/targets/icon_tree_shaker.dart';
import 'package:flutter_tools/src/bundle.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
import 'package:flutter_tools/src/project.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/test_build_system.dart';
import '../src/testbed.dart';

// Tests for BundleBuilder.
void main() {
  testUsingContext('Copies assets to expected directory after building', () async {
    final BuildSystem buildSystem = TestBuildSystem.all(
      BuildResult(success: true),
      (Target target, Environment environment) {
        environment.outputDir.childFile('kernel_blob.bin').createSync(recursive: true);
        environment.outputDir.childFile('isolate_snapshot_data').createSync();
        environment.outputDir.childFile('vm_snapshot_data').createSync();
        environment.outputDir.childFile('LICENSE').createSync(recursive: true);
      }
    );

    await BundleBuilder().build(
      platform: TargetPlatform.ios,
      buildInfo: const BuildInfo(
        BuildMode.debug,
        null,
        treeShakeIcons: false
      ),
      project: FlutterProject.fromDirectoryTest(globals.fs.currentDirectory),
      mainPath: globals.fs.path.join('lib', 'main.dart'),
      assetDirPath: 'example',
      depfilePath: 'example.d',
      buildSystem: buildSystem
    );
    expect(globals.fs.file(globals.fs.path.join('example', 'kernel_blob.bin')).existsSync(), true);
    expect(globals.fs.file(globals.fs.path.join('example', 'LICENSE')).existsSync(), true);
    expect(globals.fs.file(globals.fs.path.join('example.d')).existsSync(), false);
  }, overrides: <Type, Generator>{
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
  });

  testUsingContext('Handles build system failure', () {
    expect(
      () => BundleBuilder().build(
        platform: TargetPlatform.ios,
        buildInfo: const BuildInfo(
          BuildMode.debug,
          null,
          treeShakeIcons: false
        ),
        project: FlutterProject.fromDirectoryTest(globals.fs.currentDirectory),
        mainPath: 'lib/main.dart',
        assetDirPath: 'example',
        depfilePath: 'example.d',
        buildSystem: TestBuildSystem.all(BuildResult(success: false))
      ),
      throwsToolExit()
    );
  }, overrides: <Type, Generator>{
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
  });

  testUsingContext('Passes correct defines to build system', () async {
    final FlutterProject project = FlutterProject.fromDirectoryTest(globals.fs.currentDirectory);
    final String mainPath = globals.fs.path.join('lib', 'main.dart');
    const String assetDirPath = 'example';
    const String depfilePath = 'example.d';
    Environment env;
    final BuildSystem buildSystem = TestBuildSystem.all(
      BuildResult(success: true),
      (Target target, Environment environment) {
        env = environment;
        environment.outputDir.childFile('kernel_blob.bin').createSync(recursive: true);
        environment.outputDir.childFile('isolate_snapshot_data').createSync();
        environment.outputDir.childFile('vm_snapshot_data').createSync();
        environment.outputDir.childFile('LICENSE').createSync(recursive: true);
      }
    );

    await BundleBuilder().build(
      platform: TargetPlatform.ios,
      buildInfo: const BuildInfo(
        BuildMode.debug,
        null,
        trackWidgetCreation: true,
        extraFrontEndOptions: <String>['test1', 'test2'],
        extraGenSnapshotOptions: <String>['test3', 'test4'],
        fileSystemRoots: <String>['test5', 'test6'],
        fileSystemScheme: 'test7',
        dartDefines: <String>['test8', 'test9'],
        treeShakeIcons: true,
      ),
      project: project,
      mainPath: mainPath,
      assetDirPath: assetDirPath,
      depfilePath: depfilePath,
      buildSystem: buildSystem
    );

    expect(env, isNotNull);
    expect(env.defines[kBuildMode], 'debug');
    expect(env.defines[kTargetPlatform], 'ios');
    expect(env.defines[kTargetFile], mainPath);
    expect(env.defines[kTrackWidgetCreation], 'true');
    expect(env.defines[kExtraFrontEndOptions], 'test1,test2');
    expect(env.defines[kExtraGenSnapshotOptions], 'test3,test4');
    expect(env.defines[kFileSystemRoots], 'test5,test6');
    expect(env.defines[kFileSystemScheme], 'test7');
    expect(env.defines[kDartDefines], encodeDartDefines(<String>['test8', 'test9']));
    expect(env.defines[kIconTreeShakerFlag], 'true');
    expect(env.defines[kDeferredComponents], 'false');
  }, overrides: <Type, Generator>{
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
  });
}
