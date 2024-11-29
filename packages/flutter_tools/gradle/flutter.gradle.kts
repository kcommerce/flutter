// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file exists solely for compatibility with projects that have
// not migrated to the declarative apply of the Flutter Gradle Plugin.

logger.error(
    """
    You are applying Flutter's main Gradle plugin imperatively using
    the apply script method, which is deprecated and will be removed in a future
    release. Migrate to applying Gradle plugins with the declarative plugins
    block: https://flutter.dev/to/flutter-gradle-plugin-apply
    """.trimIndent()
)

val pathToThisDirectory = buildscript.sourceFile?.parentFile
apply(from = "$pathToThisDirectory/src/main/groovy/flutter.groovy")
