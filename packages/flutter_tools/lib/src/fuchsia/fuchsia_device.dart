// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';

import 'package:flutter_tools/src/convert.dart';
import 'package:meta/meta.dart';

import '../application_package.dart';
import '../artifacts.dart';
import '../base/common.dart';
import '../base/context.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/net.dart';
import '../base/platform.dart';
import '../base/process.dart';
import '../base/time.dart';
import '../build_info.dart';
import '../device.dart';
import '../device_port_forwarder.dart';
import '../globals.dart' as globals;
import '../project.dart';
import '../vmservice.dart';

import 'amber_ctl.dart';
import 'application_package.dart';
import 'fuchsia_build.dart';
import 'fuchsia_pm.dart';
import 'fuchsia_sdk.dart';
import 'fuchsia_workflow.dart';
import 'session_control.dart';
import 'tiles_ctl.dart';

/// The [FuchsiaDeviceTools] instance.
FuchsiaDeviceTools get fuchsiaDeviceTools => context.get<FuchsiaDeviceTools>();

/// Fuchsia device-side tools.
class FuchsiaDeviceTools {
  FuchsiaAmberCtl _amberCtl;
  FuchsiaAmberCtl get amberCtl => _amberCtl ??= FuchsiaAmberCtl();

  FuchsiaTilesCtl _tilesCtl;
  FuchsiaTilesCtl get tilesCtl => _tilesCtl ??= FuchsiaTilesCtl();


  FuchsiaSessionControl _sessionControl;
  FuchsiaSessionControl get sessionControl => _sessionControl ??= FuchsiaSessionControl();
}

final String _ipv4Loopback = InternetAddress.loopbackIPv4.address;
final String _ipv6Loopback = InternetAddress.loopbackIPv6.address;

/// Read the log for a particular device.
class _FuchsiaLogReader extends DeviceLogReader {
  _FuchsiaLogReader(this._device, this._systemClock, [this._app]);

  // \S matches non-whitespace characters.
  static final RegExp _flutterLogOutput = RegExp(r'INFO: \S+\(flutter\): ');

  final FuchsiaDevice _device;
  final ApplicationPackage _app;
  final SystemClock _systemClock;

  @override
  String get name => _device.name;

  Stream<String> _logLines;
  @override
  Stream<String> get logLines {
    final Stream<String> logStream = fuchsiaSdk.syslogs(_device.id);
    _logLines ??= _processLogs(logStream);
    return _logLines;
  }

  Stream<String> _processLogs(Stream<String> lines) {
    if (lines == null) {
      return null;
    }
    // Get the starting time of the log processor to filter logs from before
    // the process attached.
    final DateTime startTime = _systemClock.now();
    // Determine if line comes from flutter, and optionally whether it matches
    // the correct fuchsia module.
    final RegExp matchRegExp = _app == null
        ? _flutterLogOutput
        : RegExp('INFO: ${_app.name}(\\.cmx)?\\(flutter\\): ');
    return Stream<String>.eventTransformed(
      lines,
      (EventSink<String> output) => _FuchsiaLogSink(output, matchRegExp, startTime),
    );
  }

  @override
  String toString() => name;

  @override
  void dispose() {
    // The Fuchsia SDK syslog process is killed when the subscription to the
    // logLines Stream is canceled.
  }
}

class _FuchsiaLogSink implements EventSink<String> {
  _FuchsiaLogSink(this._outputSink, this._matchRegExp, this._startTime);

  static final RegExp _utcDateOutput = RegExp(r'\d+\-\d+\-\d+ \d+:\d+:\d+');
  final EventSink<String> _outputSink;
  final RegExp _matchRegExp;
  final DateTime _startTime;

  @override
  void add(String line) {
    if (!_matchRegExp.hasMatch(line)) {
      return;
    }
    final String rawDate = _utcDateOutput.firstMatch(line)?.group(0);
    if (rawDate == null) {
      return;
    }
    final DateTime logTime = DateTime.parse(rawDate);
    if (logTime.millisecondsSinceEpoch < _startTime.millisecondsSinceEpoch) {
      return;
    }
    _outputSink.add(
        '[${logTime.toLocal()}] Flutter: ${line.split(_matchRegExp).last}');
  }

