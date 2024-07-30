// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// reduced-test-set:
//   This file is run as part of a reduced test set in CI on Mac and Windows
//   machines.
@Tags(<String>['reduced-test-set'])
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/semantics_tester.dart';

void main() {
  setUp(() {
    debugResetSemanticsIdCounter();
  });

  testWidgets('CupertinoCheckbox semantics', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      CupertinoApp (
        home: Center(
          child: CupertinoCheckbox(
            value: false,
            onChanged: (bool? b) { },
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.byType(Focus).last), matchesSemantics(
      hasCheckedState: true,
      hasEnabledState: true,
      isEnabled: true,
      hasTapAction: true,
      hasFocusAction: true,
      isFocusable: true,
    ));

    await tester.pumpWidget(
      CupertinoApp (
        home: Center(
          child: CupertinoCheckbox(
            value: true,
            onChanged: (bool? b) { },
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.byType(Focus).last), matchesSemantics(
      hasCheckedState: true,
      hasEnabledState: true,
      isChecked: true,
      isEnabled: true,
      hasTapAction: true,
      hasFocusAction: true,
      isFocusable: true,
    ));

    await tester.pumpWidget(
      const CupertinoApp (
        home: Center(
          child: CupertinoCheckbox(
            value: false,
            onChanged: null,
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.byType(CupertinoCheckbox)), matchesSemantics(
      hasCheckedState: true,
      hasEnabledState: true,
      // isFocusable is delayed by 1 frame.
      isFocusable: true,
      hasFocusAction: true,
    ));

    await tester.pump();
    // isFocusable should be false now after the 1 frame delay.
    expect(tester.getSemantics(find.byType(CupertinoCheckbox)), matchesSemantics(
      hasCheckedState: true,
      hasEnabledState: true,
    ));

    await tester.pumpWidget(
      const CupertinoApp (
        home: Center(
          child: CupertinoCheckbox(
            value: true,
            onChanged: null,
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.byType(CupertinoCheckbox)), matchesSemantics(
      hasCheckedState: true,
      hasEnabledState: true,
      isChecked: true,
    ));

    await tester.pumpWidget(
      const CupertinoApp (
        home: Center(
          child: CupertinoCheckbox(
            value: null,
            tristate: true,
            onChanged: null,
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.byType(CupertinoCheckbox)), matchesSemantics(
      hasCheckedState: true,
      hasEnabledState: true,
      isCheckStateMixed: true,
    ));

    await tester.pumpWidget(
      const CupertinoApp (
        home: Center(
          child: CupertinoCheckbox(
            value: true,
            tristate: true,
            onChanged: null,
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.byType(CupertinoCheckbox)), matchesSemantics(
      hasCheckedState: true,
      hasEnabledState: true,
      isChecked: true,
    ));

    await tester.pumpWidget(
      const CupertinoApp (
        home: Center(
          child: CupertinoCheckbox(
            value: false,
            tristate: true,
            onChanged: null,
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.byType(CupertinoCheckbox)), matchesSemantics(
      hasCheckedState: true,
      hasEnabledState: true,
    ));

    handle.dispose();
  });

  testWidgets('Can wrap CupertinoCheckbox with Semantics', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      CupertinoApp(
        home: Semantics(
          label: 'foo',
          textDirection: TextDirection.ltr,
          child: CupertinoCheckbox(
            value: false,
            onChanged: (bool? b) { },
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.byType(Focus).last), matchesSemantics(
      label: 'foo',
      textDirection: TextDirection.ltr,
      hasCheckedState: true,
      hasEnabledState: true,
      isEnabled: true,
      hasTapAction: true,
      hasFocusAction: true,
      isFocusable: true,
    ));
    handle.dispose();
  });

  testWidgets('CupertinoCheckbox tristate: true', (WidgetTester tester) async {
    bool? checkBoxValue;

    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return CupertinoCheckbox(
              tristate: true,
              value: checkBoxValue,
              onChanged: (bool? value) {
                setState(() {
                  checkBoxValue = value;
                });
              },
            );
          },
        ),
      ),
    );

    expect(tester.widget<CupertinoCheckbox>(find.byType(CupertinoCheckbox)).value, null);

    await tester.tap(find.byType(CupertinoCheckbox));
    await tester.pumpAndSettle();
    expect(checkBoxValue, false);

    await tester.tap(find.byType(CupertinoCheckbox));
    await tester.pumpAndSettle();
    expect(checkBoxValue, true);

    await tester.tap(find.byType(CupertinoCheckbox));
    await tester.pumpAndSettle();
    expect(checkBoxValue, null);

    checkBoxValue = true;
    await tester.pumpAndSettle();
    expect(checkBoxValue, true);

    checkBoxValue = null;
    await tester.pumpAndSettle();
    expect(checkBoxValue, null);
  });

  testWidgets('has semantics for tristate', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoCheckbox(
          tristate: true,
          value: null,
          onChanged: (bool? newValue) { },
        ),
      ),
    );

    expect(semantics.nodesWith(
      flags: <SemanticsFlag>[
        SemanticsFlag.hasCheckedState,
        SemanticsFlag.hasEnabledState,
        SemanticsFlag.isEnabled,
        SemanticsFlag.isFocusable,
        SemanticsFlag.isCheckStateMixed,
      ],
      actions: <SemanticsAction>[SemanticsAction.focus, SemanticsAction.tap],
    ), hasLength(1));

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoCheckbox(
          tristate: true,
          value: true,
          onChanged: (bool? newValue) { },
        ),
      ),
    );

    expect(semantics.nodesWith(
      flags: <SemanticsFlag>[
        SemanticsFlag.hasCheckedState,
        SemanticsFlag.hasEnabledState,
        SemanticsFlag.isEnabled,
        SemanticsFlag.isChecked,
        SemanticsFlag.isFocusable,
      ],
      actions: <SemanticsAction>[SemanticsAction.tap, SemanticsAction.focus],
    ), hasLength(1));

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoCheckbox(
          tristate: true,
          value: false,
          onChanged: (bool? newValue) { },
        ),
      ),
    );

    expect(semantics.nodesWith(
      flags: <SemanticsFlag>[
        SemanticsFlag.hasCheckedState,
        SemanticsFlag.hasEnabledState,
        SemanticsFlag.isEnabled,
        SemanticsFlag.isFocusable,
      ],
      actions: <SemanticsAction>[SemanticsAction.tap, SemanticsAction.focus],
    ), hasLength(1));

    semantics.dispose();
  });

  testWidgets('has semantic events', (WidgetTester tester) async {
    dynamic semanticEvent;
    bool? checkboxValue = false;
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (dynamic message) async {
      semanticEvent = message;
    });
    final SemanticsTester semanticsTester = SemanticsTester(tester);

    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return CupertinoCheckbox(
              value: checkboxValue,
              onChanged: (bool? value) {
                setState(() {
                  checkboxValue = value;
                });
              },
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(CupertinoCheckbox));
    final RenderObject object = tester.firstRenderObject(find.byType(CupertinoCheckbox));

    expect(checkboxValue, true);
    expect(semanticEvent, <String, dynamic>{
      'type': 'tap',
      'nodeId': object.debugSemantics!.id,
      'data': <String, dynamic>{},
    });
    expect(object.debugSemantics!.getSemanticsData().hasAction(SemanticsAction.tap), true);

    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null);
    semanticsTester.dispose();
  });

  testWidgets('Checkbox can configure a semantic label', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      CupertinoApp (
        home: Center(
          child: CupertinoCheckbox(
            value: false,
            onChanged: (bool? b) { },
            semanticLabel: 'checkbox',
          ),
        ),
      ),
    );
    expect(tester.getSemantics(find.byType(Focus).last), matchesSemantics(
      hasCheckedState: true,
      hasEnabledState: true,
      isEnabled: true,
      hasTapAction: true,
      hasFocusAction: true,
      isFocusable: true,
      label: 'checkbox'
    ));

    // If wrapped with semantics, both the parent semantic label and the
    // checkbox's semantic label are used in annotation.
    await tester.pumpWidget(
      CupertinoApp(
        home: Semantics(
          label: 'foo',
          textDirection: TextDirection.ltr,
          child: CupertinoCheckbox(
            value: false,
            onChanged: (bool? b) { },
            semanticLabel: 'checkbox',
          ),
        ),
      ),
    );
    expect(tester.getSemantics(find.byType(Focus).last), matchesSemantics(
      label: 'foo\ncheckbox',
      textDirection: TextDirection.ltr,
      hasCheckedState: true,
      hasEnabledState: true,
      isEnabled: true,
      hasTapAction: true,
      hasFocusAction: true,
      isFocusable: true,
    ));
    handle.dispose();
  });

  testWidgets('Checkbox can be toggled by keyboard shortcuts', (WidgetTester tester) async {
    tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    bool? value = true;
    Widget buildApp({bool enabled = true}) {
      return CupertinoApp(
        home: Center(
          child: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
            return CupertinoCheckbox(
              value: value,
              onChanged: enabled ? (bool? newValue) {
                setState(() {
                  value = newValue;
                });
              } : null,
              autofocus: true,
            );
          }),
        ),
      );
    }
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // On web, switches don't respond to the enter key.
    expect(value, kIsWeb ? isTrue : isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(value, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('Checkbox respects shape and side', (WidgetTester tester) async {
    const RoundedRectangleBorder roundedRectangleBorder =
        RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5)));

    const BorderSide side = BorderSide(
      width: 4,
      color: Color(0xfff44336),
    );

    Widget buildApp() {
      return CupertinoApp(
        home: Center(
          child: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
            return CupertinoCheckbox(
              value: false,
              onChanged: (bool? newValue) {},
              shape: roundedRectangleBorder,
              side: side,
            );
          }),
        ),
      );
    }

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(tester.widget<CupertinoCheckbox>(find.byType(CupertinoCheckbox)).shape, roundedRectangleBorder);
    expect(tester.widget<CupertinoCheckbox>(find.byType(CupertinoCheckbox)).side, side);
    expect(
      find.byType(CupertinoCheckbox),
      paints
        ..drrect(
          color: const Color(0xfff44336),
          outer: RRect.fromLTRBR(15.0, 15.0, 29.0, 29.0, const Radius.circular(5)),
          inner: RRect.fromLTRBR(19.0, 19.0, 25.0, 25.0, const Radius.circular(1)),
        ),
    );
  });

  testWidgets('Checkbox default colors, and size in light mode', (WidgetTester tester) async {
    Widget buildCheckbox({bool value = true}) {
      return CupertinoApp(
        home: Center(
          child: RepaintBoundary(
            child: CupertinoCheckbox(
              value: value,
              onChanged: (bool? newValue) {},
            ),
          ),
        ),
      );
    }
    await tester.pumpWidget(buildCheckbox());
    await expectLater(
      find.byType(CupertinoCheckbox),
      matchesGoldenFile('checkbox.light_theme.selected.png'),
    );
    await tester.pumpWidget(buildCheckbox(value: false));
    await expectLater(
      find.byType(CupertinoCheckbox),
      matchesGoldenFile('checkbox.light_theme.unselected.png'),
    );
  });

  testWidgets('Checkbox default colors, and size in dark mode', (WidgetTester tester) async {
    Widget buildCheckbox({bool value = true}) {
      return CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: Center(
          child: RepaintBoundary(
            child: CupertinoCheckbox(
              value: value,
              onChanged: (bool? newValue) {},
            ),
          ),
        ),
      );
    }
    await tester.pumpWidget(buildCheckbox());
    await expectLater(
      find.byType(CupertinoCheckbox),
      matchesGoldenFile('checkbox.dark_theme.selected.png'),
    );
    await tester.pumpWidget(buildCheckbox(value: false));
    await expectLater(
      find.byType(CupertinoCheckbox),
      matchesGoldenFile('checkbox.dark_theme.unselected.png'),
    );
  });

  testWidgets('Disabled checkbox default colors, and size in light mode', (WidgetTester tester) async {
    Widget buildCheckbox({bool value = true}) {
      return CupertinoApp(
        home: Center(
          child: RepaintBoundary(
            child: CupertinoCheckbox(
              value: value,
              onChanged: null,
            ),
          ),
        ),
      );
    }
    await tester.pumpWidget(buildCheckbox());
    await expectLater(
      find.byType(CupertinoCheckbox),
      matchesGoldenFile('checkbox.disabled_light_theme.selected.png'),
    );
    await tester.pumpWidget(buildCheckbox(value: false));
    await expectLater(
      find.byType(CupertinoCheckbox),
      matchesGoldenFile('checkbox.disabled_light_theme.unselected.png'),
    );
  });

  testWidgets('Disabled checkbox default colors, and size in dark mode', (WidgetTester tester) async {
    Widget buildCheckbox({bool value = true}) {
      return CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: Center(
          child: RepaintBoundary(
            child: CupertinoCheckbox(
              value: value,
              onChanged: null,
            ),
          ),
        ),
      );
    }
    await tester.pumpWidget(buildCheckbox());
    await expectLater(
      find.byType(CupertinoCheckbox),
      matchesGoldenFile('checkbox.disabled_dark_theme.selected.png'),
    );
    await tester.pumpWidget(buildCheckbox(value: false));
    await expectLater(
      find.byType(CupertinoCheckbox),
      matchesGoldenFile('checkbox.disabled_dark_theme.unselected.png'),
    );
  });

  testWidgets('Checkbox configures focus color', (WidgetTester tester) async {
    const Color defaultCheckColor = Color(0xffffffff);
    const Color defaultActiveFillColor = Color(0xff007aff);
    const Color defaultFocusColor = Color(0xcc6eadf2);
    const Color testFocusColor = Color(0xffaabbcc);
    tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    final FocusNode node = FocusNode();
    addTearDown(node.dispose);

    Widget buildApp({Color? focusColor, bool autofocus = false, FocusNode? focusNode}) {
      return CupertinoApp(
        home: Center(
          child: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
            return CupertinoCheckbox(
              value: true,
              onChanged: (bool? newValue) {},
              autofocus: autofocus,
              focusNode: focusNode,
              focusColor: focusColor,
            );
          }),
        ),
      );
    }
    await tester.pumpWidget(buildApp(focusNode: node, autofocus: true));
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    expect(
      find.byType(CupertinoCheckbox),
      paints
        ..path(color: defaultActiveFillColor)
        ..rrect()
        ..path(color: defaultCheckColor)
        ..path(color: defaultFocusColor, strokeWidth: 3.5, style: PaintingStyle.stroke),
      reason: 'Checkbox shows the correct focus color',
    );

    await tester.pumpWidget(buildApp(
      focusColor: testFocusColor,
      focusNode: node,
      autofocus: true,
    ));
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    expect(
      find.byType(CupertinoCheckbox),
      paints
        ..path(color: defaultActiveFillColor)
        ..rrect()
        ..path(color: defaultCheckColor)
        ..path(color: testFocusColor, strokeWidth: 3.5, style: PaintingStyle.stroke),
        reason: 'Checkbox can configure a focus color',
    );
  });

  testWidgets('Checkbox is darkened when pressed in light mode', (WidgetTester tester) async {
    const Color defaultCheckColor = Color(0xffffffff);
    const Color defaultActiveFillColor = Color(0xff007aff);
    const Color defaultInactiveFillColor = Color(0xffffffff);
    const Color pressedDarkShadow = Color(0x26ffffff);

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoCheckbox(
            value: false,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final TestGesture gesture1 = await tester.startGesture(tester.getCenter(find.byType(CupertinoCheckbox)));
    await tester.pump();

    expect(
      find.byType(CupertinoCheckbox),
      paints
        ..path(color: defaultInactiveFillColor)
        ..drrect()
        ..path(color: pressedDarkShadow),
      reason: 'Inactive pressed checkbox is slightly darkened',
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoCheckbox(
            value: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final TestGesture gesture2 = await tester.startGesture(tester.getCenter(find.byType(CupertinoCheckbox)));
    await tester.pump();

    expect(
      find.byType(CupertinoCheckbox),
      paints
        ..path(color: defaultActiveFillColor)
        ..rrect()
        ..path(color: defaultCheckColor)
        ..path(color: pressedDarkShadow),
      reason: 'Active pressed checkbox is slightly darkened',
    );

    // Finish gestures to release resources.
    await gesture1.up();
    await gesture2.up();
    await tester.pump();
  });

  testWidgets('Checkbox is lightened when pressed in dark mode', (WidgetTester tester) async {
    const Color checkColor = Color(0xffffffff);
    const Color defaultActiveFillColor = Color(0xff3264d7);
    const Color defaultInactiveFillColor = Color(0xff000000);
    const Color pressedLightShadow = Color(0x26ffffff);

    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: Center(
          child: CupertinoCheckbox(
            value: false,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final TestGesture gesture1 = await tester.startGesture(tester.getCenter(find.byType(CupertinoCheckbox)));
    await tester.pump();

    expect(
      find.byType(CupertinoCheckbox),
      paints
        ..path(color: defaultInactiveFillColor)
        ..drrect()
        ..path(color: pressedLightShadow),
      reason: 'Inactive pressed checkbox is slightly lightened',
    );

    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: Center(
          child: CupertinoCheckbox(
            value: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final TestGesture gesture2 = await tester.startGesture(tester.getCenter(find.byType(CupertinoCheckbox)));
    await tester.pump();

    expect(
      find.byType(CupertinoCheckbox),
      paints
        ..path(color: defaultActiveFillColor)
        ..rrect()
        ..path(color: checkColor)
        ..path(color: pressedLightShadow),
      reason: 'Active pressed checkbox is slightly lightened',
    );

    // Finish gestures to release resources.
    await gesture1.up();
    await gesture2.up();
    await tester.pump();
  });
}
