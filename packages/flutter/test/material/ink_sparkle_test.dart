// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file is run as part of a reduced test set in CI on Mac and Windows
// machines.
@Tags(<String>['reduced-test-set'])

import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/constants.dart';
import 'package:flutter_test/flutter_test.dart';

import '../rendering/mock_canvas.dart';

void main() {
  testWidgets('InkSparkle in a Button with default splashFactory paints by calling drawRect', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(splashFactory: InkSparkle.splashFactory),
            child: const Text('Sparkle!'),
            onPressed: () { },
          ),
        ),
      ),
    ));
    final Finder buttonFinder = find.text('Sparkle!');
    await tester.tap(buttonFinder);
    await tester.pump();
    await tester.pumpAndSettle();

    final MaterialInkController material = Material.of(tester.element(buttonFinder))!;
    await tester.pump(const Duration(milliseconds: 200));
    expect(material, paintsExactlyCountTimes(#drawRect, 1));
  },
    skip: kIsWeb, // [intended] SPIR-V shaders are not yet supported for web.
  );

  testWidgets('InkSparkle default splashFactory paints with drawRect when bounded', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: InkWell(
            splashFactory: InkSparkle.splashFactory,
            child: const Text('Sparkle!'),
            onTap: () { },
          ),
        ),
      ),
    ));
    final Finder buttonFinder = find.text('Sparkle!');
    await tester.tap(buttonFinder);
    await tester.pump();
    await tester.pumpAndSettle();

    final MaterialInkController material = Material.of(tester.element(buttonFinder))!;
    await tester.pump(const Duration(milliseconds: 200));
    expect(material, paintsExactlyCountTimes(#drawRect, 1));
  },
    skip: kIsWeb, // [intended] SPIR-V shaders are not yet supported for web.
  );

    testWidgets('InkSparkle default splashFactory paints with drawPaint when unbounded', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: InkResponse(
            splashFactory: InkSparkle.splashFactory,
            child: const Text('Sparkle!'),
            onTap: () { },
          ),
        ),
      ),
    ));
    final Finder buttonFinder = find.text('Sparkle!');
    await tester.tap(buttonFinder);
    await tester.pump();
    await tester.pumpAndSettle();

    final MaterialInkController material = Material.of(tester.element(buttonFinder))!;
    await tester.pump(const Duration(milliseconds: 200));
    expect(material, paintsExactlyCountTimes(#drawPaint, 1));
  },
    skip: kIsWeb, // [intended] SPIR-V shaders are not yet supported for web.
  );

  /////////////
  // Goldens //
  /////////////

  testWidgets('InkSparkle renders with sparkles when top left of button is tapped', (WidgetTester tester) async {
    await _runTest(tester, 'top_left', 0.2);
  },
    skip: kIsWeb, // [intended] SPIR-V shaders are not yet supported for web.
  );

  testWidgets('InkSparkle renders with sparkles when center of button is tapped', (WidgetTester tester) async {
    await _runTest(tester, 'center', 0.5);
  },
    skip: kIsWeb, // [intended] SPIR-V shaders are not yet supported for web.
  );

  testWidgets('InkSparkle renders with sparkles when bottom right of button is tapped', (WidgetTester tester) async {
    await _runTest(tester, 'bottom_right', 0.8);
  },
    skip: kIsWeb, // [intended] SPIR-V shaders are not yet supported for web.
  );
}

Future<void> _runTest(WidgetTester tester, String positionName, double distanceFromTopLeft) async {
  final Key repaintKey = UniqueKey();
  final Key buttonKey = UniqueKey();

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: repaintKey,
          child: ElevatedButton(
            key: buttonKey,
            style: ElevatedButton.styleFrom(splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory),
            child: const Text('Sparkle!'),
            onPressed: () { },
          ),
        ),
      ),
    ),
  ));

  final Finder buttonFinder = find.byKey(buttonKey);
  final Finder repaintFinder = find.byKey(repaintKey);

  await _warmUpShader(tester, buttonFinder);

  final Offset topLeft = tester.getTopLeft(buttonFinder);
  final Offset bottomRight = tester.getBottomRight(buttonFinder);

  final Offset target = topLeft + (bottomRight - topLeft) * distanceFromTopLeft;
  await tester.tapAt(target);
  for (int i = 0; i <= 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      repaintFinder,
      matchesGoldenFile('ink_sparkle.$positionName.$i.png'),
    );
  }
}

// Warm up shader. Compilation is of the order of 10 milliseconds and
// Animation is < 1000 milliseconds. Use 2000 milliseconds as a safety
// net to prevent flakiness.
Future<void> _warmUpShader(WidgetTester tester, Finder buttonFinder) async {
  await tester.tap(buttonFinder);
  await tester.pumpAndSettle(const Duration(milliseconds: 2000));
}
