// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/drive/web_driver_service.dart';
import 'package:package_config/package_config_types.dart';

import '../src/common.dart';
import '../src/fake_process_manager.dart';

void main() {
  testWithoutContext('WebDriverService catches SocketExceptions cleanly and includes link to documentation', () async {
    final BufferLogger logger = BufferLogger.test();
    final WebDriverService service = WebDriverService(
      logger: logger,
      processUtils: ProcessUtils(
        logger: logger,
        processManager: FakeProcessManager.empty(),
      ),
      dartSdkPath: 'dart',
    );
    const String link = 'https://flutter.dev/docs/testing/integration-tests#running-in-a-browser';
    try {
      await service.startTest(
        'foo.test',
        <String>[],
        <String, String>{},
        PackageConfig(<Package>[Package('test', Uri.base)]),
        driverPort: 1,
        headless: true,
        browserName: 'chrome',
      );
      fail('WebDriverService did not throw as expected.');
    } on ToolExit catch (error) {
      expect(error.message, isNot(contains('SocketException')));
      expect(error.message, contains(link));
    }
  });

  testWithoutContext(
      'WebDriverService use the correct desired capabilities from map parameter',
      () async {
    final Map<String, Object> desiredCapabilities = <String, Object>{
      'chrome': <String, Object>{
        'acceptInsecureCerts': true,
        'goog:loggingPrefs': <String, String>{
          'browser': 'INFO',
          'performance': 'ALL'
        },
        'chromeOptions': <String, Object>{
          'w3c': false,
          'args': <String>[
            '--bwsi',
            '--disable-background-timer-throttling',
            '--disable-default-apps',
            '--disable-popup-blocking',
            '--disable-translate',
            '--no-default-browser-check',
            '--no-sandbox',
            '--no-first-run',
            '--load-extension=/Users/PussyCat/debug_extension/metamask'
          ],
          'perfLoggingPrefs': <String, String>{
            'traceCategories': 'devtools.timeline,v8,blink.console,benchmark,blink,blink.user_timing'
          }
        }
      }
    };
    final BufferLogger logger = BufferLogger.test();
    final WebDriverService service = WebDriverService(
      logger: logger,
      processUtils: ProcessUtils(
        logger: logger,
        processManager: FakeProcessManager.empty(),
      ),
      dartSdkPath: 'dart',
    );
    try {
      await service.startTest(
        'foo.test',
        <String>[],
        <String, String>{},
        PackageConfig(<Package>[Package('test', Uri.base)]),
        driverPort: 1,
        headless: true,
        browserName: 'chrome',
        allBrowsersDesiredCapabilities: desiredCapabilities,
      );
      fail('WebDriverService did not throw as expected.');
    } on ToolExit catch (_) {
      expect(service.desiredCapabilities, desiredCapabilities['chrome']);
    }
  });
}
