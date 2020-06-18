// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recorder.dart';
import 'test_data.dart';

/// Creates a grid of mouse regions, then continuously scrolls them up and down.
///
/// Measures our ability to render mouse regions.
class BenchMouseRegionGridScroll extends WidgetRecorder {
  BenchMouseRegionGridScroll() : super(name: benchmarkName);

  static const String benchmarkName = 'bench_mouse_region_grid_scroll';

  final _Tester tester = _Tester();

  // Use a non-trivial border to force Web to switch painter
  Border _getBorder(int columnIndex, int rowIndex) {
    const BorderSide defaultBorderSide = BorderSide();

    return Border(
      left: columnIndex == 0 ? defaultBorderSide : BorderSide.none,
      top: rowIndex == 0 ? defaultBorderSide : BorderSide.none,
      right: defaultBorderSide,
      bottom: defaultBorderSide,
    );
  }

  bool started = false;

  @override
  void frameDidDraw() {
    if (!started) {
      started = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) async {
        tester.start();
        final VoidCallback localDidStop = didStop;
        didStop = () {
          if (localDidStop != null)
            localDidStop();
          tester.stop();
        };
      });
    }
    super.frameDidDraw();
  }

  @override
  Widget createWidget() {
    const int rowsCount = 60;
    const int columnsCount = 20;
    const double containerSize = 20;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 400,
          child: ListView.builder(
            itemCount: rowsCount,
            cacheExtent: rowsCount * containerSize,
            physics: const ClampingScrollPhysics(),
            itemBuilder: (BuildContext context, int rowIndex) => Row(
              children: List<Widget>.generate(
                columnsCount,
                (int columnIndex) => MouseRegion(
                  onEnter: (_) => {},
                  child: Container(
                    decoration: BoxDecoration(
                      border: _getBorder(columnIndex, rowIndex),
                      color: Color.fromARGB(255, rowIndex * 20 % 256, 127, 127),
                    ),
                    width: containerSize,
                    height: containerSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tester {
  static const int scrollFrequency = 60;
  static const Offset dragStartLocation = const Offset(200, 200);
  static const Offset dragUpOffset = const Offset(0, 200);
  static const Offset dragDownOffset = const Offset(0, -200);
  static const Duration hoverDuration = const Duration(milliseconds: 20);
  static const Duration dragDuration = const Duration(milliseconds: 200);

  bool _stopped = false;

  TestGesture get gesture {
    return _gesture ??= TestGesture(
      dispatcher: (PointerEvent event, HitTestResult result) async {
        RendererBinding.instance.dispatchEvent(event, result);
      },
      hitTester: (Offset location) {
        final HitTestResult result = HitTestResult();
        RendererBinding.instance.hitTest(result, location);
        return result;
      },
      kind: PointerDeviceKind.mouse,
    );
  }
  TestGesture _gesture;

  Duration currentTime = Duration.zero;

  void _hoverTo(Offset location, Duration duration) async {
    currentTime += duration;
    await gesture.moveTo(location, timeStamp: currentTime);
    await Future<void>.delayed(Duration.zero);
  }

  void _scroll(Offset start, Offset offset, Duration duration) async {
    final int durationMs = duration.inMilliseconds;
    final Duration fullFrameDuration = Duration(seconds: 1) ~/ scrollFrequency;
    final int frameDurationMs = fullFrameDuration.inMilliseconds;

    final int fullFrames = duration.inMilliseconds ~/ frameDurationMs;
    final Offset fullFrameOffset = offset * ((frameDurationMs as double) / durationMs);

    final Duration finalFrameDuration = duration - fullFrameDuration * fullFrames;
    final Offset finalFrameOffset = offset - fullFrameOffset * (fullFrames as double);

    await gesture.down(start, timeStamp: currentTime);
    await Future<void>.delayed(Duration.zero);

    for (int frame = 0; frame < fullFrames; frame += 1) {
      currentTime += fullFrameDuration;
      await gesture.moveBy(fullFrameOffset, timeStamp: currentTime);
      await Future<void>.delayed(Duration.zero);
    }

    if (finalFrameOffset != Duration.zero) {
      currentTime += finalFrameDuration;
      await gesture.moveBy(finalFrameOffset, timeStamp: currentTime);
      await Future<void>.delayed(Duration.zero);
    }

    await gesture.up(timeStamp: currentTime);
    await Future<void>.delayed(Duration.zero);
  }

  void start() async {
    await Future<void>.delayed(Duration.zero);
    while (!_stopped) {
      await _hoverTo(dragStartLocation, hoverDuration);
      await _scroll(dragStartLocation, dragUpOffset, dragDuration);
      await _hoverTo(dragStartLocation, hoverDuration);
      await _scroll(dragStartLocation, dragDownOffset, dragDuration);
    }
  }

  void stop() {
    _stopped = true;
  }
}
