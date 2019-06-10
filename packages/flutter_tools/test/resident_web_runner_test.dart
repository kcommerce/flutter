

import 'dart:async';

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/resident_runner.dart';
import 'package:flutter_tools/src/resident_web_runner.dart';
import 'package:flutter_tools/src/web/chrome.dart';
import 'package:flutter_tools/src/web/compile.dart';
import 'package:mockito/mockito.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

import 'src/common.dart';
import 'src/testbed.dart';

void main() {
  group('ResidentWebRunner', () {
    Testbed testbed;
    MockWebCompilationProxy mockWebCompilationProxy;
    MockChromeLauncher mockChromeLauncher;
    MockChrome mockChrome;

    setUp(() {
      mockWebCompilationProxy = MockWebCompilationProxy();
      mockChromeLauncher = MockChromeLauncher();
      mockChrome = MockChrome();
      testbed = Testbed(setup: () async {
        fs.file('pubspec.yaml').createSync();
        fs.file('.packages').createSync();
        fs.file(fs.path.join('lib', 'main.dart')).createSync(recursive: true);
        fs.file(fs.path.join('web', 'index.html')).createSync(recursive: true);
        when(mockChrome.chromeConnection).thenReturn(MockChromeConnection());
        when(mockChromeLauncher.launch(
          any,
          headless: anyNamed('headless')
        )).thenAnswer((Invocation invocation) {
          return Future<Chrome>.value(mockChrome);
        });
      }, overrides: <Type, Generator>{
        WebCompilationProxy: () => mockWebCompilationProxy,
        ChromeLauncher: () => mockChromeLauncher,
      });
    });

    test('initializes web compiler with correct values for debug', () => testbed.run(() async {
      final Completer<void> completer = Completer<void>();
      final ResidentWebRunner residentCompiler = ResidentWebRunner(
        <FlutterDevice>[],
        debuggingOptions: DebuggingOptions.enabled(
          BuildInfo.debug,
        ),
        flutterProject: FlutterProject.current(),
        ipv6: true,
      );
      when(mockWebCompilationProxy.initialize(
        projectDirectory: fs.currentDirectory,
        targets: <String>[fs.path.join('lib', 'main.dart')],
        release: false
      )).thenAnswer((Invocation invocation) {
        return Future<bool>.value(true);
      });

      unawaited(residentCompiler.run(appStartedCompleter: completer));
      await completer.future;
    }));

    test('initializes web compiler with correct values for release', () => testbed.run(() async {
      final Completer<void> completer = Completer<void>();
      final ResidentWebRunner residentCompiler = ResidentWebRunner(
        <FlutterDevice>[],
        debuggingOptions: DebuggingOptions.disabled(
          BuildInfo.release,
        ),
        flutterProject: FlutterProject.current(),
        ipv6: true,
      );
      when(mockWebCompilationProxy.initialize(
        projectDirectory: fs.currentDirectory,
        targets: <String>[fs.path.join('lib', 'main.dart')],
        release: true
      )).thenAnswer((Invocation invocation) {
        return Future<bool>.value(true);
      });

      unawaited(residentCompiler.run());
      await completer.future;
    }));
  });
}

class MockWebCompilationProxy extends Mock implements WebCompilationProxy {}
class MockChromeLauncher extends Mock implements ChromeLauncher {}
class MockChrome extends Mock implements Chrome {}
class MockChromeConnection extends Mock implements ChromeConnection {}


