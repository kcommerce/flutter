// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import '../rendering/rendering_tester.dart';

void main() {
  testWidgets('ListWheelScrollView needs positive diameter ratio', (WidgetTester tester) async {
    try {
      await tester.pumpWidget(
        new Directionality(
          textDirection: TextDirection.ltr,
          child: new ListWheelScrollView(
            diameterRatio: -2.0,
            itemExtent: 20.0,
            children: <Widget>[],
          ),
        )
      );
      fail('Expected failure with negative diameterRatio');
    } on AssertionError {
      // Exception expected.
    }
  });

  testWidgets('ListWheelScrollView needs positive item extent', (WidgetTester tester) async {
    try {
      await tester.pumpWidget(
        new Directionality(
          textDirection: TextDirection.ltr,
          child: new ListWheelScrollView(
            itemExtent: null,
            children: <Widget>[new Container()],
          ),
        )
      );
      fail('Expected failure with null itemExtent');
    } on AssertionError {
      // Exception expected.
    }
  });

  testWidgets("ListWheelScrollView takes parent's size with small children", (WidgetTester tester) async {
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new ListWheelScrollView(
          // Inner children smaller than the outer window.
          itemExtent: 50.0,
          children: <Widget>[
            new Container(
              height: 50.0,
              color: const Color(0xFFFFFFFF),
            ),
          ],
        ),
      )
    );
    expect(tester.getTopLeft(find.byType(ListWheelScrollView)), const Offset(0.0, 0.0));
    // Standard test screen size.
    expect(tester.getBottomRight(find.byType(ListWheelScrollView)), const Offset(800.0, 600.0));
  });

  testWidgets("ListWheelScrollView takes parent's size with large children", (WidgetTester tester) async {
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new ListWheelScrollView(
          // Inner children 5000.0px.
          itemExtent: 50.0,
          children: new List<Widget>.generate(100, (int index) {
            return new Container(
              height: 50.0,
              color: const Color(0xFFFFFFFF),
            );
          }),
        ),
      )
    );
    expect(tester.getTopLeft(find.byType(ListWheelScrollView)), const Offset(0.0, 0.0));
    // Still fills standard test screen size.
    expect(tester.getBottomRight(find.byType(ListWheelScrollView)), const Offset(800.0, 600.0));
  });

  testWidgets("ListWheelScrollView children can't be bigger than itemExtent", (WidgetTester tester) async {
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new ListWheelScrollView(
          itemExtent: 50.0,
          children: <Widget>[
            const SizedBox(
              height: 200.0,
              width: 200.0,
              child: const Center(
                child: const Text('blah'),
              ),
            ),
          ],
        ),
      )
    );
    expect(tester.getSize(find.byType(SizedBox)), const Size(200.0, 50.0));
    expect(find.text('blah'), findsOneWidget);
  });

  testWidgets('ListWheelScrollView can have zero child', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new ListWheelScrollView(
          itemExtent: 50.0,
          children: <Widget>[],
        ),
      )
    );
    expect(tester.getSize(find.byType(ListWheelScrollView)), const Size(800.0, 600.0));
  });

  testWidgets('ListWheelScrollView starts and ends from the middle', (WidgetTester tester) async {
    final ScrollController controller = new ScrollController();
    final List<int> paintedChildren = <int>[];

    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new ListWheelScrollView(
          controller: controller,
          itemExtent: 100.0,
          children: new List<Widget>.generate(100, (int index) {
            return new CustomPaint(
              painter: new TestCallbackPainter(onPaint: () {
                paintedChildren.add(index);
              }),
            );
          }),
        ),
      )
    );

    // Screen is 600px tall and the first item starts at 250px. The first 4
    // children are visible.
    expect(paintedChildren, <int>[0, 1, 2, 3]);

    controller.jumpTo(1000.0);
    paintedChildren.clear();

    await tester.pump();
    // Item number 10 is now in the middle of the screen at 250px. 9, 8, 7 are
    // visible before it and 11, 12, 13 are visible after it.
    expect(paintedChildren, <int>[7, 8, 9, 10, 11, 12, 13]);

    // Move to the last item.
    controller.jumpTo(9900.0);
    paintedChildren.clear();

    await tester.pump();
    // Item 99 is in the middle at 250px.
    expect(paintedChildren, <int>[96, 97, 98, 99]);
  });

  testWidgets('A child gets painted as soon as its first pixel is in the viewport', (WidgetTester tester) async {
    final ScrollController controller = new ScrollController(initialScrollOffset: 50.0);
    final List<int> paintedChildren = <int>[];

    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new ListWheelScrollView(
          controller: controller,
          itemExtent: 100.0,
          children: new List<Widget>.generate(10, (int index) {
            return new CustomPaint(
              painter: new TestCallbackPainter(onPaint: () {
                paintedChildren.add(index);
              }),
            );
          }),
        ),
      )
    );

    // Screen is 600px tall and the first item starts at 200px. The first 4
    // children are visible.
    expect(paintedChildren, <int>[0, 1, 2, 3]);

    paintedChildren.clear();
    // Move down by 1px.
    await tester.drag(find.byType(ListWheelScrollView), const Offset(0.0, -1.0));
    await tester.pump();

    // Now the first pixel of item 5 enters the viewport.
    expect(paintedChildren, <int>[0, 1, 2, 3, 4]);
  });

  testWidgets('A child is no longer painted after its last pixel leaves the viewport', (WidgetTester tester) async {
    final ScrollController controller = new ScrollController(initialScrollOffset: 250.0);
    final List<int> paintedChildren = <int>[];

    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new ListWheelScrollView(
          controller: controller,
          itemExtent: 100.0,
          children: new List<Widget>.generate(10, (int index) {
            return new CustomPaint(
              painter: new TestCallbackPainter(onPaint: () {
                paintedChildren.add(index);
              }),
            );
          }),
        ),
      )
    );

    // The first item is at 0px and the 600px screen is full in the
    // **untransformed plane's viewport painting coordinates**
    expect(paintedChildren, <int>[0, 1, 2, 3, 4, 5]);

    paintedChildren.clear();
    // Go down another 99px.
    controller.jumpTo(349.0);
    await tester.pump();

    // One more item now visible with the last pixel of 0 showing.
    expect(paintedChildren, <int>[0, 1, 2, 3, 4, 5, 6]);

    paintedChildren.clear();
    // Go down one more pixel.
    controller.jumpTo(350.0);
    await tester.pump();

    // Item 0 no longer visible.
    expect(paintedChildren, <int>[1, 2, 3, 4, 5, 6]);
  });
}
