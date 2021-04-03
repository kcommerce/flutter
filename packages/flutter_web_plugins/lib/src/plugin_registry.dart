// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A registrar for Flutter plugins implemented in Dart.
///
/// Plugins for the web platform are implemented in Dart and are
/// registered with this class by code generated by the `flutter` tool
/// when compiling the application.
///
/// This class implements [BinaryMessenger] to route messages from the
/// framework to registered plugins.
///
/// Use this [BinaryMessenger] when creating platform channels in order for
/// them to receive messages from the platform side. For example:
///
/// ```dart
/// class MyPlugin {
///   static void registerWith(Registrar registrar) {
///     final MethodChannel channel = MethodChannel(
///       'com.my_plugin/my_plugin',
///       const StandardMethodCodec(),
///       registrar, // the registrar is used as the BinaryMessenger
///     );
///     final MyPlugin instance = MyPlugin();
///     channel.setMethodCallHandler(instance.handleMethodCall);
///   }
///   // ...
/// }
/// ```
class Registrar extends BinaryMessenger {
  /// Creates a [Registrar].
  ///
  /// The argument is ignored. To create a test [Registrar] with custom behavior,
  /// subclass the [Registrar] class and override methods as appropriate.
  Registrar([
    @Deprecated(
      'This argument is ignored. '
      'This feature was deprecated after v1.24.0-7.0.pre.'
    )
    BinaryMessenger? binaryMessenger,
  ]);

  /// Registers the registrar's message handler
  /// ([handlePlatformMessage]) with the engine, so that plugin
  /// messages are correctly dispatched to the relevant registered
  /// plugin.
  ///
  /// Only one handler can be registered at a time. Calling this
  /// method a second time silently unregisters any
  /// previously-registered handler and replaces it with the handler
  /// from this object.
  ///
  /// This method uses a function called `webOnlySetPluginHandler` in
  /// the [dart:ui] library. That function is only available when
  /// compiling for the web.
  void registerMessageHandler() {
    // The function below is only defined in the Web dart:ui.
    // ignore: undefined_function
    ui.webOnlySetPluginHandler(handleFrameworkMessage);
  }

  /// Receives a platform message from the framework.
  ///
  /// This method has been replaced with the more clearly-named [handleFrameworkMessage].
  @Deprecated(
    'Use handleFrameworkMessage instead. '
    'This feature was deprecated after v1.24.0-7.0.pre.'
  )
  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) => handleFrameworkMessage(channel, data, callback);

  /// Message handler for web plugins.
  ///
  /// This method is called when handling messages from the framework.
  ///
  /// If a handler has been registered for the given `channel`, it is
  /// invoked, and the value it returns is passed to `callback` (if that
  /// is non-null). Then, the method's future is completed.
  ///
  /// If no handler has been registered for that channel, then the
  /// callback (if any) is invoked with null, then the method's future
  /// is completed.
  ///
  /// Messages are not buffered (unlike platform messages headed to
  /// the framework, which are managed by [ChannelBuffers]).
  ///
  /// This method is registered as the message handler by code
  /// autogenerated by the `flutter` tool when the application is
  /// compiled, if any web plugins are used. The code in question is
  /// the following:
  ///
  /// ```dart
  /// ui.webOnlySetPluginHandler(webPluginRegistrar.handleFrameworkMessage);
  /// ```
  Future<void> handleFrameworkMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) async {
    ByteData? response;
    try {
      final MessageHandler? handler = _handlers[channel];
      if (handler != null) {
        response = await handler(data);
      }
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'flutter web plugins',
        context: ErrorDescription('during a framework-to-plugin message'),
      ));
    } finally {
      if (callback != null) {
        callback(response);
      }
    }
  }

  /// Returns `this`.
  @Deprecated(
    'This property is redundant. It returns the object on which it is called. '
    'This feature was deprecated after v1.24.0-7.0.pre.'
  )
  BinaryMessenger get messenger => this;

  final Map<String, MessageHandler> _handlers = <String, MessageHandler>{};

  /// Sends a platform message from the platform side back to the framework.
  @override
  Future<ByteData?> send(String channel, ByteData? message) {
    final Completer<ByteData?> completer = Completer<ByteData?>();
    ui.window.onPlatformMessage!(channel, message, (ByteData? reply) {
      try {
        completer.complete(reply);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'flutter web plugins',
          context: ErrorDescription('during a plugin-to-framework message'),
        ));
      }
    });
    return completer.future;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null)
      _handlers.remove(channel);
    else
      _handlers[channel] = handler;
  }

  @override
  bool checkMessageHandler(String channel, MessageHandler? handler) => _handlers[channel] == handler;

  @override
  void setMockMessageHandler(
    String channel,
    MessageHandler? handler,
  ) {
    throw FlutterError(
      'Setting mock handlers is not supported on the platform side.',
    );
  }

  @override
  bool checkMockMessageHandler(String channel, MessageHandler? handler) {
    throw FlutterError(
      'Setting mock handlers is not supported on the platform side.',
    );
  }
}

/// This class was previously separate from [Registrar] but was merged into it
/// as part of a simplification of the web plugins API.
@Deprecated(
  'Use Registrar instead. '
  'This feature was deprecated after v1.26.0-18.0.pre.'
)
class PluginRegistry extends Registrar {
  /// Creates a [Registrar].
  ///
  /// The argument is ignored.
  @Deprecated(
    'Use Registrar instead. '
    'This feature was deprecated after v1.26.0-18.0.pre.'
  )
  PluginRegistry([
    @Deprecated(
      'This argument is ignored. '
      'This feature was deprecated after v1.26.0-18.0.pre.'
    )
    BinaryMessenger? binaryMessenger,
  ]) : super();

  /// Returns `this`. The argument is ignored.
  @Deprecated(
    'This method is redundant. It returns the object on which it is called. '
    'This feature was deprecated after v1.26.0-18.0.pre.'
  )
  Registrar registrarFor(Type key) => this;
}

/// The default plugin registrar for the web.
final Registrar webPluginRegistrar = PluginRegistry();

/// A deprecated alias for [webPluginRegistrar].
@Deprecated(
  'Use webPluginRegistrar instead. '
  'This feature was deprecated after v1.24.0-7.0.pre.'
)
PluginRegistry get webPluginRegistry => webPluginRegistrar as PluginRegistry;

/// A deprecated alias for [webPluginRegistrar].
@Deprecated(
  'Use webPluginRegistrar instead. '
  'This feature was deprecated after v1.24.0-7.0.pre.'
)
BinaryMessenger get pluginBinaryMessenger => webPluginRegistrar;
