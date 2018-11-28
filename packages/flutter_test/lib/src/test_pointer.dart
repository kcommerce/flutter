// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'test_async_utils.dart';

export 'dart:ui' show Offset;

/// A class for generating coherent artificial pointer events.
///
/// You can use this to manually simulate individual events, but the
/// simplest way to generate coherent gestures is to use [TestGesture].
class TestPointer {
  /// Creates a [TestPointer]. By default, the pointer identifier used is 1,
  /// however this can be overridden by providing an argument to the
  /// constructor.
  ///
  /// Multiple [TestPointer]s created with the same pointer identifier will
  /// interfere with each other if they are used in parallel.
  TestPointer([ this.pointer = 1 ]);

  /// The pointer identifier used for events generated by this object.
  ///
  /// Set when the object is constructed. Defaults to 1.
  final int pointer;

  /// Whether the pointer simulated by this object is currently down.
  ///
  /// A pointer is released (goes up) by calling [up] or [cancel].
  ///
  /// Once a pointer is released, it can no longer generate events.
  bool get isDown => _isDown;
  bool _isDown = false;

  /// The position of the last event sent by this object.
  ///
  /// If no event has ever been sent by this object, returns null.
  Offset get location => _location;
  Offset _location;

  /// If a custom event is created outside of this class, this function is used
  /// to set the [isDown].
  bool setDownInfo(PointerEvent event, Offset newLocation) {
    _location = newLocation;
    switch (event.runtimeType) {
      case PointerDownEvent:
        assert(!isDown);
        _isDown = true;
        break;
      case PointerUpEvent:
      case PointerCancelEvent:
        assert(isDown);
        _isDown = false;
        break;
      default: break;
    }
    return isDown;
  }

  /// Create a [PointerDownEvent] at the given location.
  ///
  /// By default, the time stamp on the event is [Duration.zero]. You
  /// can give a specific time stamp by passing the `timeStamp`
  /// argument.
  PointerDownEvent down(Offset newLocation, { Duration timeStamp = Duration.zero, }) {
    assert(!isDown);
    _isDown = true;
    _location = newLocation;
    return PointerDownEvent(
      timeStamp: timeStamp,
      pointer: pointer,
      position: location
    );
  }

  /// Create a [PointerMoveEvent] to the given location.
  ///
  /// By default, the time stamp on the event is [Duration.zero]. You
  /// can give a specific time stamp by passing the `timeStamp`
  /// argument.
  PointerMoveEvent move(Offset newLocation, { Duration timeStamp = Duration.zero }) {
    assert(isDown);
    final Offset delta = newLocation - location;
    _location = newLocation;
    return PointerMoveEvent(
      timeStamp: timeStamp,
      pointer: pointer,
      position: newLocation,
      delta: delta
    );
  }

  /// Create a [PointerUpEvent].
  ///
  /// By default, the time stamp on the event is [Duration.zero]. You
  /// can give a specific time stamp by passing the `timeStamp`
  /// argument.
  ///
  /// The object is no longer usable after this method has been called.
  PointerUpEvent up({ Duration timeStamp = Duration.zero }) {
    assert(isDown);
    _isDown = false;
    return PointerUpEvent(
      timeStamp: timeStamp,
      pointer: pointer,
      position: location
    );
  }

  /// Create a [PointerCancelEvent].
  ///
  /// By default, the time stamp on the event is [Duration.zero]. You
  /// can give a specific time stamp by passing the `timeStamp`
  /// argument.
  ///
  /// The object is no longer usable after this method has been called.
  PointerCancelEvent cancel({ Duration timeStamp = Duration.zero }) {
    assert(isDown);
    _isDown = false;
    return PointerCancelEvent(
      timeStamp: timeStamp,
      pointer: pointer,
      position: location
    );
  }
}

/// Signature for a callback that can dispatch events and returns a future that
/// completes when the event dispatch is complete.
typedef EventDispatcher = Future<void> Function(PointerEvent event, HitTestResult result);

/// Signature for callbacks that perform hit-testing at a given location.
typedef HitTester = HitTestResult Function(Offset location);

/// A class for performing gestures in tests.
///
/// The simplest way to create a [TestGesture] is to call
/// [WidgetTester.startGesture].
class TestGesture {
  TestGesture._(this._dispatcher, this._result, this._pointer);