  @override
  void addError(Object error, [StackTrace stackTrace]) {
    _outputSink.addError(error, stackTrace);
  }

  @override
  void close() {
    _outputSink.close();
  }
}

/// Device discovery for Fuchsia devices.
class FuchsiaDevices extends PollingDeviceDiscovery {
  FuchsiaDevices({
    @required Platform platform,
    @required FuchsiaWorkflow fuchsiaWorkflow,
    @required FuchsiaSdk fuchsiaSdk,
    @required Logger logger,
  }) : _platform = platform,
       _fuchsiaWorkflow = fuchsiaWorkflow,
       _fuchsiaSdk = fuchsiaSdk,
       _logger = logger,
       super('Fuchsia devices');

  final Platform _platform;
  final FuchsiaWorkflow _fuchsiaWorkflow;
  final FuchsiaSdk _fuchsiaSdk;
  final Logger _logger;

  @override
  bool get supportsPlatform => isFuchsiaSupportedPlatform(_platform);

  @override
  bool get canListAnything => _fuchsiaWorkflow.canListDevices;

  @override
  Future<List<Device>> pollingGetDevices({ Duration timeout }) async {
    if (!_fuchsiaWorkflow.canListDevices) {
      return <Device>[];
    }
    // TODO(omerlevran): Remove once soft transition is complete fxb/67602.
    final List<String> text = (await _fuchsiaSdk.listDevices(
      timeout: timeout,
      useDeviceFinder: _fuchsiaWorkflow.shouldUseDeviceFinder,
    ))?.split('\n');
    if (text == null || text.isEmpty) {
      return <Device>[];
    }
    final List<FuchsiaDevice> devices = <FuchsiaDevice>[];
    for (final String line in text) {
      final FuchsiaDevice device = await _parseDevice(line);
      if (device == null) {
        continue;
      }
      devices.add(device);
    }
    return devices;
  }

  @override
  Future<List<String>> getDiagnostics() async => const <String>[];

  Future<FuchsiaDevice> _parseDevice(String text) async {
    final String line = text.trim();
    // ['ip', 'device name']
    final List<String> words = line.split(' ');
    if (words.length < 2) {
      return null;
    }
    final String name = words[1];
    String resolvedHost;

    // TODO(omerlevran): Remove once soft transition is complete fxb/67602.
    if (_fuchsiaWorkflow.shouldUseDeviceFinder) {
      // TODO(omerlevran): Add support for resolve on the FuchsiaSdk Object.
      resolvedHost = await _fuchsiaSdk.fuchsiaDevFinder.resolve(
        name,
      );
    } else {
      // TODO(omerlevran): Add support for resolve on the FuchsiaSdk Object.
      resolvedHost = await _fuchsiaSdk.fuchsiaFfx.resolve(name);
    }
    if (resolvedHost == null) {
      _logger.printError('Failed to resolve host for Fuchsia device `$name`');
      return null;
    }
    return FuchsiaDevice(resolvedHost, name: name);
  }

  @override
  List<String> get wellKnownIds => const <String>[];
}

class FuchsiaDevice extends Device {
  FuchsiaDevice(String id, {this.name}) : super(
      id,
      platformType: PlatformType.fuchsia,
      category: null,
      ephemeral: true,
  );

  @override
  bool get supportsHotReload => true;

  @override
  bool get supportsHotRestart => false;

  @override
  bool get supportsFlutterExit => false;

  @override
  final String name;

  @override
  Future<bool> get isLocalEmulator async => false;

  @override
  Future<String> get emulatorId async => null;

  @override
  bool get supportsStartPaused => false;

  String get strippedId => id.split('%').first;

  bool _isSession;

  Future<bool> get isSession async => _isSession ??= await _initIsSession();

  /// Determine if the Fuchsia device is running a session based build.
  ///
  /// If the device is running a session based build, `session_control` should be
  /// used to launch apps, otherwise `tiles_ctl` should be used.
  Future<bool> _initIsSession() async {
    final RunResult result = await shell('which session_control');
    if (result.exitCode != 0) {
      return false;
    }
    return true;
  }

