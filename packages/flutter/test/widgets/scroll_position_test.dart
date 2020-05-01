// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

ScrollController _controller = ScrollController(
  initialScrollOffset: 110.0,
);

class ThePositiveNumbers extends StatelessWidget {
  const ThePositiveNumbers({
    Key key,
    @required this.from,
  }) : super(key: key);
  final int from;
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const PageStorageKey<String>('ThePositiveNumbers'),
      itemExtent: 100.0,
      controller: _controller,
      itemBuilder: (BuildContext context, int index) {
        return Text('${index + from}', key: ValueKey<int>(index));
      },
    );
  }
}

Future<void> performTest(WidgetTester tester, bool maintainState) async {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (RouteSettings settings) {
          if (settings.name == '/') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Container(child: const ThePositiveNumbers(from: 0)),
              maintainState: maintainState,
            );
          } else if (settings.name == '/second') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Container(child: const ThePositiveNumbers(from: 10000)),
              maintainState: maintainState,
            );
          }
          return null;
        },
      ),
    ),
  );

  // we're 600 pixels high, each item is 100 pixels high, scroll position is
  // 110.0, so we should have 7 items, 1..7.
  expect(find.text('0'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('1'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('2'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('3'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('4'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('5'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('6'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('7'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('8'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('10'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('100'), findsNothing, reason: 'with maintainState: $maintainState');

  tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(1000.0);
  await tester.pump(const Duration(seconds: 1));

  // we're 600 pixels high, each item is 100 pixels high, scroll position is
  // 1000, so we should have exactly 6 items, 10..15.

  expect(find.text('0'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('1'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('8'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('9'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('10'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('11'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('12'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('13'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('14'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('15'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('16'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('100'), findsNothing, reason: 'with maintainState: $maintainState');

  navigatorKey.currentState.pushNamed('/second');
  await tester.pump(); // navigating always takes two frames, one to start...
  await tester.pump(const Duration(seconds: 1)); // ...and one to end the transition

  // the second list is now visible, starting at 10001
  expect(find.text('0'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('1'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('10'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('11'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('10000'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('10001'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('10002'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('10003'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('10004'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('10005'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('10006'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('10007'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('10008'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('10010'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('10100'), findsNothing, reason: 'with maintainState: $maintainState');

  navigatorKey.currentState.pop();
  await tester.pump(); // again, navigating always takes two frames

  // Ensure we don't clamp the scroll offset even during the navigation.
  // https://github.com/flutter/flutter/issues/4883
  final ScrollableState state = tester.state(find.byType(Scrollable).first);
  expect(state.position.pixels, equals(1000.0), reason: 'with maintainState: $maintainState');

  await tester.pump(const Duration(seconds: 1));

  // we're 600 pixels high, each item is 100 pixels high, scroll position is
  // 1000, so we should have exactly 6 items, 10..15.

  expect(find.text('0'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('1'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('8'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('9'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('10'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('11'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('12'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('13'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('14'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('15'), findsOneWidget, reason: 'with maintainState: $maintainState');
  expect(find.text('16'), findsNothing, reason: 'with maintainState: $maintainState');
  expect(find.text('100'), findsNothing, reason: 'with maintainState: $maintainState');
}

class ExpandingBox extends StatefulWidget {
  const ExpandingBox({this.collapsedSize, this.expandedsize});

  final double collapsedSize;
  final double expandedsize;

  @override
  _ExpandingBoxState createState() {
    return _ExpandingBoxState(collapsedSize: collapsedSize, expandedsize: expandedsize);
  }
}

class _ExpandingBoxState extends State<ExpandingBox> with AutomaticKeepAliveClientMixin<ExpandingBox>{
  _ExpandingBoxState({this.collapsedSize, this.expandedsize}) {
    height = collapsedSize;
  }

  final double collapsedSize;
  final double expandedsize;

  double height;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      height: height,
      color: Colors.green,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FlatButton(
          child: const Text('Collapse'),
          onPressed: () {
            setState(() {
              height = height == collapsedSize ? expandedsize : collapsedSize;
            });
          }
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

void main() {
  testWidgets('ScrollPosition jumpTo() doesn\'t call notifyListeners twice', (WidgetTester tester) async {
    int count = 0;
    await tester.pumpWidget(MaterialApp(
      home: ListView.builder(
        itemBuilder: (BuildContext context, int index) {
          return Text('$index', textDirection: TextDirection.ltr);
        },
      ),
    ));

    final ScrollPosition position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.addListener(() {
      count++;
    });
    position.jumpTo(100);

    expect(count, 1);
  });

  testWidgets('shrink listview', (WidgetTester tester) async {
    // widget tests run at (800x600)@3.0x
    await tester.pumpWidget(MaterialApp(
      home: ListView.builder(
        itemBuilder: (BuildContext context, int index) => index == 0
              ? const ExpandingBox(collapsedSize: 400, expandedsize: 1200)
              : Container(height: 300, color: Colors.red),
        itemCount: 2,
      ),
    ));

    final ScrollPosition position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.activity.runtimeType, IdleScrollActivity);
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, 100.0);
    expect(position.pixels, 0.0);
    await tester.tap(find.byType(FlatButton));
    await tester.pumpAndSettle();

    final TestGesture drag1 = await tester.startGesture(const Offset(10.0, 500.0));
    await tester.pumpAndSettle();
    await drag1.moveTo(const Offset(10.0, 0.0));
    await tester.pumpAndSettle();
    await drag1.up();
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(500.00, 0.01));
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, 900.0);

    final TestGesture drag2 = await tester.startGesture(const Offset(10.0, 500.0));
    await tester.pumpAndSettle();
    await drag2.moveTo(const Offset(10.0, 100.0));
    await tester.pumpAndSettle();
    await drag2.up();
    await tester.pumpAndSettle();
    expect(position.maxScrollExtent, 900.0);
    expect(position.pixels, closeTo(900.00, 0.01));

    await tester.pumpAndSettle();
    await tester.tap(find.byType(FlatButton));
    await tester.pump();
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, 100.0);
    expect(position.pixels, 100.0);
  });

  testWidgets('shrink listview while dragging', (WidgetTester tester) async {
    // widget tests run at (800x600)@3.0x
    await tester.pumpWidget(MaterialApp(
      home: ListView.builder(
        itemBuilder: (BuildContext context, int index) => index == 0
              ? const ExpandingBox(collapsedSize: 400, expandedsize: 1200)
              : Container(height: 300, color: Colors.red),
        itemCount: 2,
      ),
    ));

    final ScrollPosition position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.activity.runtimeType, IdleScrollActivity);
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, 100.0);
    expect(position.pixels, 0.0);
    await tester.tap(find.byType(FlatButton));
    await tester.pumpAndSettle();

    final TestGesture drag1 = await tester.startGesture(const Offset(10.0, 500.0));
    await tester.pumpAndSettle();
    await drag1.moveTo(const Offset(10.0, 0.0));
    await tester.pumpAndSettle();
    await drag1.up();
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(500.00, 0.01));
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, 900.0);

    final TestGesture drag2 = await tester.startGesture(const Offset(10.0, 500.0));
    await tester.pumpAndSettle();
    await drag2.moveTo(const Offset(10.0, 100.0));
    await tester.pumpAndSettle();
    expect(position.maxScrollExtent, 900.0);
    expect(position.pixels, closeTo(900.00, 0.01));
    expect(position.activity.runtimeType, DragScrollActivity);

    await tester.tap(find.byType(FlatButton));
    await tester.pump();
    expect(position.activity.runtimeType, DragScrollActivity);
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, 900.0);
    expect(position.pixels, 900.0);

    await drag2.up();
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, 900.0);
    expect(position.pixels, 900.0);
  });

  testWidgets('whether we remember our scroll position', (WidgetTester tester) async {
    await performTest(tester, true);
    await performTest(tester, false);
  });

  testWidgets('scroll alignment is honored by ensureVisible', (WidgetTester tester) async {
    final List<int> items = List<int>.generate(11, (int index) => index).toList();
    final List<FocusNode> nodes = List<FocusNode>.generate(11, (int index) => FocusNode(debugLabel: 'Item ${index + 1}')).toList();
    final ScrollController controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          scrollDirection: Axis.vertical,
          controller: controller,
          children: items.map<Widget>((int item) {
            return Focus(
              key: ValueKey<int>(item),
              focusNode: nodes[item],
              child: Container(height: 110),
            );
          }).toList(),
        ),
      ),
    );

    controller.position.ensureVisible(
      tester.renderObject(find.byKey(const ValueKey<int>(0))),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
    expect(controller.position.pixels, equals(0.0));

    controller.position.ensureVisible(
      tester.renderObject(find.byKey(const ValueKey<int>(1))),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
    expect(controller.position.pixels, equals(0.0));

    controller.position.ensureVisible(
      tester.renderObject(find.byKey(const ValueKey<int>(1))),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    expect(controller.position.pixels, equals(0.0));

    controller.position.ensureVisible(
      tester.renderObject(find.byKey(const ValueKey<int>(4))),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
    expect(controller.position.pixels, equals(0.0));

    controller.position.ensureVisible(
      tester.renderObject(find.byKey(const ValueKey<int>(5))),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
    expect(controller.position.pixels, equals(0.0));

    controller.position.ensureVisible(
      tester.renderObject(find.byKey(const ValueKey<int>(5))),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    expect(controller.position.pixels, equals(60.0));

    controller.position.ensureVisible(
      tester.renderObject(find.byKey(const ValueKey<int>(0))),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
    expect(controller.position.pixels, equals(0.0));
  });
}
