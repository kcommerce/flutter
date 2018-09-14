// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show window;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Conrolls a scrollable widget that is not fully visible on screen yet. While
/// the [top] value is between [minTop] and [maxTop], scroll events will drive
/// [top]. Once it has reached [minTop] or [maxTop], scroll events will drive
/// [offset]. The [top] value is guaranteed not to be [clamp]ed between
/// [minTop] and [maxTop].
///
/// This controller would typically be created and listened to by a parent
/// widget such as a [Positioned] or an [Align], and then either passed in
/// directly or used as a [PrimaryScrollController] by a [Scrollable] descendant
/// of that parent.
///
/// See also:
///
///  * [ScrollTopThenContentPosition], which manages the positioning logic for
///    this controller.
///  * [PrimaryScrollController], which can be used to establish a
///    [ScrollTopThenContentController] as the primary contorller for
///    descendants.
class ScrollTopThenContentController extends ScrollController {
  /// Creates a new [ScrollTopThenContentController].
  ///
  /// The [top] and [minTop] parameters must not be null. If [maxTop]
  /// is provided as null, it will be defaulted to the [ui.window] height.
  ScrollTopThenContentController({
    double initialScrollOffset = 0.0,
    double top = 0.0,
    this.minTop = 0.0,
    this.maxTop = double.maxFinite,
    String debugLabel,
  })  : assert(top != null),
        assert(minTop != null),
        assert(maxTop != null),
        _initialTop = top,
        super(
        debugLabel: debugLabel,
        initialScrollOffset: initialScrollOffset,
      );

  ScrollTopThenContentPosition _position;

  /// The current value of [top].  This controller will
  double get top => _position?.top ?? double.maxFinite;
  final double _initialTop;

  /// The minimum allowable value for [top].
  final double minTop;

  /// The maximum allowable value for [top].
  final double maxTop;

  /// Animate the [top] value to [maxTop].
  Future<Null> dismiss() {
    return _position.dismiss();
  }

  /// Animate the [top] value to [newTop].
  Future<Null> animateTopTo(double newTop, {
    @required Duration duration,
    @required Curve curve,
  }) {
    return _position?.animateTopTo(newTop, duration: duration, curve: curve);
  }

  @override
  ScrollTopThenContentPosition createScrollPosition(ScrollPhysics physics,
      ScrollContext context, ScrollPosition oldPosition) {
    _position = ScrollTopThenContentPosition(
      physics: physics,
      context: context,
      top: _initialTop,
      minTop: minTop,
      maxTop: maxTop,
      oldPosition: oldPosition,
      notifier: notifyTopListeners,
    );
    return _position;
  }

  // NotificationCallback handling for top.

  List<VoidCallback> _topListeners = <VoidCallback>[];

  /// Register a closure to be called when [top] changes.
  ///
  /// Listeners looking for changes to the [offset] should use [addListener].
  /// This method must not be called after [dispose] has been called.
  void addTopListener(VoidCallback callback) {
    _topListeners.add(callback);
  }

  /// Remove a previously registered closure from the list of closures that are
  /// notified when [top] changes.
  ///
  /// If the given listener is not registered, the call is ignored.
  ///
  /// This method must not be called after [dispose] has been called.
  ///
  /// If a listener had been added twice, and is removed once during an
  /// iteration (i.e. in response to a notification), it will still be called
  /// again. If, on the other hand, it is removed as many times as it was
  /// registered, then it will no longer be called. This odd behavior is the
  /// result of the [ChangeNotifier] not being able to determine which listener
  /// is being removed, since they are identical, and therefore conservatively
  /// still calling all the listeners when it knows that any are still
  /// registered.
  ///
  /// This surprising behavior can be unexpectedly observed when registering a
  /// listener on two separate objects which are both forwarding all
  /// registrations to a common upstream object.
  void removeTopListener(VoidCallback callback) {
    _topListeners.remove(callback);
  }

  /// Call all the registered listeners to [top] changes.
  ///
  /// Call this method whenever [top] changes, to notify any clients the
  /// object may have. Listeners that are added during this iteration will not
  /// be visited. Listeners that are removed during this iteration will not be
  /// visited after they are removed.
  ///
  /// Exceptions thrown by listeners will be caught and reported using
  /// [FlutterError.reportError].
  ///
  /// This method must not be called after [dispose] has been called.
  ///
  /// Surprising behavior can result when reentrantly removing a listener (i.e.
  /// in response to a notification) that has been registered multiple times.
  /// See the discussion at [removeTopListener].
  void notifyTopListeners() {
    if (_topListeners != null) {
      final List<VoidCallback> localListeners =
      List<VoidCallback>.from(_topListeners);
      for (VoidCallback listener in localListeners) {
        try {
          if (_topListeners.contains(listener)) {
            listener();
          }
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
              exception: exception,
              stack: stack,
              library: 'widgets library',
              context: 'while dispatching notifications for $runtimeType',
              informationCollector: (StringBuffer information) {
                information
                    .writeln('The $runtimeType sending notification was:');
                information.write('  $this');
              }));
        }
      }
    }
  }

  @override
  void dispose() {
    _topListeners = null;
    super.dispose();
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('top: $top');
  }
}