  @override
  Future<bool> isAppInstalled(
    ApplicationPackage app, {
    String userIdentifier,
  }) async => false;

  @override
  Future<bool> isLatestBuildInstalled(ApplicationPackage app) async => false;

  @override
  Future<bool> installApp(
    ApplicationPackage app, {
    String userIdentifier,
  }) => Future<bool>.value(false);

  @override
  Future<bool> uninstallApp(
    ApplicationPackage app, {
    String userIdentifier,
  }) async => false;

  @override
  bool isSupported() => true;

  @override
  bool supportsRuntimeMode(BuildMode buildMode) => buildMode != BuildMode.jitRelease;

  @override
  Future<LaunchResult> startApp(
    covariant FuchsiaApp package, {
    String mainPath,
    String route,
    DebuggingOptions debuggingOptions,
    Map<String, dynamic> platformArgs,
    bool prebuiltApplication = false,
    bool ipv6 = false,
    String userIdentifier,
  }) async {
    if (await isSession) {
      globals.printTrace('Running on a session framework based build.');
    } else {
      globals.printTrace('Running on a non session framework based build.');
    }

    if (!prebuiltApplication) {
      await buildFuchsia(fuchsiaProject: FlutterProject.current().fuchsia,
                         targetPlatform: await targetPlatform,
                         target: mainPath,
                         buildInfo: debuggingOptions.buildInfo);
    }
    // Stop the app if it's currently running.
    await stopApp(package);

    // Find out who the device thinks we are.
    final int port = await globals.os.findFreePort();
    if (port == 0) {
      globals.printError('Failed to find a free port');
      return LaunchResult.failed();
    }

    // Try Start with a fresh package repo in case one was left over from a
    // previous run.
    final Directory packageRepo =
        globals.fs.directory(globals.fs.path.join(getFuchsiaBuildDirectory(), '.pkg-repo'));
    try {
      if (packageRepo.existsSync()) {
        packageRepo.deleteSync(recursive: true);
      }
      packageRepo.createSync(recursive: true);
    } on Exception catch (e) {
      globals.printError('Failed to create Fuchsia package repo directory '
                 'at ${packageRepo.path}: $e');
      return LaunchResult.failed();
    }

    final String appName = FlutterProject.current().manifest.appName;
    final Status status = globals.logger.startProgress(
      'Starting Fuchsia application $appName...',
    );
    FuchsiaPackageServer fuchsiaPackageServer;
    bool serverRegistered = false;
    String fuchsiaUrl;
    try {
      if (await isSession) {
        // Prefetch session_control
        if (!await fuchsiaDeviceTools.amberCtl.getUp(this, 'session_control')) {
          globals.printError('Failed to get amber to prefetch session_control');
          return LaunchResult.failed();
        }
      } else {
        // Ask amber to pre-fetch some things we'll need before setting up our own
        // package server. This is to avoid relying on amber correctly using
        // multiple package servers, support for which is in flux.
        if (!await fuchsiaDeviceTools.amberCtl.getUp(this, 'tiles')) {
          globals.printError('Failed to get amber to prefetch tiles');
          return LaunchResult.failed();
        }
        if (!await fuchsiaDeviceTools.amberCtl.getUp(this, 'tiles_ctl')) {
          globals.printError('Failed to get amber to prefetch tiles_ctl');
          return LaunchResult.failed();
        }
      }

      // Start up a package server.
      const String packageServerName = FuchsiaPackageServer.toolHost;
      fuchsiaPackageServer = FuchsiaPackageServer(
          packageRepo.path, packageServerName, '', port);
      if (!await fuchsiaPackageServer.start()) {
        globals.printError('Failed to start the Fuchsia package server');
        return LaunchResult.failed();
      }

      // Serve the application's package.
      final File farArchive = package.farArchive(
          debuggingOptions.buildInfo.mode);
      if (!await fuchsiaPackageServer.addPackage(farArchive)) {
        globals.printError('Failed to add package to the package server');
        return LaunchResult.failed();
      }

      // Serve the flutter_runner.
      final File flutterRunnerArchive = globals.fs.file(globals.artifacts.getArtifactPath(
        Artifact.fuchsiaFlutterRunner,
        platform: await targetPlatform,
        mode: debuggingOptions.buildInfo.mode,
      ));
      if (!await fuchsiaPackageServer.addPackage(flutterRunnerArchive)) {
        globals.printError('Failed to add flutter_runner package to the package server');
        return LaunchResult.failed();
      }

      // Teach the package controller about the package server.
      if (!await fuchsiaDeviceTools.amberCtl.addRepoCfg(this, fuchsiaPackageServer)) {
        globals.printError('Failed to teach amber about the package server');
        return LaunchResult.failed();
      }
      serverRegistered = true;

      // Tell the package controller to prefetch the flutter_runner.
      String flutterRunnerName;
      if (debuggingOptions.buildInfo.usesAot) {
        if (debuggingOptions.buildInfo.mode.isRelease) {
          flutterRunnerName = 'flutter_aot_product_runner';
        } else {
          flutterRunnerName = 'flutter_aot_runner';
        }
      } else {
        if (debuggingOptions.buildInfo.mode.isRelease) {
          flutterRunnerName = 'flutter_jit_product_runner';
        } else {
          flutterRunnerName = 'flutter_jit_runner';
        }
      }
      if (!await fuchsiaDeviceTools.amberCtl.pkgCtlResolve(
          this, fuchsiaPackageServer, flutterRunnerName)) {
        globals.printError('Failed to get pkgctl to prefetch the flutter_runner');
        return LaunchResult.failed();
      }

      // Tell the package controller to prefetch the app.
      if (!await fuchsiaDeviceTools.amberCtl.pkgCtlResolve(
          this, fuchsiaPackageServer, appName)) {
        globals.printError('Failed to get pkgctl to prefetch the package');
        return LaunchResult.failed();
      }

      fuchsiaUrl = 'fuchsia-pkg://$packageServerName/$appName#meta/$appName.cmx';

      if (await isSession) {
        // Instruct session_control to start the app
        if (!await fuchsiaDeviceTools.sessionControl.add(this, fuchsiaUrl)) {
          globals.printError('Failed to add the app to session_control');
          return LaunchResult.failed();
        }
      } else {
        // Ensure tiles_ctl is started, and start the app.
        if (!await FuchsiaTilesCtl.ensureStarted(this)) {
          globals.printError('Failed to ensure that tiles is started on the device');
          return LaunchResult.failed();
        }

        // Instruct tiles_ctl to start the app.
        if (!await fuchsiaDeviceTools.tilesCtl.add(this, fuchsiaUrl, <String>[])) {
          globals.printError('Failed to add the app to tiles');
          return LaunchResult.failed();
        }
      }
    } finally {
      // Try to un-teach the package controller about the package server if
      // needed.
      if (serverRegistered) {
        await fuchsiaDeviceTools.amberCtl.pkgCtlRepoRemove(this, fuchsiaPackageServer);
      }
      // Shutdown the package server and delete the package repo;
      globals.printTrace("Shutting down the tool's package server.");
      fuchsiaPackageServer?.stop();
      globals.printTrace("Removing the tool's package repo: at ${packageRepo.path}");
      try {
        packageRepo.deleteSync(recursive: true);
      } on Exception catch (e) {
        globals.printError('Failed to remove Fuchsia package repo directory '
                   'at ${packageRepo.path}: $e.');
      }
      status.cancel();
    }

    if (debuggingOptions.buildInfo.mode.isRelease) {
      globals.printTrace('App successfully started in a release mode.');
      return LaunchResult.succeeded();
    }
    globals.printTrace('App started in a non-release mode. Setting up vmservice connection.');

    // In a debug or profile build, try to find the observatory uri.
    final FuchsiaIsolateDiscoveryProtocol discovery =
      getIsolateDiscoveryProtocol(fuchsiaUrl);
    try {
      final Uri observatoryUri = await discovery.uri;
      return LaunchResult.succeeded(observatoryUri: observatoryUri);
    } finally {
      discovery.dispose();
    }
  }

