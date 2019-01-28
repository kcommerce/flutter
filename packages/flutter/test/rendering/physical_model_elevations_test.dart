// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderPhysicalModel checks elevation', () {
    Future<void> _testStackChildren(WidgetTester tester, List<Widget> children, int expectedErrorCount) async {
      int count = 0;
      final Function oldOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        count++;
      };
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
            children: children,
          ),
        ),
      );
      FlutterError.onError = oldOnError;
      expect(count, expectedErrorCount);
    }

    testWidgets('entirely overlapping, correct painting order', (WidgetTester tester) async {
      final List<Widget> children = <Widget>[
        Container(
          width: 300,
          height: 300,
          child: const Material(
            elevation: 1.0,
            color: Colors.green,
          ),
        ),
        Container(
          width: 300,
          height: 300,
          child: const Material(
            elevation: 2.0,
            color: Colors.blue,
          ),
        ),
      ];

      await _testStackChildren(tester, children, 0);
      expect(find.byType(Material), findsNWidgets(2));
    });

    testWidgets('entirely overlapping, wrong painting order', (WidgetTester tester) async {
      final List<Widget> children = <Widget>[
        Container(
          width: 300,
          height: 300,
          child: const Material(
            elevation: 2.0,
            color: Colors.green,
          ),
        ),
        Container(
          width: 300,
          height: 300,
          child: const Material(
            elevation: 1.0,
            color: Colors.blue,
          ),
        ),
      ];

      await _testStackChildren(tester, children, 1);
      expect(find.byType(Material), findsNWidgets(2));
    });

    testWidgets('not non-rect not overlapping, wrong painting order', (WidgetTester tester) async {
      // These would be overlapping if we only took the rectangular bounds of the circle.
      final List<Widget> children = <Widget>[
        Positioned.fromRect(
          rect: Rect.fromLTWH(150, 150, 150, 150),
          child: Container(
            width: 300,
            height: 300,
            child: const Material(
              elevation: 3.0,
              color: Colors.brown,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: Rect.fromLTWH(20, 20, 140, 150),
          child: Container(
            width: 300,
            height: 300,
            child: const Material(
              elevation: 2.0,
              color: Colors.red,
              shape: CircleBorder()
            ),
          ),
        ),
      ];

      await _testStackChildren(tester, children, 0);
      expect(find.byType(Material), findsNWidgets(2));
    });

    testWidgets('not non-rect entirely overlapping, wrong painting order', (WidgetTester tester) async {
      final List<Widget> children = <Widget>[
        Positioned.fromRect(
          rect: Rect.fromLTWH(20, 20, 140, 150),
          child: Container(
            width: 300,
            height: 300,
            child: const Material(
              elevation: 3.0,
              color: Colors.brown,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: Rect.fromLTWH(50, 50, 100, 100),
          child: Container(
            width: 300,
            height: 300,
            child: const Material(
              elevation: 2.0,
              color: Colors.red,
              shape: CircleBorder()
            ),
          ),
        ),
      ];

      await _testStackChildren(tester, children, 1);
      expect(find.byType(Material), findsNWidgets(2));
    });


    testWidgets('non-rect partially overlapping, wrong painting order', (WidgetTester tester) async {
      final List<Widget> children = <Widget>[
        Positioned.fromRect(
          rect: Rect.fromLTWH(150, 150, 150, 150),
          child: Container(
            width: 300,
            height: 300,
            child: const Material(
              elevation: 3.0,
              color: Colors.brown,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: Rect.fromLTWH(30, 20, 150, 150),
          child: Container(
            width: 300,
            height: 300,
            child: const Material(
              elevation: 2.0,
              color: Colors.red,
              shape: CircleBorder()
            ),
          ),
        ),
      ];

      await _testStackChildren(tester, children, 1);
      expect(find.byType(Material), findsNWidgets(2));
    });

    testWidgets('non-rect partially overlapping, wrong painting order, max to check is 0', (WidgetTester tester) async {
      final int previousMax = tester.binding.pipelineOwner.maxElevationObjectsToCheck;
      tester.binding.pipelineOwner.maxElevationObjectsToCheck = 0; // disables the check.

      final List<Widget> children = <Widget>[
        Positioned.fromRect(
          rect: Rect.fromLTWH(150, 150, 150, 150),
          child: Container(
            width: 300,
            height: 300,
            child: const Material(
              elevation: 3.0,
              color: Colors.brown,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: Rect.fromLTWH(30, 20, 150, 150),
          child: Container(
            width: 300,
            height: 300,
            child: const Material(
              elevation: 2.0,
              color: Colors.red,
              shape: CircleBorder()
            ),
          ),
        ),
      ];

      await _testStackChildren(tester, children, 0);
      expect(find.byType(Material), findsNWidgets(2));
      tester.binding.pipelineOwner.maxElevationObjectsToCheck = previousMax;
    });
  });
}