  /// Create a [TestGesture] by starting with a pointerDown at the
  /// given point.
  ///
  /// By default, the pointer identifier used is 1. This can be overridden by
  /// providing the `pointer` argument.
  ///
  /// A function to use for hit testing should be provided via the `hitTester`
  /// argument, and a function to use for dispatching events should be provided
  /// via the `dispatcher` argument.
  static Future<TestGesture> down(Offset downLocation, {
    int pointer = 1,
    @required HitTester hitTester,
    @required EventDispatcher dispatcher,
  }) async {
    assert(hitTester != null);
    assert(dispatcher != null);
    TestGesture result;
    return TestAsyncUtils.guard<void>(() async {
      // dispatch down event
      final HitTestResult hitTestResult = hitTester(downLocation);
      final TestPointer testPointer = TestPointer(pointer);
      await dispatcher(testPointer.down(downLocation), hitTestResult);

      // create a TestGesture
      result = TestGesture._(dispatcher, hitTestResult, testPointer);
    }).then<TestGesture>((void value) {
      return result;
    }, onError: (dynamic error, StackTrace stack) {
      return Future<TestGesture>.error(error, stack);
    });
  }

  /// Create a [TestGesture] by starting with a custom [PointerDownEvent] at the
  /// given point.
  ///
  /// By default, the pointer identifier used is 1. This can be overridden by
  /// providing the `pointer` argument.
  ///
  /// A function to use for hit testing should be provided via the `hitTester`
  /// argument, and a function to use for dispatching events should be provided
  /// via the `dispatcher` argument.
  static Future<TestGesture> downWithCustomEvent(Offset downLocation, PointerDownEvent downEvent, {
    int pointer = 1,
    @required HitTester hitTester,
    @required EventDispatcher dispatcher,
  }) async {
    assert(hitTester != null);
    assert(dispatcher != null);
    TestGesture result;
    return TestAsyncUtils.guard<void>(() async {
      // dispatch down event
      final HitTestResult hitTestResult = hitTester(downLocation);
      final TestPointer testPointer = TestPointer(pointer);
      testPointer.setDownInfo(downEvent, downLocation);
      await dispatcher(downEvent, hitTestResult);
      // create a TestGesture
      result = TestGesture._(dispatcher, hitTestResult, testPointer);
    }).then<TestGesture>((void value) {
      return result;
    }, onError: (dynamic error, StackTrace stack) {
      return Future<TestGesture>.error(error, stack);
    });
  }

  final EventDispatcher _dispatcher;
  final HitTestResult _result;
  final TestPointer _pointer;

  /// Send a move event moving the pointer by the given offset.
  Future<void> updateWithCustomEvent(PointerEvent event, { Duration timeStamp = Duration.zero }) {
    _pointer.setDownInfo(event, event.position);
    return TestAsyncUtils.guard<void>(() {
      return _dispatcher(event, _result);
    });
  }

  /// Send a move event moving the pointer by the given offset.
  Future<void> moveBy(Offset offset, { Duration timeStamp = Duration.zero }) {
    assert(_pointer._isDown);
    return moveTo(_pointer.location + offset, timeStamp: timeStamp);
  }

  /// Send a move event moving the pointer to the given location.
  Future<void> moveTo(Offset location, { Duration timeStamp = Duration.zero }) {
    return TestAsyncUtils.guard<void>(() {
      assert(_pointer._isDown);
      return _dispatcher(_pointer.move(location, timeStamp: timeStamp), _result);
    });
  }

  /// End the gesture by releasing the pointer.
  ///
  /// The object is no longer usable after this method has been called.
  Future<void> up() {
    return TestAsyncUtils.guard<void>(() async {
      assert(_pointer._isDown);
      await _dispatcher(_pointer.up(), _result);
      assert(!_pointer._isDown);
    });
  }

  /// End the gesture by canceling the pointer (as would happen if the
  /// system showed a modal dialog on top of the Flutter application,
  /// for instance).
  ///
  /// The object is no longer usable after this method has been called.
  Future<void> cancel() {
    return TestAsyncUtils.guard<void>(() async {
      assert(_pointer._isDown);
      await _dispatcher(_pointer.cancel(), _result);
      assert(!_pointer._isDown);
    });
  }
}
