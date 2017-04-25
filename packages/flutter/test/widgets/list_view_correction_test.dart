// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('ListView can handle shrinking top elements', (WidgetTester tester) async {
    final ScrollController controller = new ScrollController();
    await tester.pumpWidget(new ListView(
      controller: controller,
      children: <Widget>[
        new Container(height: 400.0, child: const Text('1')),
        new Container(height: 400.0, child: const Text('2')),
        new Container(height: 400.0, child: const Text('3')),
        new Container(height: 400.0, child: const Text('4')),
        new Container(height: 400.0, child: const Text('5')),
        new Container(height: 400.0, child: const Text('6')),
      ],
    ));

    controller.jumpTo(1000.0);
    await tester.pump();

    expect(tester.getTopLeft(find.text('4')).dy, equals(200.0));

    await tester.pumpWidget(new ListView(
      controller: controller,
      children: <Widget>[
        new Container(height: 200.0, child: const Text('1')),
        new Container(height: 400.0, child: const Text('2')),
        new Container(height: 400.0, child: const Text('3')),
        new Container(height: 400.0, child: const Text('4')),
        new Container(height: 400.0, child: const Text('5')),
        new Container(height: 400.0, child: const Text('6')),
      ],
    ));

    expect(controller.offset, equals(1000.0));
    expect(tester.getTopLeft(find.text('4')).dy, equals(200.0));

    controller.jumpTo(300.0);
    await tester.pump();

    expect(tester.getTopLeft(find.text('2')).dy, equals(100.0));

    controller.jumpTo(50.0);

    await tester.pump();

    expect(controller.offset, equals(0.0));
    expect(tester.getTopLeft(find.text('2')).dy, equals(200.0));
  });

  testWidgets('ListView can handle inserts at 0', (WidgetTester tester) async {
    final ScrollController controller = new ScrollController();
    await tester.pumpWidget(new ListView(
      controller: controller,
      children: <Widget>[
        new Container(height: 400.0, child: const Text('0')),
        new Container(height: 400.0, child: const Text('1')),
        new Container(height: 400.0, child: const Text('2')),
        new Container(height: 400.0, child: const Text('3')),
      ],
    ));
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsNothing);

    final Finder findItemA = find.descendant(of: find.byType(Container), matching: find.text('A'));
    final Finder findItemB = find.descendant(of: find.byType(Container), matching: find.text('B'));
    await tester.pumpWidget(new ListView(
      controller: controller,
      children: <Widget>[
        new Container(height: 10.0, child: const Text('A')),
        new Container(height: 10.0, child: const Text('B')),
        new Container(height: 400.0, child: const Text('0')),
        new Container(height: 400.0, child: const Text('1')),
        new Container(height: 400.0, child: const Text('2')),
        new Container(height: 400.0, child: const Text('3')),
      ],
    ));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(tester.getTopLeft(findItemA).dy, 0.0);
    expect(tester.getBottomRight(findItemA).dy, 10.0);
    expect(tester.getTopLeft(findItemB).dy, 10.0);
    expect(tester.getBottomRight(findItemB).dy, 20.0);


    controller.jumpTo(1200.0);
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);

    await tester.pumpWidget(new ListView(
      controller: controller,
      children: <Widget>[
        new Container(height: 200.0, child: const Text('A')),
        new Container(height: 200.0, child: const Text('B')),
        new Container(height: 400.0, child: const Text('0')),
        new Container(height: 400.0, child: const Text('1')),
        new Container(height: 400.0, child: const Text('2')),
        new Container(height: 400.0, child: const Text('3')),
      ],
    ));
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);

    // Scrolling to 0 causes items A and B to underflow (extend below
    // scrollOffset 0) because their heights have grown from 10 - 200.
    // RenderSliver list corrects the scroll offset in this case. Only item
    // B will become visible and item B's bottom edge will still appear
    // where it was when its height was 10.0.
    controller.jumpTo(0.0);
    await tester.pump();
    expect(find.text('B'), findsOneWidget);
    expect(controller.offset, greaterThan(0.0)); // RenderSliverList corrected the offset.
    expect(tester.getTopLeft(findItemB).dy, -180.0);
    expect(tester.getBottomRight(findItemB).dy, 20.0);


    controller.jumpTo(0.0);
    await tester.pump();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(tester.getTopLeft(findItemA).dy, 0.0);
    expect(tester.getBottomRight(findItemA).dy, 200.0);
    expect(tester.getTopLeft(findItemB).dy, 200.0);
    expect(tester.getBottomRight(findItemB).dy, 400.0);
  });
}
