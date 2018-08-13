// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/utils.dart';
import 'package:flutter_devicelab/tasks/perf_tests.dart';

class HelloWorldMemoryTest extends MemoryTest {
  HelloWorldMemoryTest() : super(
    '${flutterDirectory.path}/examples/hello_world',
    'lib/main.dart',
    'io.flutter.examples.hello_world',
  );

  /// Launch an app with no instrumentation and measure its memory usage after
  /// 1.5s and 3.0s.
  @override
  Future<void> useMemory() async {
    print('launching $project$test on device...');
    await flutter('run', options: <String>[
      '--verbose',
      '--release',
      '--no-resident',
      '-d', device.deviceId,
      test,
    ]);
    await new Future<Null>.delayed(const Duration(milliseconds: 1500));
    await recordStart();
    await new Future<Null>.delayed(const Duration(milliseconds: 3000));
    await recordEnd();
  }
}

Future<Null> main() async {
  await task(new HelloWorldMemoryTest().run);
}
