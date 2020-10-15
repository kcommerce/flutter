// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:file/memory.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/dds.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart' as io;
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/ios/devices.dart';
import 'package:flutter_tools/src/ios/fallback_discovery.dart';
import 'package:flutter_tools/src/ios/ios_deploy.dart';
import 'package:flutter_tools/src/ios/iproxy.dart';
import 'package:flutter_tools/src/ios/mac.dart';
import 'package:flutter_tools/src/reporting/reporting.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fakes.dart';

const FakeCommand kDeployCommand = FakeCommand(
  command: <String>[
    'Artifact.iosDeploy.TargetPlatform.ios',
    '--id',
    '123',
    '--bundle',
    '/',
    '--no-wifi',
  ],
  environment: <String, String>{
    'PATH': '/usr/bin:null',
    'DYLD_LIBRARY_PATH': '/path/to/libraries',
  }
);

// The command used to actually launch the app with args in release/profile.
const FakeCommand kLaunchReleaseCommand = FakeCommand(
  command: <String>[
    'Artifact.iosDeploy.TargetPlatform.ios',
    '--id',
    '123',
    '--bundle',
    '/',
    '--no-wifi',
    '--justlaunch',
    // These args are the default on DebuggingOptions.
    '--args',
    '--enable-dart-profiling --enable-service-port-fallback --disable-service-auth-codes --observatory-port=60700',
  ],
  environment: <String, String>{
    'PATH': '/usr/bin:null',
    'DYLD_LIBRARY_PATH': '/path/to/libraries',
  }
);

// The command used to just launch the app with args in debug.
const FakeCommand kLaunchDebugCommand = FakeCommand(command: <String>[
  'Artifact.iosDeploy.TargetPlatform.ios',
  '--id',
  '123',
  '--bundle',
  '/',
  '--no-wifi',
  '--justlaunch',
  '--args',
  '--enable-dart-profiling --enable-service-port-fallback --disable-service-auth-codes --observatory-port=60700 --enable-checked-mode --verify-entry-points'
], environment: <String, String>{
  'PATH': '/usr/bin:null',
  'DYLD_LIBRARY_PATH': '/path/to/libraries',
});

// The command used to actually launch the app and attach the debugger with args in debug.
const FakeCommand kAttachDebuggerCommand = FakeCommand(command: <String>[
  'script',
  '-t',
  '0',
  '/dev/null',
  'Artifact.iosDeploy.TargetPlatform.ios',
  '--id',
  '123',
  '--bundle',
  '/',
  '--debug',
  '--noninteractive',
  '--no-wifi',
  '--args',
  '--enable-dart-profiling --enable-service-port-fallback --disable-service-auth-codes --observatory-port=60700 --enable-checked-mode --verify-entry-points'
], environment: <String, String>{
  'PATH': '/usr/bin:null',
  'DYLD_LIBRARY_PATH': '/path/to/libraries',
},
stdout: '(lldb)     run\nsuccess\n(lldb)     autoexit',
);

