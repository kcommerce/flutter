// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dwds/dwds.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/base/net.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/resident_runner.dart';
import 'package:flutter_tools/src/build_runner/resident_web_runner.dart';
import 'package:flutter_tools/src/build_runner/web_fs.dart';
import 'package:flutter_tools/src/web/chrome.dart';
import 'package:flutter_tools/src/web/web_device.dart';
import 'package:meta/meta.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:vm_service/vm_service.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

import '../src/common.dart';
import '../src/testbed.dart';

void main() {
  Testbed testbed;
  MockFlutterWebFs mockWebFs;
  ResidentWebRunner residentWebRunner;
  MockFlutterDevice mockFlutterDevice;

  setUp(() {
    mockWebFs = MockFlutterWebFs();
    final MockWebDevice mockWebDevice = MockWebDevice();
    mockFlutterDevice = MockFlutterDevice();
    when(mockFlutterDevice.device).thenReturn(mockWebDevice);
    testbed = Testbed(
      setup: () {
        residentWebRunner = residentWebRunner = DwdsWebRunnerFactory().createWebRunner(
          mockFlutterDevice,
          flutterProject: FlutterProject.current(),
          debuggingOptions: DebuggingOptions.disabled(BuildInfo.release),
          ipv6: true,
          stayResident: true,
          dartDefines: const <String>[],
          urlTunneller: null,
        ) as ResidentWebRunner;
      },
      overrides: <Type, Generator>{
        WebFsFactory: () => ({
          @required String target,
          @required FlutterProject flutterProject,
          @required BuildInfo buildInfo,
          @required bool skipDwds,
          @required bool initializePlatform,
          @required String hostname,
          @required String port,
          @required UrlTunneller urlTunneller,
          @required List<String> dartDefines,
        }) async {
          return mockWebFs;
        },
      },
    );
  });

  void _setupMocks() {
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file(globals.fs.path.join('lib', 'main.dart')).createSync(recursive: true);
    globals.fs.file(globals.fs.path.join('web', 'index.html')).createSync(recursive: true);
    when(mockWebFs.connect(any)).thenThrow(StateError('debugging not supported'));
  }

  test('Can successfully run and connect without vmservice', () => testbed.run(() async {
    _setupMocks();
    final DelegateLogger delegateLogger = globals.logger as DelegateLogger;
    final MockStatus mockStatus = MockStatus();
    delegateLogger.status = mockStatus;
    final Completer<DebugConnectionInfo> connectionInfoCompleter = Completer<DebugConnectionInfo>();
    unawaited(residentWebRunner.run(
      connectionInfoCompleter: connectionInfoCompleter,
    ));
    final DebugConnectionInfo debugConnectionInfo = await connectionInfoCompleter.future;

    expect(debugConnectionInfo.wsUri, null);
    verify(mockStatus.stop()).called(1);
  }, overrides: <Type, Generator>{
    Logger: () => DelegateLogger(BufferLogger(
      terminal: AnsiTerminal(
        stdio: null,
        platform: const LocalPlatform(),
      ),
      outputPreferences: OutputPreferences.test(),
    )),
  }));

  test('Can full restart after attaching', () => testbed.run(() async {
    _setupMocks();
    final Completer<DebugConnectionInfo> connectionInfoCompleter = Completer<DebugConnectionInfo>();
    unawaited(residentWebRunner.run(
      connectionInfoCompleter: connectionInfoCompleter,
    ));
    await connectionInfoCompleter.future;
    when(mockWebFs.recompile()).thenAnswer((Invocation _) async {
      return true;
    });
    final OperationResult result = await residentWebRunner.restart(fullRestart: true);

    expect(result.code, 0);
  }));

  test('Fails on compilation errors in hot restart', () => testbed.run(() async {
    _setupMocks();
    final Completer<DebugConnectionInfo> connectionInfoCompleter = Completer<DebugConnectionInfo>();
    unawaited(residentWebRunner.run(
      connectionInfoCompleter: connectionInfoCompleter,
    ));
    await connectionInfoCompleter.future;
    when(mockWebFs.recompile()).thenAnswer((Invocation _) async {
      return false;
    });
    final OperationResult result = await residentWebRunner.restart(fullRestart: true);

    expect(result.code, 1);
    expect(result.message, contains('Failed to recompile application.'));
  }));

  test('Correctly peforms a full refresh on attached chrome device.', () => testbed.run(() async {
    _setupMocks();
    final MockChromeDevice chromeDevice = MockChromeDevice();
    final MockChrome chrome = MockChrome();
    final MockChromeConnection mockChromeConnection = MockChromeConnection();
    final MockChromeTab mockChromeTab = MockChromeTab();
    final MockWipConnection mockWipConnection = MockWipConnection();
    when(mockChromeConnection.getTab(any)).thenAnswer((Invocation invocation) async {
      return mockChromeTab;
    });
    when(mockChromeTab.connect()).thenAnswer((Invocation invocation) async {
      return mockWipConnection;
    });
    when(chrome.chromeConnection).thenReturn(mockChromeConnection);
    launchChromeInstance(chrome);
    when(mockFlutterDevice.device).thenReturn(chromeDevice);
    final Completer<DebugConnectionInfo> connectionInfoCompleter = Completer<DebugConnectionInfo>();
    unawaited(residentWebRunner.run(
      connectionInfoCompleter: connectionInfoCompleter,
    ));
    await connectionInfoCompleter.future;
    when(mockWebFs.recompile()).thenAnswer((Invocation _) async {
      return true;
    });
    final OperationResult result = await residentWebRunner.restart(fullRestart: true);

    expect(result.code, 0);
    verify(mockWipConnection.sendCommand('Page.reload', <String, Object>{
      'ignoreCache': true,
    })).called(1);
  }));

}

class MockWebDevice extends Mock implements Device {}
class MockBuildDaemonCreator extends Mock implements BuildDaemonCreator {}
class MockFlutterWebFs extends Mock implements WebFs {}
class MockDebugConnection extends Mock implements DebugConnection {}
class MockVmService extends Mock implements VmService {}
class MockStatus extends Mock implements Status {}
class MockFlutterDevice extends Mock implements FlutterDevice {}
class MockChromeDevice extends Mock implements ChromeDevice {}
class MockChrome extends Mock implements Chrome {}
class MockChromeConnection extends Mock implements ChromeConnection {}
class MockChromeTab extends Mock implements ChromeTab {}
class MockWipConnection extends Mock implements WipConnection {}
