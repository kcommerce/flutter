// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('AnimatedContainer.debugFillDescription', (WidgetTester tester) async {
    final AnimatedContainer container = new AnimatedContainer(
      constraints: const BoxConstraints.tightFor(width: 17.0, height: 23.0),
      decoration: const BoxDecoration(color: const Color(0xFF00FF00)),
      foregroundDecoration: const BoxDecoration(color: const Color(0x7F0000FF)),
      margin: const EdgeInsets.all(10.0),
      padding: const EdgeInsets.all(7.0),
      transform: new Matrix4.translationValues(4.0, 3.0, 0.0),
      width: 50.0,
      height: 75.0,
      curve: Curves.ease,
      duration: const Duration(milliseconds: 200),
    );

    expect(container, hasOneLineDescription);
  });

  testWidgets('AnimatedContainer control test', (WidgetTester tester) async {
    final GlobalKey key = new GlobalKey();

    final BoxDecoration decorationA = const BoxDecoration(
      color: const Color(0xFF00FF00),
    );

    final BoxDecoration decorationB = const BoxDecoration(
      color: const Color(0xFF0000FF),
    );

    BoxDecoration actualDecoration;

    await tester.pumpWidget(
      new AnimatedContainer(
        key: key,
        duration: const Duration(milliseconds: 200),
        decoration: decorationA
      )
    );

    final RenderDecoratedBox box = key.currentContext.findRenderObject();
    actualDecoration = box.decoration;
    expect(actualDecoration.color, equals(decorationA.color));

    await tester.pumpWidget(
      new AnimatedContainer(
        key: key,
        duration: const Duration(milliseconds: 200),
        decoration: decorationB
      )
    );

    expect(key.currentContext.findRenderObject(), equals(box));
    actualDecoration = box.decoration;
    expect(actualDecoration.color, equals(decorationA.color));

    await tester.pump(const Duration(seconds: 1));

    actualDecoration = box.decoration;
    expect(actualDecoration.color, equals(decorationB.color));

    expect(box, hasAGoodToStringDeep);
    expect(
      box.toStringDeep(),
      equalsIgnoringHashCodes(
        'RenderDecoratedBox#00000\n'
        ' │ creator: DecoratedBox ← Container ←\n'
        ' │   AnimatedContainer-[GlobalKey#00000] ← [root]\n'
        ' │ parentData: <none>\n'
        ' │ constraints: BoxConstraints(w=800.0, h=600.0)\n'
        ' │ size: Size(800.0, 600.0)\n'
        ' │ decoration:\n'
        ' │   color: Color(0xff0000ff)\n'
        ' │ configuration: ImageConfiguration(bundle:\n'
        ' │   PlatformAssetBundle#00000(), devicePixelRatio: 1.0, platform:\n'
        ' │   macos)\n'
        ' │\n'
        ' └─child: RenderLimitedBox#00000\n'
        '   │ creator: LimitedBox ← DecoratedBox ← Container ←\n'
        '   │   AnimatedContainer-[GlobalKey#00000] ← [root]\n'
        '   │ parentData: <none> (can use size)\n'
        '   │ constraints: BoxConstraints(w=800.0, h=600.0)\n'
        '   │ size: Size(800.0, 600.0)\n'
        '   │ maxWidth: 0.0\n'
        '   │ maxHeight: 0.0\n'
        '   │\n'
        '   └─child: RenderConstrainedBox#00000\n'
        '       creator: ConstrainedBox ← LimitedBox ← DecoratedBox ← Container ←\n'
        '         AnimatedContainer-[GlobalKey#00000] ← [root]\n'
        '       parentData: <none> (can use size)\n'
        '       constraints: BoxConstraints(w=800.0, h=600.0)\n'
        '       size: Size(800.0, 600.0)\n'
        '       additionalConstraints: BoxConstraints(biggest)\n',
      ),
    );
  });

  testWidgets('AnimatedContainer overanimate test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: const Color(0xFF00FF00),
      )
    );
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(
      new AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: const Color(0xFF00FF00),
      )
    );
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(
      new AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: const Color(0xFF0000FF),
      )
    );
    expect(tester.binding.transientCallbackCount, 1); // this is the only time an animation should have started!
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(
      new AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: const Color(0xFF0000FF),
      )
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Animation rerun', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Center(
        child: new AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 100.0,
          height: 100.0,
          child: const Text('X')
        )
      )
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    RenderBox text = tester.renderObject(find.text('X'));
    expect(text.size.width, equals(100.0));
    expect(text.size.height, equals(100.0));

    await tester.pump(const Duration(milliseconds: 1000));

    await tester.pumpWidget(
      new Center(
        child: new AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200.0,
          height: 200.0,
          child: const Text('X')
        )
      )
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    text = tester.renderObject(find.text('X'));
    expect(text.size.width, greaterThan(110.0));
    expect(text.size.width, lessThan(190.0));
    expect(text.size.height, greaterThan(110.0));
    expect(text.size.height, lessThan(190.0));

    await tester.pump(const Duration(milliseconds: 1000));

    expect(text.size.width, equals(200.0));
    expect(text.size.height, equals(200.0));

    await tester.pumpWidget(
      new Center(
        child: new AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200.0,
          height: 100.0,
          child: const Text('X')
        )
      )
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(text.size.width, equals(200.0));
    expect(text.size.height, greaterThan(110.0));
    expect(text.size.height, lessThan(190.0));

    await tester.pump(const Duration(milliseconds: 1000));

    expect(text.size.width, equals(200.0));
    expect(text.size.height, equals(100.0));
  });
}