  @override
  Future<bool> stopApp(
    covariant FuchsiaApp app, {
    String userIdentifier,
  }) async {
    if (await isSession) {
      // Currently there are no way to close a running app programmatically
      // using the session framework afaik. So this is a no-op.
      return true;
    }
    final int appKey = await FuchsiaTilesCtl.findAppKey(this, app.id);
    if (appKey != -1) {
      if (!await fuchsiaDeviceTools.tilesCtl.remove(this, appKey)) {
        globals.printError('tiles_ctl remove on ${app.id} failed.');
        return false;
      }
    }
    return true;
  }

  TargetPlatform _targetPlatform;

  Future<TargetPlatform> _queryTargetPlatform() async {
    const TargetPlatform defaultTargetPlatform = TargetPlatform.fuchsia_arm64;
    if (!globals.fuchsiaArtifacts.hasSshConfig) {
      globals.printTrace('Could not determine Fuchsia target platform because '
                 'Fuchsia ssh configuration is missing.\n'
                 'Defaulting to arm64.');
      return defaultTargetPlatform;
    }
    final RunResult result = await shell('uname -m');
    if (result.exitCode != 0) {
      globals.printError('Could not determine Fuchsia target platform type:\n$result\n'
                 'Defaulting to arm64.');
      return defaultTargetPlatform;
    }
    final String machine = result.stdout.trim();
    switch (machine) {
      case 'aarch64':
        return TargetPlatform.fuchsia_arm64;
      case 'x86_64':
        return TargetPlatform.fuchsia_x64;
      default:
        globals.printError('Unknown Fuchsia target platform "$machine". '
                   'Defaulting to arm64.');
        return defaultTargetPlatform;
    }
  }

