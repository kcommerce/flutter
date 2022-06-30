// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/flutter_project_metadata.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/migrate/migrate_compute.dart';
import 'package:flutter_tools/src/migrate/migrate_result.dart';
import 'package:flutter_tools/src/migrate/migrate_utils.dart';
import 'package:flutter_tools/src/project.dart';

import '../src/common.dart';
import '../src/context.dart';
import 'test_data/migrate_project.dart';
import 'test_utils.dart';


void main() {
  late FileSystem fileSystem;
  late File manifestFile;
  late BufferLogger logger;
  late MigrateUtils utils;
  late MigrateContext context;
  late Directory targetFlutterDirectory;
  late Directory currentDir;

  setUpAll(() async {
    fileSystem = globals.localFileSystem;
    currentDir = createResolvedTempDirectorySync('current_app.');
    logger = BufferLogger.test();
    utils = MigrateUtils(
      logger: logger,
      fileSystem: fileSystem,
      platform: globals.platform,
      processManager: globals.processManager,
    );
    print('1');
    await MigrateProject.installProject('version:1.22.6_stable', currentDir);
    print('2');
    final FlutterProjectFactory flutterFactory = FlutterProjectFactory(logger: logger, fileSystem: fileSystem);
    final FlutterProject flutterProject = flutterFactory.fromDirectory(currentDir);
    print('3');
    context = MigrateContext(
      migrateResult: MigrateResult.empty(),
      flutterProject: flutterProject,
      blacklistPrefixes: <String>{},
      logger: logger,
      verbose: true,
      fileSystem: fileSystem,
      status: logger.startSpinner(),
      migrateUtils: utils,
    );
    print('4');
    targetFlutterDirectory = fileSystem.directory('targetFlutterDir');
  });

  group('MigrateFlutterProject', () {
    print('5');
    testUsingContext('MigrateBaseFlutterProject creates', () async {
      final Directory workingDir = fileSystem.directory('migrate_working_dir');
      final Directory baseDir = fileSystem.directory('base_dir');
      workingDir.createSync(recursive: true);
    print('6');
      MigrateBaseFlutterProject baseProject = MigrateBaseFlutterProject(
        path: null,
        directory: baseDir,
        name: 'base',
        androidLanguage: 'java',
        iosLanguage: 'objc',
        platformWhitelist: null,
      );

    print('7');
      baseProject.createProject(
        context,
        <String>['5391447fae6209bb21a89e6a5a6583cac1af9b4b'], //revisionsList
        <String, List<MigratePlatformConfig>>{'5391447fae6209bb21a89e6a5a6583cac1af9b4b': <MigratePlatformConfig>[MigratePlatformConfig(platform: SupportedPlatform.android)]}, //revisionToConfigs
        '5391447fae6209bb21a89e6a5a6583cac1af9b4b', //fallbackRevision
        '5391447fae6209bb21a89e6a5a6583cac1af9b4b', //targetRevision
        targetFlutterDirectory, //targetFlutterDirectory
      );

    print('8');
      expect(baseDir.childFile('pubspec.yaml').existsSync(), true);
    });

  });
}
