// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('chrome') // Uses web-only Flutter SDK

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class TestPlugin {
  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'test_plugin',
      const StandardMethodCodec(),
      registrar.messenger,
    );
    final TestPlugin testPlugin = TestPlugin();
    channel.setMethodCallHandler(testPlugin.handleMethodCall);
  }

  static final List<String> calledMethods = <String>[];

  Future<void> handleMethodCall(MethodCall call) async {
    calledMethods.add(call.method);
  }
}

void main() {
  group('Plugin Event Channel', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      webPluginRegistry.registerMessageHandler();
    });

    test('can send events to an $EventChannel', () async {
      const EventChannel listeningChannel = EventChannel('test');
      const PluginEventChannel<String> sendingChannel =
          PluginEventChannel<String>('test');

      final StreamController<String> controller = StreamController<String>();
      sendingChannel.controller = controller;

      expect(listeningChannel.receiveBroadcastStream(),
          emitsInOrder(<String>['hello', 'world']));

      controller.add('hello');
      controller.add('world');
      await controller.close();
    });

    test('can send errors to an $EventChannel', () async {
      const EventChannel listeningChannel = EventChannel('test2');
      const PluginEventChannel<String> sendingChannel =
          PluginEventChannel<String>('test2');

      final StreamController<String> controller = StreamController<String>();
      sendingChannel.controller = controller;

      expect(
          listeningChannel.receiveBroadcastStream(),
          emitsError(predicate<dynamic>((dynamic e) =>
              e is PlatformException && e.message == 'Test error')));

      controller.addError('Test error');
      await controller.close();
    });

    test('receives a listen event', () async {
      const EventChannel listeningChannel = EventChannel('test3');
      const PluginEventChannel<String> sendingChannel =
          PluginEventChannel<String>('test3');

      final StreamController<String> controller = StreamController<String>(
          onListen: expectAsync0<void>(() {}, count: 1));
      sendingChannel.controller = controller;

      expect(listeningChannel.receiveBroadcastStream(),
          emitsInOrder(<String>['hello']));

      controller.add('hello');
      await controller.close();
    });

    test('receives a cancel event', () async {
      const EventChannel listeningChannel = EventChannel('test4');
      const PluginEventChannel<String> sendingChannel =
          PluginEventChannel<String>('test4');

      final StreamController<String> controller =
          StreamController<String>(onCancel: expectAsync0<void>(() {}));
      sendingChannel.controller = controller;

      final Stream<dynamic> eventStream =
          listeningChannel.receiveBroadcastStream();
      StreamSubscription<dynamic> subscription;
      subscription =
          eventStream.listen(expectAsync1<void, dynamic>((dynamic x) {
        expect(x, equals('hello'));
        subscription.cancel();
      }));

      controller.add('hello');
    });
  });
}
