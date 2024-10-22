// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base/error_handling_io.dart';
import '../base/fingerprint.dart';
import '../build_info.dart';
import '../cache.dart';
import '../flutter_plugins.dart';
import '../globals.dart' as globals;
import '../project.dart';

/// For a given build, determines whether dependencies have changed since the
/// last call to processPods, then calls processPods with that information.
Future<void> processPodsIfNeeded(
  XcodeBasedProject xcodeProject,
  String buildDirectory,
  BuildMode buildMode, {
  bool forceCocoaPodsOnly = false,
}) async {
  final FlutterProject project = xcodeProject.parent;

  // When using Swift Package Manager, the Podfile may not exist so if there
  // isn't a Podfile, skip processing pods.
  if (project.usesSwiftPackageManager && !xcodeProject.podfile.existsSync() && !forceCocoaPodsOnly) {
    return;
  }

  // If there are no plugins and if the project is a not module with an existing
  // podfile, skip processing pods
  if (!hasPlugins(project) && !(project.isModule && xcodeProject.podfile.existsSync())) {
    return;
  }

  // If forcing the use of only CocoaPods, but the project is using Swift
  // Package Manager, print a warning that CocoaPods will be used.
  if (forceCocoaPodsOnly && project.usesSwiftPackageManager) {
    globals.logger.printWarning(
        'Swift Package Manager does not yet support this command. '
        'CocoaPods will be used instead.');

    // If CocoaPods has been deintegrated, add it back.
    if (!xcodeProject.podfile.existsSync()) {
      await globals.cocoaPods?.setupPodfile(xcodeProject);
    }

    // Delete Swift Package Manager manifest to invalidate fingerprinter
    ErrorHandlingFileSystem.deleteIfExists(
      xcodeProject.flutterPluginSwiftPackageManifest,
    );
  }

  // If the Xcode project, Podfile, generated plugin Swift Package, or podhelper
  // have changed since last run, pods should be updated.
  final Fingerprinter fingerprinter = Fingerprinter(
    fingerprintPath: globals.fs.path.join(buildDirectory, 'pod_inputs.fingerprint'),
    paths: <String>[
      xcodeProject.xcodeProjectInfoFile.path,
      xcodeProject.podfile.path,
      if (xcodeProject.flutterPluginSwiftPackageManifest.existsSync())
        xcodeProject.flutterPluginSwiftPackageManifest.path,
      globals.fs.path.join(
        Cache.flutterRoot!,
        'packages',
        'flutter_tools',
        'bin',
        'podhelper.rb',
      ),
    ],
    fileSystem: globals.fs,
    logger: globals.logger,
  );

  final bool didPodInstall = await globals.cocoaPods?.processPods(
    xcodeProject: xcodeProject,
    buildMode: buildMode,
    dependenciesChanged: !fingerprinter.doesFingerprintMatch(),
  ) ?? false;
  if (didPodInstall) {
    fingerprinter.writeFingerprint();
  }
}