  @override
  bool get supportsScreenshot => isFuchsiaSupportedPlatform(globals.platform);

  @override
  Future<void> takeScreenshot(File outputFile) async {
    if (outputFile.basename.split('.').last != 'ppm') {
      throw '${outputFile.path} must be a .ppm file';
    }
    final RunResult screencapResult = await shell('screencap > /tmp/screenshot.ppm');
    if (screencapResult.exitCode != 0) {
      throw 'Could not take a screenshot on device $name:\n$screencapResult';
    }
    try {
      final RunResult scpResult = await scp('/tmp/screenshot.ppm', outputFile.path);
      if (scpResult.exitCode != 0) {
        throw 'Failed to copy screenshot from device:\n$scpResult';
      }
    } finally {
      try {
        final RunResult deleteResult = await shell('rm /tmp/screenshot.ppm');
        if (deleteResult.exitCode != 0) {
          globals.printError(
            'Failed to delete screenshot.ppm from the device:\n$deleteResult'
          );
        }
      } on Exception catch (e) {
        globals.printError(
          'Failed to delete screenshot.ppm from the device: $e'
        );
      }
    }
  }

  @override
  Future<TargetPlatform> get targetPlatform async => _targetPlatform ??= await _queryTargetPlatform();

  @override
  Future<String> get sdkNameAndVersion async {
    const String defaultName = 'Fuchsia';
    if (!globals.fuchsiaArtifacts.hasSshConfig) {
      globals.printTrace('Could not determine Fuchsia sdk name or version '
                 'because Fuchsia ssh configuration is missing.');
      return defaultName;
    }
    const String versionPath = '/pkgfs/packages/build-info/0/data/version';
    final RunResult catResult = await shell('cat $versionPath');
    if (catResult.exitCode != 0) {
      globals.printTrace('Failed to cat $versionPath: ${catResult.stderr}');
      return defaultName;
    }
    final String version = catResult.stdout.trim();
    if (version.isEmpty) {
      globals.printTrace('$versionPath was empty');
      return defaultName;
    }
    return 'Fuchsia $version';
  }

