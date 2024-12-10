// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  if (!(Platform.isLinux || Platform.isMacOS)) {
    print('This test must be run on a POSIX host. Skipping...');
    exit(0);
  }
  final bool adbExists =
      Process.runSync('which', <String>['adb']).exitCode == 0;
  if (!adbExists) {
    print(r'This test needs ADB to exist on the $PATH. Skipping...');
    exit(0);
  }
  bool shouldResetDevSettings = false;
  ProcessResult checkDevSettingsResult = Process.runSync('adb', <String>[
    'shell',
    'settings',
    'get',
    'global',
    'development_settings_enabled',
  ]);
  if (checkDevSettingsResult.stdout.startsWith('0')) {
    print('Enabling developer settings...');
    shouldResetDevSettings = true;
    Process.runSync('adb', <String>[
      'shell',
      'settings',
      'put',
      'global',
      'development_settings_enabled',
      '1',
    ]);
  }
  print('Adding Synthetic notch...');
  Process.runSync('adb', <String>[
    'shell',
    'cmd',
    'overlay',
    'enable',
    'com.android.internal.display.cutout.emulation.tall',
  ]);
  // Await future.delay 
  Process.runSync('sleep', <String>['1']);
  print('Starting test.');
  final FlutterDriver driver = await FlutterDriver.connect();
  final String data = await driver.requestData(
    null,
    timeout: const Duration(minutes: 1),
  );
  await driver.close();
  print('Test finished. Reverting Adb changes...');
  if (shouldResetDevSettings) {
    print('Disabling developer settings...');
    Process.runSync('adb', <String>[
      'shell',
      'settings',
      'put',
      'global',
      'development_settings_enabled',
      '0',
    ]);
  }
  print('Removing Synthetic notch...');
  Process.runSync('adb', <String>[
    'shell',
    'cmd',
    'overlay',
    'disable',
    'com.android.internal.display.cutout.emulation.tall',
  ]);

  final Map<String, dynamic> result = jsonDecode(data) as Map<String, dynamic>;
  print(result);
  exit(result['result'] == 'true' ? 0 : 1);
}