/// A scroll position that manages scroll activities for
/// [ScrollTopThenContentController], which delegates its [top]
/// member to this class.
///
/// This class is a concrete subclass of [ScrollPosition] logic that handles a
/// single [ScrollContext], such as a [Scrollable]. An instance of this class
/// manages [ScrollActivity] instances, which changes the
/// [ScrollTopThenContentController.top] or visible content offset in the
/// [Scrollable]'s [Viewport].
///
/// See also:
///
///  * [ScrollTopThenContentController], which uses this as its [ScrollPosition].
class ScrollTopThenContentPosition extends ScrollPositionWithSingleContext {
  /// Creates a new [ScrollTopThenContentPosition].
  ///
  /// The [top], [notifier], and [minTop] parameters must not be null.  If [maxTop]
  /// is null, it will be defaulted to [double.maxFinite].
  ScrollTopThenContentPosition({
    @required double top,
    @required this.notifier,
    this.minTop = 0.0,
    @required this.maxTop,
    ScrollPosition oldPosition,
    ScrollPhysics physics,
    @required ScrollContext context,
  })  : assert(top != null),
        assert(notifier != null),
        assert(minTop != null),
        assert(maxTop != null),
        assert(context != null),
        super(
        physics: physics,
        context: context,
        initialPixels: 0.0,
        oldPosition: oldPosition,
      ) {
    _topAnimationController = AnimationController(
      value: 1.0,
      vsync: context.vsync,
      duration: const Duration(milliseconds: 200),
      debugLabel: 'ScrollTopThenContentTopController',
    )..addListener(notifier)..animateTo(top / maxTop);
  }

  /// The [VoidCallback] to use when [top] is modified.
  final VoidCallback notifier;

  /// The current vertical offset.
  double get top => _topAnimationController.value * maxTop;

  /// The minimum allowable vertical offset.
  final double minTop;

  /// The maximum allowable vertical offset.
  final double maxTop;


  VoidCallback _dragCancelCallback;
  // Tracks whether a drag down can affect the [top].
  bool _canScrollDown = false;
  // Tracks whether a fling down can affect the [top].
  bool _canFlingDown = false;

  AnimationController _ballisticController;
  AnimationController _topAnimationController;

  // Ensure that top stays between _minTop and _maxTop, and update listeners
  void _addDeltaToTop(double delta) {
    _topAnimationController.value += delta / maxTop;
  }

  /// Animate the [top] value to [maxTop].
  Future<Null> dismiss() {
    return _topAnimationController.forward();
  }

  /// Animate the top value to [newTop], which will be clamped
  /// between [minTop]..[maxTop].
  ///
  /// The [newTop] parameter must not be null.
  Future<Null> animateTopTo(double newTop, {
    Duration duration,
    Curve curve,
  }) {
    assert(newTop != null);
    newTop = newTop.clamp(minTop, maxTop);
    return _topAnimationController.animateTo(newTop, duration: duration, curve: curve);
  }
  @override
  void absorb(ScrollPosition other) {
    // Need to make sure these get reset -
    // notice this can be an issue when toggling between iOS and Android physics.
    _canFlingDown = false;
    _canScrollDown = false;
    super.absorb(other);
  }

  @override
  void applyUserOffset(double delta) {
    if (top == minTop) {
      // <= because of iOS bounce overscroll
      if (pixels <= 0.0 && _canScrollDown) {
        _addDeltaToTop(delta);
        _canScrollDown = false;
      } else {
        if (pixels <= 0.0) {
          _canScrollDown = true;
        }
        super.applyUserOffset(delta);
      }
    } else {
      _addDeltaToTop(delta);
    }
  }

  @override
  double get minScrollExtent {
    // This prevents the physics simulation from thinking it shouldn't be
    // doing anything when a user flings down from top == minTop.
    return _canFlingDown ? super.minScrollExtent + 1 : super.minScrollExtent;
  }

  @override
  void goBallistic(double velocity) {
    if (top == minTop || top == maxTop || velocity == 0.0) {
      super.goBallistic(velocity);
      return;
    }

    // Scrollable expects that we will dispose of its current _drag
    _dragCancelCallback?.call();


    _ballisticController = AnimationController.unbounded(
      debugLabel: '$runtimeType',
      vsync: context.vsync,
    );
    void _tickUp() {
      _addDeltaToTop(-_ballisticController.value);
      if (top == minTop) {
        _ballisticController.stop();
        super.goBallistic(velocity);
      }
    }

    void _tickDown() {
      _addDeltaToTop(_ballisticController.value.abs());
      if (top == maxTop) {
        _ballisticController.stop();
        super.goBallistic(velocity);
      }
    }

    _canFlingDown = true;
    final Simulation simulation =
    physics.createBallisticSimulation(this, velocity);

    if (simulation != null) {
      _ballisticController
        ..addListener(velocity > 0 ? _tickUp : _tickDown)
        ..animateWith(simulation);
      _canFlingDown = false;
    }
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    // Save this so we can call it later if we have to [goBallistic] on our own.
    _dragCancelCallback = dragCancelCallback;
    return super.drag(details, dragCancelCallback);
  }

  @override
  void dispose() {
    _ballisticController?.dispose();
    _topAnimationController?.dispose();
    super.dispose();
  }
}