  @override
  DeviceLogReader getLogReader({
    ApplicationPackage app,
    bool includePastLogs = false,
  }) {
    assert(!includePastLogs, 'Past log reading not supported on Fuchsia.');
    return _logReader ??= _FuchsiaLogReader(this, globals.systemClock, app);
  }
  _FuchsiaLogReader _logReader;

  @override
  DevicePortForwarder get portForwarder =>
      _portForwarder ??= _FuchsiaPortForwarder(this);
  DevicePortForwarder _portForwarder;

  @visibleForTesting
  set portForwarder(DevicePortForwarder forwarder) {
    _portForwarder = forwarder;
  }

  @override
  void clearLogs() {}

  bool _ipv6;

  /// [true] if the current host address is IPv6.
  //  Strip interface name to avoid issues in Dart's ipv6 parsing logic as it
  //  currently does not allow an ipv6 address suffixed by an interface name
  //  like [::1%qemu].
  bool get ipv6 => _ipv6 ??= isIPv6Address(strippedId);

  /// Return the address that the device should use to communicate with the
  /// host.
  Future<String> get hostAddress async {
    if (_cachedHostAddress != null) {
      return _cachedHostAddress;
    }
    final RunResult result = await shell(r'echo $SSH_CONNECTION');
    void fail() {
      throwToolExit('Failed to get local address, aborting.\n$result');
    }
    if (result.exitCode != 0) {
      fail();
    }
    final List<String> splitResult = result.stdout.split(' ');
    if (splitResult.isEmpty) {
      fail();
    }
    final String addr = splitResult[0].replaceAll('%', '%25');
    if (addr.isEmpty) {
      fail();
    }
    return _cachedHostAddress = addr;
  }

  String _cachedHostAddress;

  /// List the ports currently running a dart observatory and the component url
  /// of flutter views that such dart observatory provides
  Future<Map<int, List<String>>> servicePorts() async {
    // TODO(michaellee8): Use the v2 /hub protocol,
    //  https://github.com/flutter/flutter/issues/83609#issuecomment-871114230,
    //  https://bugs.fuchsia.dev/p/fuchsia/issues/detail?id=79924,
    //  https://fuchsia.dev/fuchsia-src/concepts/components/v2/hub

    final Iterable<String> servicePaths = await vmServicePaths();

    final Map<int, List<String>> portUrlMap = <int, List<String>>{};

    // In practice it should be safe to assume that there are only one port
    // for each vmservice-port, but to play safe we duplicates entries if there
    // are multiple ports for the path.
    for (final String path in servicePaths) {

      // Get ports
      final Iterable<int> ports = (await listDirectory(path)).map(int.tryParse);

      // Get component urls
      final List<String> urls = await
          Stream<String>.fromIterable(await findByName('$path/../../../c', 'url'))
          .asyncMap(readFile).toList();

      for (final int port in ports){
        portUrlMap[port] = urls;
      }
    }
    return portUrlMap;
  }

  @visibleForTesting
  Future<Iterable<String>> vmServicePaths() async {
    final Iterable<String> paths = await findByName('/hub', 'vmservice-port');
    if (paths.isEmpty) {
      throwToolExit(
          'No Dart Observatories found. Are you running a debug build?');
    }
    return paths;
  }

  @visibleForTesting
  Future<Iterable<String>> listDirectory(String path) async {
    final String command = 'ls "$path"';
    final RunResult result = await shell(command);
    if (result.exitCode != 0) {
      throwToolExit("'$command' on device $name failed, stderr: '${result.stderr}");
    }
    final String output = result.stdout;
    return output.trim().split('\n').where((String s) => s != '');
  }

  @visibleForTesting
  Future<Iterable<String>> findByName(String path, String name) async {
    final String command = 'find "$path" -name "$name"';
    final RunResult result = await shell(command);
    if (result.exitCode != 0) {
      throwToolExit("'$command' on device $name failed. stderr: '${result.stderr}'");
    }
    final String output = result.stdout;
    return output.trim().split('\n').where((String s) => s != '');
  }

