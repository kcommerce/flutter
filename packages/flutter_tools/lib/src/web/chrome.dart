// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

import '../base/common.dart';
import '../base/context.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/os.dart';
import '../base/platform.dart';

/// The [ChromeLauncher] instance.
ChromeLauncher get chromeLauncher => context.get<ChromeLauncher>();

const String _kChromeEnvironment = 'CHROME_EXECUTABLE';
const String _kLinuxExecutable = 'google-chrome';
const String _kMacOSExecutable =
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const String _kWindowsExecutable = r'Google\Chrome\Application\chrome.exe';
final List<String> _kWindowsPrefixes = <String>[
  platform.environment['LOCALAPPDATA'],
  platform.environment['PROGRAMFILES'],
  platform.environment['PROGRAMFILES(X86)']
];

// Responsible for launching chrome with devtools configured.
class ChromeLauncher {
  const ChromeLauncher();

  static final Completer<Chrome> _currentCompleter = Completer<Chrome>();

  /// Launch the chrome browser to a particular `host` page.
  Future<Chrome> launch(String url) async {
    final Directory dataDir = fs.systemTempDirectory.createTempSync();
    final int port = await os.findFreePort();
    final List<String> args = <String>[
      // Using a tmp directory ensures that a new instance of chrome launches
      // allowing for the remote debug port to be enabled.
      '--user-data-dir=${dataDir.path}',
      '--remote-debugging-port=$port',
      // When the DevTools has focus we don't want to slow down the application.
      '--disable-background-timer-throttling',
      // Since we are using a temp profile, disable features that slow the
      // Chrome launch.
      '--disable-extensions',
      '--disable-popup-blocking',
      '--bwsi',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-default-apps',
      '--disable-translate',
      url,
    ];
    final Process process = await Process.start(_executable, args);

    // Wait until the DevTools are listening before trying to connect.
    await process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((String line) => line.startsWith('DevTools listening'))
        .timeout(Duration(seconds: 60),
            onTimeout: () =>
                throw Exception('Unable to connect to Chrome DevTools.'));

    return _connect(Chrome._(
      port,
      ChromeConnection('localhost', port),
      process: process,
      dataDir: dataDir,
    ));
  }

  static Future<Chrome> _connect(Chrome chrome) async {
    if (_currentCompleter.isCompleted) {
      throwToolExit('Only one instance of chrome can be started.');
    }
    // The connection is lazy. Try a simple call to make sure the provided
    // connection is valid.
    try {
      await chrome.chromeConnection.getTabs();
    } catch (e) {
      await chrome.close();
      throwToolExit(
          'Unable to connect to Chrome debug port: ${chrome.debugPort}\n $e');
    }
    _currentCompleter.complete(chrome);
    return chrome;
  }

  /// Connects to an instance of Chrome with an open debug port.
  static Future<Chrome> fromExisting(int port) async =>
      _connect(Chrome._(port, ChromeConnection('localhost', port)));

  static Future<Chrome> get connectedInstance => _currentCompleter.future;
}

String get _executable {
  if (platform.environment.containsKey(_kChromeEnvironment)) {
    return platform.environment[_kChromeEnvironment];
  }
  if (platform.isLinux) {
    return _kLinuxExecutable;
  }
  if (platform.isMacOS) {
    return _kMacOSExecutable;
  }
  if (platform.isWindows) {
    return fs.path.join(
        _kWindowsPrefixes.firstWhere((String prefix) {
          if (prefix == null) {
            return false;
          }
          final String path = fs.path.join(prefix, _kWindowsExecutable);
          return fs.file(path).existsSync();
        }, orElse: () => '.'),
        _kWindowsExecutable);
  }
  throw StateError('Unexpected platform type.');
}

/// A class for managing an instance of Chrome.
class Chrome {
  Chrome._(
    this.debugPort,
    this.chromeConnection, {
    Process process,
    Directory dataDir,
  })  : _process = process,
        _dataDir = dataDir;

  final int debugPort;
  final Process _process;
  final Directory _dataDir;
  final ChromeConnection chromeConnection;

  static Completer<Chrome> _currentCompleter = Completer<Chrome>();

  Future<void> close() async {
    if (_currentCompleter.isCompleted) {
      _currentCompleter = Completer<Chrome>();
    }
    chromeConnection.close();
    _process?.kill(ProcessSignal.SIGKILL);
    await _process?.exitCode;
    try {
      // Chrome starts another process as soon as it dies that modifies the
      // profile information. Give it some time before attempting to delete
      // the directory.
      await Future<void>.delayed(Duration(milliseconds: 500));
      await _dataDir?.delete(recursive: true);
    } catch (_) {
      // Silently fail if we can't clean up the profile information.
      // It is a system tmp directory so it should get cleaned up eventually.
    }
  }
}
