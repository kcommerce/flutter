// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;

void main() {
  late DateTime firstDate;
  late DateTime lastDate;
  late DateTime initialDate;

  setUp(() {
    firstDate = DateTime(2001);
    lastDate = DateTime(2031, DateTime.december, 31);
    initialDate = DateTime(2016, DateTime.january, 15);
  });

  group(CalendarDatePicker, () {
    final intl.NumberFormat arabicNumbers = intl.NumberFormat('0', 'ar');
    final Map<Locale, Map<String, dynamic>> testLocales = <Locale, Map<String, dynamic>>{
      // Tests the default.
      const Locale('en', 'US'): <String, dynamic>{
        'textDirection': TextDirection.ltr,
        'expectedDaysOfWeek': <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'],
        'expectedDaysOfMonth': List<String>.generate(30, (final int i) => '${i + 1}'),
        'expectedMonthYearHeader': 'September 2017',
      },
      // Tests a different first day of week.
      const Locale('ru', 'RU'): <String, dynamic>{
        'textDirection': TextDirection.ltr,
        'expectedDaysOfWeek': <String>['В', 'П', 'В', 'С', 'Ч', 'П', 'С',],
        'expectedDaysOfMonth': List<String>.generate(30, (final int i) => '${i + 1}'),
        'expectedMonthYearHeader': 'сентябрь 2017 г.',
      },
      const Locale('ro', 'RO'): <String, dynamic>{
        'textDirection': TextDirection.ltr,
        'expectedDaysOfWeek': <String>['D', 'L', 'M', 'M', 'J', 'V', 'S'],
        'expectedDaysOfMonth': List<String>.generate(30, (final int i) => '${i + 1}'),
        'expectedMonthYearHeader': 'septembrie 2017',
      },
      // Tests RTL.
      const Locale('ar', 'AR'): <String, dynamic>{
        'textDirection': TextDirection.rtl,
        'expectedDaysOfWeek': <String>['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'],
        'expectedDaysOfMonth': List<String>.generate(30, (final int i) => arabicNumbers.format(i + 1)),
        'expectedMonthYearHeader': 'سبتمبر ٢٠١٧',
      },
    };

    for (final Locale locale in testLocales.keys) {
      testWidgets('shows dates for $locale', (final WidgetTester tester) async {
        final List<String> expectedDaysOfWeek = testLocales[locale]!['expectedDaysOfWeek'] as List<String>;
        final List<String> expectedDaysOfMonth = testLocales[locale]!['expectedDaysOfMonth'] as List<String>;
        final String expectedMonthYearHeader = testLocales[locale]!['expectedMonthYearHeader'] as String;
        final TextDirection textDirection = testLocales[locale]!['textDirection'] as TextDirection;
        final DateTime baseDate = DateTime(2017, 9, 27);

        await _pumpBoilerplate(tester, CalendarDatePicker(
          initialDate: baseDate,
          firstDate: baseDate.subtract(const Duration(days: 90)),
          lastDate: baseDate.add(const Duration(days: 90)),
          onDateChanged: (final DateTime newValue) {},
        ), locale: locale, textDirection: textDirection);

        expect(find.text(expectedMonthYearHeader), findsOneWidget);

        for (final String dayOfWeek in expectedDaysOfWeek) {
          expect(find.text(dayOfWeek), findsWidgets);
        }

        Offset? previousCellOffset;
        for (final String dayOfMonth in expectedDaysOfMonth) {
          final Finder dayCell = find.descendant(of: find.byType(GridView), matching: find.text(dayOfMonth));
          expect(dayCell, findsOneWidget);

          // Check that cells are correctly positioned relative to each other,
          // taking text direction into account.
          final Offset offset = tester.getCenter(dayCell);
          if (previousCellOffset != null) {
            if (textDirection == TextDirection.ltr) {
              expect(offset.dx > previousCellOffset.dx && offset.dy == previousCellOffset.dy || offset.dy > previousCellOffset.dy, true);
            } else {
              expect(offset.dx < previousCellOffset.dx && offset.dy == previousCellOffset.dy || offset.dy > previousCellOffset.dy, true);
            }
          }
          previousCellOffset = offset;
        }
      });
    }
  });

  testWidgets('locale parameter overrides ambient locale', (final WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', 'US'),
      supportedLocales: const <Locale>[
        Locale('en', 'US'),
        Locale('fr', 'CA'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Material(
        child: Builder(
          builder: (final BuildContext context) {
            return TextButton(
              onPressed: () async {
                await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  locale: const Locale('fr', 'CA'),
                );
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final Element picker = tester.element(find.byType(CalendarDatePicker));
    expect(
      Localizations.localeOf(picker),
      const Locale('fr', 'CA'),
    );

    expect(
      Directionality.of(picker),
      TextDirection.ltr,
    );

    await tester.tap(find.text('ANNULER'));
  });

  testWidgets('textDirection parameter overrides ambient textDirection', (final WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', 'US'),
      home: Material(
        child: Builder(
          builder: (final BuildContext context) {
            return TextButton(
              onPressed: () async {
                await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  textDirection: TextDirection.rtl,
                );
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final Element picker = tester.element(find.byType(CalendarDatePicker));
    expect(
      Directionality.of(picker),
      TextDirection.rtl,
    );

    await tester.tap(find.text('CANCEL'));
  });

  testWidgets('textDirection parameter takes precedence over locale parameter', (final WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', 'US'),
      supportedLocales: const <Locale>[
        Locale('en', 'US'),
        Locale('fr', 'CA'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Material(
        child: Builder(
          builder: (final BuildContext context) {
            return TextButton(
              onPressed: () async {
                await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  locale: const Locale('fr', 'CA'),
                  textDirection: TextDirection.rtl,
                );
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final Element picker = tester.element(find.byType(CalendarDatePicker));
    expect(
      Localizations.localeOf(picker),
      const Locale('fr', 'CA'),
    );

    expect(
      Directionality.of(picker),
      TextDirection.rtl,
    );

    await tester.tap(find.text('ANNULER'));
  });

  group("locale fonts don't overflow layout", () {
    // Test screen layouts in various locales to ensure the fonts used
    // don't overflow the layout

    // Common screen size roughly based on a Pixel 1
    const Size kCommonScreenSizePortrait = Size(1070, 1770);
    const Size kCommonScreenSizeLandscape = Size(1770, 1070);

    Future<void> showPicker(final WidgetTester tester, final Locale locale, final Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (final BuildContext context) {
              return Localizations(
                locale: locale,
                delegates: GlobalMaterialLocalizations.delegates,
                child: TextButton(
                  child: const Text('X'),
                  onPressed: () {
                    showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                    );
                  },
                ),
              );
            },
          ),
        )
      );
      await tester.tap(find.text('X'));
      await tester.pumpAndSettle();
    }

    // Regression test for https://github.com/flutter/flutter/issues/20171
    testWidgets('common screen size - portrait - Chinese', (final WidgetTester tester) async {
      await showPicker(tester, const Locale('zh', 'CN'), kCommonScreenSizePortrait);
      expect(tester.takeException(), isNull);
    });

    testWidgets('common screen size - landscape - Chinese', (final WidgetTester tester) async {
      await showPicker(tester, const Locale('zh', 'CN'), kCommonScreenSizeLandscape);
      expect(tester.takeException(), isNull);
    });

    testWidgets('common screen size - portrait - Japanese', (final WidgetTester tester) async {
      await showPicker(tester, const Locale('ja', 'JA'), kCommonScreenSizePortrait);
      expect(tester.takeException(), isNull);
    });

    testWidgets('common screen size - landscape - Japanese', (final WidgetTester tester) async {
      await showPicker(tester, const Locale('ja', 'JA'), kCommonScreenSizeLandscape);
      expect(tester.takeException(), isNull);
    });
  });

}

Future<void> _pumpBoilerplate(
  final WidgetTester tester,
  final Widget child, {
  final Locale locale = const Locale('en', 'US'),
  final TextDirection textDirection = TextDirection.ltr,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Localizations(
        locale: locale,
        delegates: GlobalMaterialLocalizations.delegates,
        child: Material(
          child: child,
        ),
      ),
    ),
  ));
}
