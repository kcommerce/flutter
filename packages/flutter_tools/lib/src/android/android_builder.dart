// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base/context.dart';
import '../build_info.dart';
import '../project.dart';

/// The builder in the current context.
AndroidBuilder? get androidBuilder {
  return context.get<AndroidBuilder>();
}

abstract class AndroidBuilder {
  const AndroidBuilder();
  /// Builds an AAR artifact.
  Future<void> buildAar({
    required FlutterProject project,
    required Set<AndroidBuildInfo> androidBuildInfo,
    required String target,
    String? outputDirectoryPath,
    required String buildNumber,
  });

  /// Builds an APK artifact.
  Future<void> buildApk({
    required FlutterProject project,
    required AndroidBuildInfo androidBuildInfo,
    required String target,
    bool configOnly = false,
  });

  /// Builds an App Bundle artifact.
  Future<void> buildAab({
    required FlutterProject project,
    required AndroidBuildInfo androidBuildInfo,
    required String target,
    bool validateDeferredComponents = true,
    bool deferredComponentsEnabled = false,
    bool configOnly = false,
  });

  /// Returns a list of available build variant from the Android project.
  Future<List<String>> getBuildVariants({required FlutterProject project});
<<<<<<< HEAD
=======

  /// Returns the application id for the given build variant.
  Future<String> getApplicationIdForVariant(
    String buildVariant, {
    required FlutterProject project,
  });

  /// Returns a list of app link domains for the given build variant.
  Future<List<String>> getAppLinkDomainsForVariant(
    String buildVariant, {
    required FlutterProject project,
  });
>>>>>>> 2524052335ec76bb03e04ede244b071f1b86d190
}
