// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'base/file_system.dart';
import 'base/platform.dart';
import 'cache.dart';
import 'device.dart';

// Only launch or display desktop embedding devices if there is a sibling
// FDE repository or a `FLUTTER_DESKTOP_EMBEDDING` environment variable which
// contains a path to a FDE repo.
bool get hasFlutterDesktopRepository {
  if (_hasFlutterDesktopRepository == null) {
    final String desktopLocation = platform.environment['FLUTTER_DESKTOP_EMBEDDING'];
    if (desktopLocation != null && desktopLocation.isNotEmpty) {
      _hasFlutterDesktopRepository = fs.directory(desktopLocation)
        .childDirectory('flutter-desktop-embedding')
        .existsSync();
    } else {
      final Directory parent = fs.directory(Cache.flutterRoot).parent;
      _hasFlutterDesktopRepository = parent
        .childDirectory('flutter-desktop-embedding')
        .existsSync();
    }
  }
  return _hasFlutterDesktopRepository;
}
bool _hasFlutterDesktopRepository;

// An empty device log reader
class NoOpDeviceLogReader implements DeviceLogReader {
  NoOpDeviceLogReader(this.name);

  @override
  final String name;

  @override
  int appPid;

  @override
  Stream<String> get logLines => const Stream<String>.empty();
}

// A portforwarder which does not support forwarding ports.
class NoOpDevicePortForwarder implements DevicePortForwarder {
  const NoOpDevicePortForwarder();

  @override
  Future<int> forward(int devicePort, {int hostPort}) async {
    if (hostPort != null) {
      throw UnimplementedError();
    }
    return devicePort;
  }

  @override
  List<ForwardedPort> get forwardedPorts => <ForwardedPort>[];

  @override
  Future<void> unforward(ForwardedPort forwardedPort) async {}
}