void main() {
  // TODO(jonahwilliams): This test doesn't really belong here but
  // I don't have a better place for it for now.
  testWithoutContext('disposing device disposes the portForwarder and logReader', () async {
    final IOSDevice device = setUpIOSDevice();
    final DevicePortForwarder devicePortForwarder = MockDevicePortForwarder();
    final DeviceLogReader deviceLogReader = MockDeviceLogReader();
    final IOSApp iosApp = PrebuiltIOSApp(
      projectBundleId: 'app',
      bundleName: 'Runner',
    );

    device.portForwarder = devicePortForwarder;
    device.setLogReader(iosApp, deviceLogReader);
    await device.dispose();

    verify(deviceLogReader.dispose()).called(1);
    verify(devicePortForwarder.dispose()).called(1);
  });

  // Still uses context for analytics.
  testUsingContext('IOSDevice.startApp attaches in debug mode via log reading on iOS 13+', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      kDeployCommand,
      kAttachDebuggerCommand,
    ]);
    final IOSDevice device = setUpIOSDevice(
      processManager: processManager,
      fileSystem: fileSystem,
      vmServiceConnector: (String string, {Log log}) async {
        throw const io.SocketException(
          'OS Error: Connection refused, errno = 61, address = localhost, port '
          '= 58943',
        );
      },
    );
    final IOSApp iosApp = PrebuiltIOSApp(
      projectBundleId: 'app',
      bundleName: 'Runner',
      bundleDir: fileSystem.currentDirectory,
    );
    final FakeDeviceLogReader deviceLogReader = FakeDeviceLogReader();

    device.portForwarder = const NoOpDevicePortForwarder();
    device.setLogReader(iosApp, deviceLogReader);

    // Start writing messages to the log reader.
    Timer.run(() {
      deviceLogReader.addLine('Foo');
      deviceLogReader.addLine('Observatory listening on http://127.0.0.1:456');
    });

    final LaunchResult launchResult = await device.startApp(iosApp,
      prebuiltApplication: true,
      debuggingOptions: DebuggingOptions.enabled(BuildInfo.debug),
      platformArgs: <String, dynamic>{},
      fallbackPollingDelay: Duration.zero,
      fallbackThrottleTimeout: const Duration(milliseconds: 10),
    );

    expect(launchResult.started, true);
    expect(launchResult.hasObservatory, true);
    verify(globals.flutterUsage.sendEvent('ios-handshake', 'log-success')).called(1);
  }, overrides: <Type, Generator>{
    Usage: () => MockUsage(),
  });

  // Still uses context for analytics.
  testUsingContext('IOSDevice.startApp launches in debug mode via log reading on <iOS 13', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      kDeployCommand,
      kLaunchDebugCommand,
    ]);
    final IOSDevice device = setUpIOSDevice(
      sdkVersion: '12.4.4',
      processManager: processManager,
      fileSystem: fileSystem,
      vmServiceConnector: (String string, {Log log}) async {
        throw const io.SocketException(
          'OS Error: Connection refused, errno = 61, address = localhost, port '
              '= 58943',
        );
      },
    );
    final IOSApp iosApp = PrebuiltIOSApp(
      projectBundleId: 'app',
      bundleName: 'Runner',
      bundleDir: fileSystem.currentDirectory,
    );
    final FakeDeviceLogReader deviceLogReader = FakeDeviceLogReader();

    device.portForwarder = const NoOpDevicePortForwarder();
    device.setLogReader(iosApp, deviceLogReader);

    // Start writing messages to the log reader.
    Timer.run(() {
      deviceLogReader.addLine('Foo');
      deviceLogReader.addLine('Observatory listening on http://127.0.0.1:456');
    });

    final LaunchResult launchResult = await device.startApp(iosApp,
      prebuiltApplication: true,
      debuggingOptions: DebuggingOptions.enabled(BuildInfo.debug),
      platformArgs: <String, dynamic>{},
      fallbackPollingDelay: Duration.zero,
      fallbackThrottleTimeout: const Duration(milliseconds: 10),
    );

    expect(launchResult.started, true);
    expect(launchResult.hasObservatory, true);
    verify(globals.flutterUsage.sendEvent('ios-handshake', 'log-success')).called(1);
  }, overrides: <Type, Generator>{
    Usage: () => MockUsage(),
  });

  // Still uses context for analytics.
  testUsingContext('IOSDevice.startApp fails in debug mode when Observatory URI is malformed', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      kDeployCommand,
      kAttachDebuggerCommand,
    ]);
    final IOSDevice device = setUpIOSDevice(
      processManager: processManager,
      fileSystem: fileSystem,
      vmServiceConnector: (String string, {Log log}) async {
        throw const io.SocketException(
          'OS Error: Connection refused, errno = 61, address = localhost, port '
          '= 58943',
        );
      },
    );
    final IOSApp iosApp = PrebuiltIOSApp(
      projectBundleId: 'app',
      bundleName: 'Runner',
      bundleDir: fileSystem.currentDirectory,
    );
    final FakeDeviceLogReader deviceLogReader = FakeDeviceLogReader();

    device.portForwarder = const NoOpDevicePortForwarder();
    device.setLogReader(iosApp, deviceLogReader);

    // Now that the reader is used, start writing messages to it.
    Timer.run(() {
      deviceLogReader.addLine('Foo');
      deviceLogReader.addLine('Observatory listening on http://127.0.0.1:456abc');
    });

    final LaunchResult launchResult = await device.startApp(iosApp,
      prebuiltApplication: true,
      debuggingOptions: DebuggingOptions.enabled(BuildInfo.debug),
      platformArgs: <String, dynamic>{},
      fallbackPollingDelay: Duration.zero,
      // fallbackThrottleTimeout: const Duration(milliseconds: 10),
    );

    expect(launchResult.started, false);
    expect(launchResult.hasObservatory, false);
    verify(globals.flutterUsage.sendEvent(
      'ios-handshake',
      'failure-other',
      label: anyNamed('label'),
      value: anyNamed('value'),
    )).called(1);
    verify(globals.flutterUsage.sendEvent('ios-handshake', 'log-failure')).called(1);
    }, overrides: <Type, Generator>{
      Usage: () => MockUsage(),
    });

  // Still uses context for TimeoutConfiguration and usage
  testUsingContext('IOSDevice.startApp succeeds in release mode', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      kDeployCommand,
      kLaunchReleaseCommand,
    ]);
    final IOSDevice device = setUpIOSDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    final IOSApp iosApp = PrebuiltIOSApp(
      projectBundleId: 'app',
      bundleName: 'Runner',
      bundleDir: fileSystem.currentDirectory,
    );

    final LaunchResult launchResult = await device.startApp(iosApp,
      prebuiltApplication: true,
      debuggingOptions: DebuggingOptions.disabled(BuildInfo.release),
      platformArgs: <String, dynamic>{},
      fallbackPollingDelay: Duration.zero,
      fallbackThrottleTimeout: const Duration(milliseconds: 10),
    );

    expect(launchResult.started, true);
    expect(launchResult.hasObservatory, false);
    expect(processManager.hasRemainingExpectations, false);
  }, overrides: <Type, Generator>{
    Usage: () => MockUsage(),
  });

  // Still uses context for analytics.
  testUsingContext('IOSDevice.startApp forwards all supported debugging options', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      kDeployCommand,
      FakeCommand(
        command: <String>[
          'script',
          '-t',
          '0',
          '/dev/null',
          'Artifact.iosDeploy.TargetPlatform.ios',
          '--id',
          '123',
          '--bundle',
          '/',
          '--debug',
          '--noninteractive',
          '--no-wifi',
          // The arguments below are determined by what is passed into
          // the debugging options argument to startApp.
          '--args',
          <String>[
            '--enable-dart-profiling',
            '--enable-service-port-fallback',
            '--disable-service-auth-codes',
            '--observatory-port=60700',
            '--disable-observatory-publication',
            '--start-paused',
            '--dart-flags="--foo,--null_assertions"',
            '--enable-checked-mode',
            '--verify-entry-points',
            '--enable-software-rendering',
            '--skia-deterministic-rendering',
            '--trace-skia',
            '--endless-trace-buffer',
            '--dump-skp-on-shader-compilation',
            '--verbose-logging',
            '--cache-sksl',
            '--purge-persistent-cache',
          ].join(' '),
        ], environment: const <String, String>{
          'PATH': '/usr/bin:null',
          'DYLD_LIBRARY_PATH': '/path/to/libraries',
        },
        stdout: '(lldb)     run\nsuccess',
      )
    ]);
    final IOSDevice device = setUpIOSDevice(
      sdkVersion: '13.3',
      processManager: processManager,
      fileSystem: fileSystem,
      vmServiceConnector: (String string, {Log log}) async {
        throw const io.SocketException(
          'OS Error: Connection refused, errno = 61, address = localhost, port '
          '= 58943',
        );
      },
    );
    final IOSApp iosApp = PrebuiltIOSApp(
      projectBundleId: 'app',
      bundleName: 'Runner',
      bundleDir: fileSystem.currentDirectory,
    );
    final FakeDeviceLogReader deviceLogReader = FakeDeviceLogReader();

    device.portForwarder = const NoOpDevicePortForwarder();
    device.setLogReader(iosApp, deviceLogReader);

    // Start writing messages to the log reader.
    Timer.run(() {
      deviceLogReader.addLine('Observatory listening on http://127.0.0.1:1234');
    });

    final LaunchResult launchResult = await device.startApp(iosApp,
      prebuiltApplication: true,
      debuggingOptions: DebuggingOptions.enabled(
        BuildInfo.debug,
        startPaused: true,
        disableServiceAuthCodes: true,
        disablePortPublication: true,
        dartFlags: '--foo',
        enableSoftwareRendering: true,
        skiaDeterministicRendering: true,
        traceSkia: true,
        traceSystrace: true,
        endlessTraceBuffer: true,
        dumpSkpOnShaderCompilation: true,
        cacheSkSL: true,
        purgePersistentCache: true,
        verboseSystemLogs: true,
        nullAssertions: true,
      ),
      platformArgs: <String, dynamic>{},
      fallbackPollingDelay: Duration.zero,
      fallbackThrottleTimeout: const Duration(milliseconds: 10),
    );

    expect(launchResult.started, true);
    expect(processManager.hasRemainingExpectations, false);
  }, overrides: <Type, Generator>{
    Usage: () => MockUsage(),
  });
}

