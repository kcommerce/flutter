// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/precache.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/version.dart';
import 'package:mockito/mockito.dart';

import '../src/context.dart';
import '../src/mocks.dart';

void main() {
  final MockDeviceManager mockDeviceManager = MockDeviceManager();

  group('precache', () {
    final MockCache cache = MockCache();
    final MockFlutterVersion flutterVersion = MockFlutterVersion();
   
    Set<DevelopmentArtifact> artifacts;

    when(cache.isUpToDate()).thenReturn(false);
    when(cache.updateAll(any)).thenAnswer((Invocation invocation) {
      artifacts = invocation.positionalArguments.first;
      return Future.value(null);
    });
    when(flutterVersion.isStable).thenReturn(true);

    testUsingContext('Adds artifact flags to requested artifacts', () async {
      final PrecacheCommand command = PrecacheCommand(); 
      applyMocksToCommand(command);
      await createTestCommandRunner(command).run(
        const <String>['precache', '--ios', '--android', '--web', '--macos', '--linux', '--windows']
      );
       expect(artifacts, unorderedEquals(<DevelopmentArtifact>{
         DevelopmentArtifact.universal,
         DevelopmentArtifact.iOS,
         DevelopmentArtifact.android,
         DevelopmentArtifact.web,
         DevelopmentArtifact.macOS,
         DevelopmentArtifact.linux,
         DevelopmentArtifact.windows,
       }));
      }, overrides: <Type, Generator>{
        Cache: () => cache,
      });

    testUsingContext('Adds artifact flags to requested artifacts on stable', () async {
      // Rlease lock between test cases.
      Cache.releaseLockEarly();
      final PrecacheCommand command = PrecacheCommand(); 
      applyMocksToCommand(command);
      await createTestCommandRunner(command).run(
       const <String>['precache', '--ios', '--android', '--web', '--macos', '--linux', '--windows']
      );
     expect(artifacts, unorderedEquals(<DevelopmentArtifact>{
       DevelopmentArtifact.universal,
       DevelopmentArtifact.iOS,
       DevelopmentArtifact.android,
     }));
    }, overrides: <Type, Generator>{
      Cache: () => cache,
      FlutterVersion: () => flutterVersion,
    });
  });
}

class MockFlutterVersion extends Mock implements FlutterVersion {}
class MockCache extends Mock implements Cache {}