  @visibleForTesting
  Future<String> readFile(String path, { bool trim = true }) async {
    final String command = 'cat "$path"';
    final RunResult result = await shell(command);
    if (result.exitCode != 0){
      throwToolExit("'$command' on device $name failed, stderr: '${result.stderr}");
    }
    final String output = result.stdout;
    if (trim){
      return output.trim();
    }
    return output;
  }

  @visibleForTesting
  Future<Map<String,int>> listVmServicePorts() async {
    // iquery -f json selectors 'flutter_*_runner.cmx:root/*:empty_tree'
    const String command = 'iquery -f json show  "flutter_*_runner.cmx:root:vm_service_port"';
    final RunResult result = await shell(command);
    final String output = result.stdout;
    if (result.exitCode != 0){
      throwToolExit("'$command' on device $name failed, stderr: '${result.stderr}")
    }
    final List<dynamic> arr = jsonDecode(output) as List<dynamic>;
    arr.map(( dynamic e) => e as Map<String,dynamic>).map((m)=>Pair);

  }

  /// Run `command` on the Fuchsia device shell.
  Future<RunResult> shell(String command) async {
    if (globals.fuchsiaArtifacts.sshConfig == null) {
      throwToolExit('Cannot interact with device. No ssh config.\n'
                    'Try setting FUCHSIA_SSH_CONFIG or FUCHSIA_BUILD_DIR.');
    }
    return globals.processUtils.run(<String>[
      'ssh',
      '-F',
      globals.fuchsiaArtifacts.sshConfig.absolute.path,
      id, // Device's IP address.
      command,
    ]);
  }

  /// Transfer the file [origin] from the device to [destination].
  Future<RunResult> scp(String origin, String destination) async {
    if (globals.fuchsiaArtifacts.sshConfig == null) {
      throwToolExit('Cannot interact with device. No ssh config.\n'
                    'Try setting FUCHSIA_SSH_CONFIG or FUCHSIA_BUILD_DIR.');
    }
    return globals.processUtils.run(<String>[
      'scp',
      '-F',
      globals.fuchsiaArtifacts.sshConfig.absolute.path,
      '$id:$origin',
      destination,
    ]);
  }

  /// Finds the first port running a VM matching `isolateName` from the
  /// provided set of `ports`.
  ///
  /// Returns null if no isolate port can be found.
  ///
  // TODO(jonahwilliams): replacing this with the hub will require an update
  // to the flutter_runner.
  Future<int> findIsolatePort(String isolateName, List<int> ports) async {
    for (final int port in ports) {
      try {
        // Note: The square-bracket enclosure for using the IPv6 loopback
        // didn't appear to work, but when assigning to the IPv4 loopback device,
        // netstat shows that the local port is actually being used on the IPv6
        // loopback (::1).
        final Uri uri = Uri.parse('http://[$_ipv6Loopback]:$port');
        final FlutterVmService vmService = await connectToVmService(uri, logger: globals.logger);
        final List<FlutterView> flutterViews = await vmService.getFlutterViews();
        for (final FlutterView flutterView in flutterViews) {
          if (flutterView.uiIsolate == null) {
            continue;
          }
          if (flutterView.uiIsolate.name.contains(isolateName)) {
            return vmService.httpAddress.port;
          }
        }
      } on SocketException catch (err) {
        globals.printTrace('Failed to connect to $port: $err');
      }
    }
    throwToolExit('No ports found running $isolateName');
  }

  FuchsiaIsolateDiscoveryProtocol getIsolateDiscoveryProtocol(String fuchsiaUrl) {
    return FuchsiaIsolateDiscoveryProtocol(this, fuchsiaUrl);
  }

  @override
  bool isSupportedForProject(FlutterProject flutterProject) {
    return flutterProject.fuchsia.existsSync();
  }

  @override
  Future<void> dispose() async {
    await _portForwarder?.dispose();
  }
}

class FuchsiaIsolateDiscoveryProtocol {
  FuchsiaIsolateDiscoveryProtocol(
    this._device,
    this._fuchsiaUrl, [
    this._pollOnce = false,
  ]);

  static const Duration _pollDuration = Duration(seconds: 10);
  final FuchsiaDevice _device;
  final String _fuchsiaUrl;
  final Completer<Uri> _foundUri = Completer<Uri>();
  // whether to only poll once.
  final bool _pollOnce;
  Timer _pollingTimer;
  Status _status;