IOSDevice setUpIOSDevice({
  String sdkVersion = '13.0.1',
  FileSystem fileSystem,
  Logger logger,
  ProcessManager processManager,
  VmServiceConnector vmServiceConnector,
  IOSDeploy iosDeploy,
}) {
  final Artifacts artifacts = Artifacts.test();
  final FakePlatform macPlatform = FakePlatform(
    operatingSystem: 'macos',
    environment: <String, String>{},
  );

  final Cache cache = Cache.test(
    platform: macPlatform,
    artifacts: <ArtifactSet>[
      FakeDyldEnvironmentArtifact(),
    ],
  );

  vmServiceConnector ??= (String uri, {Log log}) async => MockVmService();
  return IOSDevice('123',
    name: 'iPhone 1',
    sdkVersion: sdkVersion,
    fileSystem: fileSystem ?? MemoryFileSystem.test(),
    platform: macPlatform,
    iProxy: IProxy.test(logger: logger, processManager: processManager ?? FakeProcessManager.any()),
    logger: logger ?? BufferLogger.test(),
    iosDeploy: iosDeploy ??
        IOSDeploy(
          logger: logger ?? BufferLogger.test(),
          platform: macPlatform,
          processManager: processManager ?? FakeProcessManager.any(),
          artifacts: artifacts,
          cache: cache,
        ),
    iMobileDevice: IMobileDevice(
      logger: logger ?? BufferLogger.test(),
      processManager: processManager ?? FakeProcessManager.any(),
      artifacts: artifacts,
      cache: cache,
    ),
    cpuArchitecture: DarwinArch.arm64,
    interfaceType: IOSDeviceInterface.usb,
    vmServiceConnectUri: vmServiceConnector,
  );
}

class MockDevicePortForwarder extends Mock implements DevicePortForwarder {}
class MockDeviceLogReader extends Mock implements DeviceLogReader {}
class MockUsage extends Mock implements Usage {}
class MockVmService extends Mock implements VmService {}
class MockDartDevelopmentService extends Mock implements DartDevelopmentService {}
class MockIOSDeployDebugger extends Mock implements IOSDeployDebugger {}
class MockIOSDeploy extends Mock implements IOSDeploy {}