  FutureOr<Uri> get uri {
    if (_uri != null) {
      return _uri;
    }
    _status ??= globals.logger.startProgress(
      'Waiting for a connection from $_fuchsiaUrl on ${_device.name}...',
    );
    unawaited(_findIsolate());  // Completes the _foundUri Future.
    return _foundUri.future.then((Uri uri) {
      _uri = uri;
      return uri;
    });
  }

  Uri _uri;

  void dispose() {
    if (!_foundUri.isCompleted) {
      _status?.cancel();
      _status = null;
      _pollingTimer?.cancel();
      _pollingTimer = null;
      _foundUri.completeError(Exception('Did not complete'));
    }
  }

  Future<void> _findIsolate() async {
    final Map<int, List<String>> portUrlsMap = await _device.servicePorts();
    for (final int port in portUrlsMap.keys) {
      if (portUrlsMap[port].contains(_fuchsiaUrl)){
        final int localPort = await _device.portForwarder.forward(port);
        final Uri uri = Uri.parse('http://[$_ipv6Loopback]:$localPort');
        _foundUri.complete(uri);
        _status.stop();
        return;
      }
    }
    globals.printTrace('No observatory with correct app component found yet.');
    if (_pollOnce) {
      _foundUri.completeError(Exception('Max iterations exceeded'));
      _status.stop();
      return;
    }
    _pollingTimer = Timer(_pollDuration, _findIsolate);
  }
}

class _FuchsiaPortForwarder extends DevicePortForwarder {
  _FuchsiaPortForwarder(this.device);

  final FuchsiaDevice device;
  final Map<int, Process> _processes = <int, Process>{};

  @override
  Future<int> forward(int devicePort, {int hostPort}) async {
    hostPort ??= await globals.os.findFreePort();
    if (hostPort == 0) {
      throwToolExit('Failed to forward port $devicePort. No free host-side ports');
    }
    // Note: the provided command works around a bug in -N, see US-515
    // for more explanation.
    final List<String> command = <String>[
      'ssh',
      '-6',
      '-F',
      globals.fuchsiaArtifacts.sshConfig.absolute.path,
      '-nNT',
      '-vvv',
      '-f',
      '-L',
      '$hostPort:$_ipv4Loopback:$devicePort',
      device.id, // Device's IP address.
      'true',
    ];
    final Process process = await globals.processManager.start(command);
    unawaited(process.exitCode.then((int exitCode) {
      if (exitCode != 0) {
        throwToolExit('Failed to forward port:$devicePort');
      }
    }));
    _processes[hostPort] = process;
    _forwardedPorts.add(ForwardedPort(hostPort, devicePort));
    return hostPort;
  }

  @override
  List<ForwardedPort> get forwardedPorts => _forwardedPorts;
  final List<ForwardedPort> _forwardedPorts = <ForwardedPort>[];

  @override
  Future<void> unforward(ForwardedPort forwardedPort) async {
    _forwardedPorts.remove(forwardedPort);
    final Process process = _processes.remove(forwardedPort.hostPort);
    process?.kill();
    final List<String> command = <String>[
      'ssh',
      '-F',
      globals.fuchsiaArtifacts.sshConfig.absolute.path,
      '-O',
      'cancel',
      '-vvv',
      '-L',
      '${forwardedPort.hostPort}:$_ipv4Loopback:${forwardedPort.devicePort}',
      device.id, // Device's IP address.
    ];
    final ProcessResult result = await globals.processManager.run(command);
    if (result.exitCode != 0) {
      throwToolExit(
        'Unforward command failed:\n'
        'stdout: ${result.stdout}\n'
        'stderr: ${result.stderr}'
      );
    }
  }

  @override
  Future<void> dispose() async {
    final List<ForwardedPort> forwardedPortsCopy =
      List<ForwardedPort>.of(forwardedPorts);
    for (final ForwardedPort port in forwardedPortsCopy) {
      await unforward(port);
    }
  }
}
