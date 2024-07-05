// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file is run as part of a reduced test set in CI on Mac and Windows
// machines.
@Tags(<String>['reduced-test-set'])
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/semantics_tester.dart';

int count = 0;

void main() {
  testWidgets('Middle still in center with asymmetrical actions', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoNavigationBar(
          leading: CupertinoButton(
            onPressed: null,
            child: Text('Something'),
          ),
          middle: Text('Title'),
        ),
      ),
    );

    // Expect the middle of the title to be exactly in the middle of the screen.
    expect(tester.getCenter(find.text('Title')).dx, 400.0);
  });

  testWidgets('Middle still in center with back button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoNavigationBar(
          middle: Text('Title'),
        ),
      ),
    );

    tester.state<NavigatorState>(find.byType(Navigator)).push(CupertinoPageRoute<void>(
      builder: (BuildContext context) {
        return const CupertinoNavigationBar(
          middle: Text('Page 2'),
        );
      },
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Expect the middle of the title to be exactly in the middle of the screen.
    expect(tester.getCenter(find.text('Page 2')).dx, 400.0);
  });

  testWidgets('Opaque background does not add blur effects, non-opaque background adds blur effects', (WidgetTester tester) async {
    const CupertinoDynamicColor background = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFE5E5E5),
      darkColor: Color(0xF3E5E5E5),
    );

    final ScrollController scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Title'),
            backgroundColor: background,
          ),
          child: ListView(
            controller: scrollController,
            children: const <Widget>[
              Placeholder(),
            ],
          ),
        ),
      ),
    );

    scrollController.jumpTo(100.0);
    await tester.pump();

    expect(
      tester.widget(find.byType(BackdropFilter)),
      isA<BackdropFilter>().having((BackdropFilter filter) => filter.enabled, 'filter enabled', false),
    );
    expect(find.byType(CupertinoNavigationBar), paints..rect(color: background.color));

    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Title'),
            backgroundColor: background,
          ),
          child: ListView(
            controller: scrollController,
            children: const <Widget>[
              Placeholder(),
            ],
          ),
        ),
      ),
    );

    scrollController.jumpTo(100.0);
    await tester.pump();

    expect(
      tester.widget(find.byType(BackdropFilter)),
      isA<BackdropFilter>().having((BackdropFilter f) => f.enabled, 'filter enabled', true),
    );
    expect(find.byType(CupertinoNavigationBar), paints..rect(color: background.darkColor));
  });

  testWidgets("Background doesn't add blur effect when no content is scrolled under", (WidgetTester test) async {
    final ScrollController scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await test.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Title'),
          ),
          child: ListView(
            controller: scrollController,
            children: const <Widget>[
              Placeholder(),
            ],
          ),
        ),
      ),
    );

    expect(
      test.widget(find.byType(BackdropFilter)),
      isA<BackdropFilter>().having((BackdropFilter filter) => filter.enabled, 'filter enabled', false),
    );

    scrollController.jumpTo(100.0);
    await test.pump();

    expect(
      test.widget(find.byType(BackdropFilter)),
      isA<BackdropFilter>().having((BackdropFilter filter) => filter.enabled, 'filter enabled', true),
    );
  });

  testWidgets('Nav bar displays correctly', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigator,
        home: const CupertinoNavigationBar(
          middle: Text('Page 1'),
        ),
      ),
    );
    navigator.currentState!.push<void>(CupertinoPageRoute<void>(
      builder: (BuildContext context) {
        return const CupertinoNavigationBar(
          middle: Text('Page 2'),
        );
      },
    ));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
    // Pops the page 2
    navigator.currentState!.pop();
    await tester.pump();
    // Needs another pump to trigger the rebuild;
    await tester.pump();
    // The back button should still persist;
    expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
    // The app does not crash
    expect(tester.takeException(), isNull);
  });

  testWidgets('Can specify custom padding', (WidgetTester tester) async {
    final Key middleBox = GlobalKey();
    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: CupertinoNavigationBar(
            leading: const CupertinoButton(onPressed: null, child: Text('Cheetah')),
            // Let the box take all the vertical space to test vertical padding but let
            // the nav bar position it horizontally.
            middle: Align(
              key: middleBox,
              widthFactor: 1.0,
              child: const Text('Title'),
            ),
            trailing: const CupertinoButton(onPressed: null, child: Text('Puma')),
            padding: const EdgeInsetsDirectional.only(
              start: 10.0,
              end: 20.0,
              top: 3.0,
              bottom: 4.0,
            ),
          ),
        ),
      ),
    );

    expect(tester.getRect(find.byKey(middleBox)).top, 3.0);
    // 44 is the standard height of the nav bar.
    expect(
      tester.getRect(find.byKey(middleBox)).bottom,
      // 44 is the standard height of the nav bar.
      44.0 - 4.0,
    );

    expect(tester.getTopLeft(find.widgetWithText(CupertinoButton, 'Cheetah')).dx, 10.0);
    expect(tester.getTopRight(find.widgetWithText(CupertinoButton, 'Puma')).dx, 800.0 - 20.0);

    // Title is still exactly centered.
    expect(tester.getCenter(find.text('Title')).dx, 400.0);
  });

  // Assert that two SystemUiOverlayStyle instances have the same values for
  // status bar properties and that the first instance has no system navigation
  // bar properties set.
  void expectSameStatusBarStyle(SystemUiOverlayStyle style, SystemUiOverlayStyle expectedStyle) {
    expect(style.statusBarColor, expectedStyle.statusBarColor);
    expect(style.statusBarBrightness, expectedStyle.statusBarBrightness);
    expect(style.statusBarIconBrightness, expectedStyle.statusBarIconBrightness);
    expect(style.systemStatusBarContrastEnforced, expectedStyle.systemStatusBarContrastEnforced);
    expect(style.systemNavigationBarColor, isNull);
    expect(style.systemNavigationBarContrastEnforced, isNull);
    expect(style.systemNavigationBarDividerColor, isNull);
    expect(style.systemNavigationBarIconBrightness, isNull);
  }

  // Regression test for https://github.com/flutter/flutter/issues/119270
  testWidgets('System navigation bar properties are not overridden', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoNavigationBar(
          backgroundColor: Color(0xF0F9F9F9),
        ),
      ),
    );
    expectSameStatusBarStyle(SystemChrome.latestStyle!, SystemUiOverlayStyle.dark);
  });

  testWidgets('Can specify custom brightness', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoNavigationBar(
          backgroundColor: Color(0xF0F9F9F9),
          brightness: Brightness.dark,
        ),
      ),
    );
    expectSameStatusBarStyle(SystemChrome.latestStyle!, SystemUiOverlayStyle.light);

    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoNavigationBar(
          backgroundColor: Color(0xF01D1D1D),
          brightness: Brightness.light,
        ),
      ),
    );
    expectSameStatusBarStyle(SystemChrome.latestStyle!, SystemUiOverlayStyle.dark);

    await tester.pumpWidget(
      const CupertinoApp(
        home: CustomScrollView(
          slivers: <Widget>[
            CupertinoSliverNavigationBar(
              largeTitle: Text('Title'),
              backgroundColor: Color(0xF0F9F9F9),
              brightness: Brightness.dark,
            ),
          ],
        ),
      ),
    );
    expectSameStatusBarStyle(SystemChrome.latestStyle!, SystemUiOverlayStyle.light);

    await tester.pumpWidget(
      const CupertinoApp(
        home: CustomScrollView(
          slivers: <Widget>[
            CupertinoSliverNavigationBar(
              largeTitle: Text('Title'),
              backgroundColor: Color(0xF01D1D1D),
              brightness: Brightness.light,
            ),
          ],
        ),
      ),
    );
    expectSameStatusBarStyle(SystemChrome.latestStyle!, SystemUiOverlayStyle.dark);
  });

  testWidgets('Padding works in RTL', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.topCenter,
            child: CupertinoNavigationBar(
              leading: CupertinoButton(onPressed: null, child: Text('Cheetah')),
              // Let the box take all the vertical space to test vertical padding but let
              // the nav bar position it horizontally.
              middle: Text('Title'),
              trailing: CupertinoButton(onPressed: null, child: Text('Puma')),
              padding: EdgeInsetsDirectional.only(
                start: 10.0,
                end: 20.0,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopRight(find.widgetWithText(CupertinoButton, 'Cheetah')).dx, 800.0 - 10.0);
    expect(tester.getTopLeft(find.widgetWithText(CupertinoButton, 'Puma')).dx, 20.0);

    // Title is still exactly centered.
    expect(tester.getCenter(find.text('Title')).dx, 400.0);
  });

  testWidgets('Nav bar uses theme defaults', (WidgetTester tester) async {
    count = 0x000000;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoNavigationBar(
          leading: CupertinoButton(
            onPressed: () { },
            child: _ExpectStyles(color: CupertinoColors.systemBlue.color, index: 0x000001),
          ),
          middle: const _ExpectStyles(color: CupertinoColors.black, index: 0x000100),
          trailing: CupertinoButton(
            onPressed: () { },
            child: _ExpectStyles(color: CupertinoColors.systemBlue.color, index: 0x010000),
          ),
        ),
      ),
    );
    expect(count, 0x010101);
  });

  testWidgets('Nav bar respects themes', (WidgetTester tester) async {
    count = 0x000000;
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: CupertinoNavigationBar(
          leading: CupertinoButton(
            onPressed: () { },
            child: _ExpectStyles(color: CupertinoColors.systemBlue.darkColor, index: 0x000001),
          ),
          middle: const _ExpectStyles(color: CupertinoColors.white, index: 0x000100),
          trailing: CupertinoButton(
            onPressed: () { },
            child: _ExpectStyles(color: CupertinoColors.systemBlue.darkColor, index: 0x010000),
          ),
        ),
      ),
    );
    expect(count, 0x010101);
  });

  testWidgets('Theme active color can be overridden', (WidgetTester tester) async {
    count = 0x000000;
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(primaryColor: Color(0xFF001122)),
        home: CupertinoNavigationBar(
          leading: CupertinoButton(
            onPressed: () { },
            child: const _ExpectStyles(color: Color(0xFF001122), index: 0x000001),
          ),
          middle: const _ExpectStyles(color: Color(0xFF000000), index: 0x000100),
          trailing: CupertinoButton(
            onPressed: () { },
            child: const _ExpectStyles(color: Color(0xFF001122), index: 0x010000),
          ),
        ),
      ),
    );
    expect(count, 0x010101);
  });

  testWidgets('No slivers with no large titles', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text('Title'),
          ),
          child: Center(),
        ),
      ),
    );

    expect(find.byType(SliverPersistentHeader), findsNothing);
  });

  testWidgets('Media padding is applied to CupertinoSliverNavigationBar', (WidgetTester tester) async {
    final ScrollController scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final Key leadingKey = GlobalKey();
    final Key middleKey = GlobalKey();
    final Key trailingKey = GlobalKey();
    final Key titleKey = GlobalKey();
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(
              top: 10.0,
              left: 20.0,
              bottom: 30.0,
              right: 40.0,
            ),
          ),
          child: CupertinoPageScaffold(
            child: CustomScrollView(
              controller: scrollController,
              slivers: <Widget>[
                CupertinoSliverNavigationBar(
                  leading: Placeholder(key: leadingKey),
                  middle: Placeholder(key: middleKey),
                  largeTitle: Text('Large Title', key: titleKey),
                  trailing: Placeholder(key: trailingKey),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1200.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Media padding applied to leading (T,L), middle (T), trailing (T, R).
    expect(tester.getTopLeft(find.byKey(leadingKey)), const Offset(16.0 + 20.0, 10.0));
    expect(tester.getRect(find.byKey(middleKey)).top, 10.0);
    expect(tester.getTopRight(find.byKey(trailingKey)), const Offset(800.0 - 16.0 - 40.0, 10.0));

    // Top and left padding is applied to large title.
    expect(tester.getTopLeft(find.byKey(titleKey)), const Offset(16.0 + 20.0, 54.0 + 10.0));
  });

  testWidgets('Large title nav bar scrolls', (WidgetTester tester) async {
    final ScrollController scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: CustomScrollView(
            controller: scrollController,
            slivers: <Widget>[
              const CupertinoSliverNavigationBar(
                largeTitle: Text('Title'),
              ),
              SliverToBoxAdapter(
                child: Container(
                  height: 1200.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(scrollController.offset, 0.0);
    expect(tester.getTopLeft(find.byType(NavigationToolbar)).dy, 0.0);
    expect(tester.getSize(find.byType(NavigationToolbar)).height, 44.0);

    expect(find.text('Title'), findsNWidgets(2)); // Though only one is visible.

    List<Element> titles = tester.elementList(find.text('Title'))
        .toList()
        ..sort((Element a, Element b) {
          final RenderParagraph aParagraph = a.renderObject! as RenderParagraph;
          final RenderParagraph bParagraph = b.renderObject! as RenderParagraph;
          return aParagraph.text.style!.fontSize!.compareTo(bParagraph.text.style!.fontSize!);
        });

    Iterable<double> opacities = titles.map<double>((Element element) {
      final RenderAnimatedOpacity renderOpacity = element.findAncestorRenderObjectOfType<RenderAnimatedOpacity>()!;
      return renderOpacity.opacity.value;
    });

    expect(opacities, <double> [
      0.0, // Initially the smaller font title is invisible.
      1.0, // The larger font title is visible.
    ]);

    expect(tester.getTopLeft(find.widgetWithText(ClipRect, 'Title').first).dy, 44.0);
    expect(tester.getSize(find.widgetWithText(ClipRect, 'Title').first).height, 52.0);

    scrollController.jumpTo(600.0);
    await tester.pump(); // Once to trigger the opacity animation.
    await tester.pump(const Duration(milliseconds: 300));

    titles = tester.elementList(find.text('Title'))
        .toList()
        ..sort((Element a, Element b) {
          final RenderParagraph aParagraph = a.renderObject! as RenderParagraph;
          final RenderParagraph bParagraph = b.renderObject! as RenderParagraph;
          return aParagraph.text.style!.fontSize!.compareTo(bParagraph.text.style!.fontSize!);
        });

    opacities = titles.map<double>((Element element) {
      final RenderAnimatedOpacity renderOpacity = element.findAncestorRenderObjectOfType<RenderAnimatedOpacity>()!;
      return renderOpacity.opacity.value;
    });

    expect(opacities, <double> [
      1.0, // Smaller font title now visible
      0.0, // Larger font title invisible.
    ]);

    // The persistent toolbar doesn't move or change size.
    expect(tester.getTopLeft(find.byType(NavigationToolbar)).dy, 0.0);
    expect(tester.getSize(find.byType(NavigationToolbar)).height, 44.0);

    expect(tester.getTopLeft(find.widgetWithText(ClipRect, 'Title').first).dy, 44.0);
    // The OverflowBox is squished with the text in it.
    expect(tester.getSize(find.widgetWithText(ClipRect, 'Title').first).height, 0.0);
  });

  testWidgets('User specified middle is always visible in sliver', (WidgetTester tester) async {
    final ScrollController scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final Key segmentedControlsKey = UniqueKey();
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: CustomScrollView(
            controller: scrollController,
            slivers: <Widget>[
              CupertinoSliverNavigationBar(
                middle: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200.0),
                  child: CupertinoSegmentedControl<int>(
                    key: segmentedControlsKey,
                    children: const <int, Widget>{
                      0: Text('Option A'),
                      1: Text('Option B'),
                    },
                    onValueChanged: (int selected) { },
                    groupValue: 0,
                  ),
                ),
                largeTitle: const Text('Title'),
              ),
              SliverToBoxAdapter(
                child: Container(
                  height: 1200.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(scrollController.offset, 0.0);
    expect(tester.getTopLeft(find.byType(NavigationToolbar)).dy, 0.0);
    expect(tester.getSize(find.byType(NavigationToolbar)).height, 44.0);

    expect(find.text('Title'), findsOneWidget);
    expect(tester.getCenter(find.byKey(segmentedControlsKey)).dx, 400.0);

    expect(tester.getTopLeft(find.widgetWithText(ClipRect, 'Title').first).dy, 44.0);
    expect(tester.getSize(find.widgetWithText(ClipRect, 'Title').first).height, 52.0);

    scrollController.jumpTo(600.0);
    await tester.pump(); // Once to trigger the opacity animation.
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.getCenter(find.byKey(segmentedControlsKey)).dx, 400.0);
    // The large title is invisible now.
    expect(
      tester.renderObject<RenderAnimatedOpacity>(find.widgetWithText(AnimatedOpacity, 'Title')).opacity.value,
      0.0,
    );
  });

  testWidgets('User specified middle is only visible when sliver is collapsed if alwaysShowMiddle is false', (WidgetTester tester) async {
    final ScrollController scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: CustomScrollView(
            controller: scrollController,
            slivers: const <Widget>[
              CupertinoSliverNavigationBar(
                largeTitle: Text('Large'),
                middle: Text('Middle'),
                alwaysShowMiddle: false,
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 1200.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(scrollController.offset, 0.0);
    expect(find.text('Middle'), findsOneWidget);

    // Initially (in expanded state) middle widget is not visible.
    RenderAnimatedOpacity middleOpacity = tester.element(find.text('Middle')).findAncestorRenderObjectOfType<RenderAnimatedOpacity>()!;
    expect(middleOpacity.opacity.value, 0.0);

    scrollController.jumpTo(600.0);
    await tester.pumpAndSettle();

    // Middle widget is visible when nav bar is collapsed.
    middleOpacity = tester.element(find.text('Middle')).findAncestorRenderObjectOfType<RenderAnimatedOpacity>()!;
    expect(middleOpacity.opacity.value, 1.0);

    scrollController.jumpTo(0.0);
    await tester.pumpAndSettle();

    // Middle widget is not visible when nav bar is again expanded.
    middleOpacity = tester.element(find.text('Middle')).findAncestorRenderObjectOfType<RenderAnimatedOpacity>()!;
    expect(middleOpacity.opacity.value, 0.0);
  });

  testWidgets('Small title can be overridden', (WidgetTester tester) async {
    final ScrollController scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: CustomScrollView(
            controller: scrollController,
            slivers: <Widget>[
              const CupertinoSliverNavigationBar(
                middle: Text('Different title'),
                largeTitle: Text('Title'),
              ),
              SliverToBoxAdapter(
                child: Container(
                  height: 1200.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(scrollController.offset, 0.0);
    expect(tester.getTopLeft(find.byType(NavigationToolbar)).dy, 0.0);
    expect(tester.getSize(find.byType(NavigationToolbar)).height, 44.0);

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Different title'), findsOneWidget);

    RenderAnimatedOpacity largeTitleOpacity =
        tester.element(find.text('Title')).findAncestorRenderObjectOfType<RenderAnimatedOpacity>()!;
    // Large title initially visible.
    expect(
      largeTitleOpacity.opacity.value,
      1.0,
    );
    // Middle widget not even wrapped with RenderOpacity, i.e. is always visible.
    expect(
      tester.element(find.text('Different title')).findAncestorRenderObjectOfType<RenderOpacity>(),
      isNull,
    );

    expect(tester.getBottomLeft(find.text('Title')).dy, 44.0 + 52.0 - 8.0); // Static part + extension - padding.

    scrollController.jumpTo(600.0);
    await tester.pump(); // Once to trigger the opacity animation.
    await tester.pump(const Duration(milliseconds: 300));

    largeTitleOpacity =
        tester.element(find.text('Title')).findAncestorRenderObjectOfType<RenderAnimatedOpacity>()!;
    // Large title no longer visible.
    expect(
      largeTitleOpacity.opacity.value,
      0.0,
    );

    // The persistent toolbar doesn't move or change size.
    expect(tester.getTopLeft(find.byType(NavigationToolbar)).dy, 0.0);
    expect(tester.getSize(find.byType(NavigationToolbar)).height, 44.0);

    expect(tester.getBottomLeft(find.text('Title')).dy, 44.0); // Extension gone.
  });

  testWidgets('Auto back/close button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoNavigationBar(
          middle: Text('Home page'),
        ),
      ),
    );

    expect(find.byType(CupertinoButton), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator)).push(CupertinoPageRoute<void>(
      builder: (BuildContext context) {
        return const CupertinoNavigationBar(
          middle: Text('Page 2'),
        );
      },
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CupertinoButton), findsOneWidget);
    expect(find.text(String.fromCharCode(CupertinoIcons.back.codePoint)), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).push(CupertinoPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext context) {
        return const CupertinoNavigationBar(
          middle: Text('Dialog page'),
        );
      },
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.widgetWithText(CupertinoButton, 'Close'), findsOneWidget);

    // Test popping goes back correctly.
    await tester.tap(find.text('Close'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Page 2'), findsOneWidget);

    await tester.tap(find.text(String.fromCharCode(CupertinoIcons.back.codePoint)));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('Long back label turns into "back"', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Placeholder(),
      ),
    );

    tester.state<NavigatorState>(find.byType(Navigator)).push(
      CupertinoPageRoute<void>(
        builder: (BuildContext context) {
          return const CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              previousPageTitle: '012345678901',
            ),
            child: Placeholder(),
          );
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.widgetWithText(CupertinoButton, '012345678901'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).push(
      CupertinoPageRoute<void>(
        builder: (BuildContext context) {
          return const CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              previousPageTitle: '0123456789012',
            ),
            child: Placeholder(),
          );
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.widgetWithText(CupertinoButton, 'Back'), findsOneWidget);
  });

  testWidgets('Border should be displayed by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoNavigationBar(
          middle: Text('Title'),
        ),
      ),
    );

    final DecoratedBox decoratedBox = tester.widgetList(find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byType(DecoratedBox),
    )).first as DecoratedBox;
    expect(decoratedBox.decoration.runtimeType, BoxDecoration);

    final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);

    final BorderSide side = decoration.border!.bottom;
    expect(side, isNotNull);
  });

  testWidgets('Overrides border color', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoNavigationBar(
          automaticBackgroundVisibility: false,
          middle: Text('Title'),
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFAABBCC),
              width: 0.0,
            ),
          ),
        ),
      ),
    );

    final DecoratedBox decoratedBox = tester.widgetList(find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byType(DecoratedBox),
    )).first as DecoratedBox;
    expect(decoratedBox.decoration.runtimeType, BoxDecoration);

    final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);

    final BorderSide side = decoration.border!.bottom;
    expect(side, isNotNull);
    expect(side.color, const Color(0xFFAABBCC));
  });

  testWidgets('Border should not be displayed when null', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoNavigationBar(
          middle: Text('Title'),
          border: null,
        ),
      ),
    );

    final DecoratedBox decoratedBox = tester.widgetList(find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byType(DecoratedBox),
    )).first as DecoratedBox;
    expect(decoratedBox.decoration.runtimeType, BoxDecoration);

    final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.border, isNull);
  });

  testWidgets('Border is displayed by default in sliver nav bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: CustomScrollView(
            slivers: <Widget>[
              CupertinoSliverNavigationBar(
                largeTitle: Text('Large Title'),
              ),
            ],
          ),
        ),
      ),
    );

    final DecoratedBox decoratedBox = tester.widgetList(find.descendant(
      of: find.byType(CupertinoSliverNavigationBar),
      matching: find.byType(DecoratedBox),
    )).first as DecoratedBox;
    expect(decoratedBox.decoration.runtimeType, BoxDecoration);

    final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);

    final BorderSide bottom = decoration.border!.bottom;
    expect(bottom, isNotNull);
  });

  testWidgets('Border is not displayed when null in sliver nav bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: CustomScrollView(
            slivers: <Widget>[
              CupertinoSliverNavigationBar(
                largeTitle: Text('Large Title'),
                border: null,
              ),
            ],
          ),
        ),
      ),
    );

    final DecoratedBox decoratedBox = tester.widgetList(find.descendant(
      of: find.byType(CupertinoSliverNavigationBar),
      matching: find.byType(DecoratedBox),
    )).first as DecoratedBox;
    expect(decoratedBox.decoration.runtimeType, BoxDecoration);

    final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.border, isNull);
  });

  testWidgets('CupertinoSliverNavigationBar has semantics', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);

    await tester.pumpWidget(const CupertinoApp(
      home: CupertinoPageScaffold(
        child: CustomScrollView(
          slivers: <Widget>[
            CupertinoSliverNavigationBar(
              largeTitle: Text('Large Title'),
              border: null,
            ),
          ],
        ),
      ),
    ));

    expect(semantics.nodesWith(
      label: 'Large Title',
      flags: <SemanticsFlag>[SemanticsFlag.isHeader],
      textDirection: TextDirection.ltr,
    ), hasLength(1));

    semantics.dispose();
  });

  testWidgets('CupertinoNavigationBar has semantics', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);

    await tester.pumpWidget(CupertinoApp(
      home: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Fixed Title'),
        ),
        child: Container(),
      ),
    ));

    expect(semantics.nodesWith(
      label: 'Fixed Title',
      flags: <SemanticsFlag>[SemanticsFlag.isHeader],
      textDirection: TextDirection.ltr,
    ), hasLength(1));

    semantics.dispose();
  });

  testWidgets('Border can be overridden in sliver nav bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: CustomScrollView(
            slivers: <Widget>[
              CupertinoSliverNavigationBar(
                automaticBackgroundVisibility: false,
                largeTitle: Text('Large Title'),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFAABBCC),
                    width: 0.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final DecoratedBox decoratedBox = tester.widgetList(find.descendant(
      of: find.byType(CupertinoSliverNavigationBar),
      matching: find.byType(DecoratedBox),
    )).first as DecoratedBox;
    expect(decoratedBox.decoration.runtimeType, BoxDecoration);

    final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);

    final BorderSide top = decoration.border!.top;
    expect(top, isNotNull);
    expect(top, BorderSide.none);
    final BorderSide bottom = decoration.border!.bottom;
    expect(bottom, isNotNull);
    expect(bottom.color, const Color(0xFFAABBCC));
  });

  testWidgets(
    'Standard title golden',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: RepaintBoundary(
            child: CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                middle: Text('Bling bling'),
              ),
              child: Center(),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(RepaintBoundary).last,
        matchesGoldenFile('nav_bar_test.standard_title.png'),
      );
    },
  );

  testWidgets(
    'Large title golden',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: RepaintBoundary(
            child: CupertinoPageScaffold(
              child: CustomScrollView(
                slivers: <Widget>[
                  const CupertinoSliverNavigationBar(
                    largeTitle: Text('Bling bling'),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      height: 1200.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(RepaintBoundary).last,
        matchesGoldenFile('nav_bar_test.large_title.png'),
      );
    },
  );

  testWidgets(
    'Nav bar background is transparent if `automaticBackgroundVisibility` is true and has no content scrolled under it',
    (WidgetTester tester) async {
      final ScrollController scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            backgroundColor: const Color(0xFFFFFFFF),
            navigationBar: const CupertinoNavigationBar(
              backgroundColor: Color(0xFFE5E5E5),
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFAABBCC),
                  width: 0.0,
                ),
              ),
              middle: Text('Title'),
            ),
            child: ListView(
              controller: scrollController,
              children: const <Widget>[
                Placeholder(),
              ],
            ),
          ),
        ),
      );

      expect(scrollController.offset, 0.0);

      final DecoratedBox decoratedBox = tester.widgetList(find.descendant(
        of: find.byType(CupertinoNavigationBar),
        matching: find.byType(DecoratedBox),
      )).first as DecoratedBox;
      expect(decoratedBox.decoration.runtimeType, BoxDecoration);

      final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
      final BorderSide side = decoration.border!.bottom;
      expect(side.color.opacity, 0.0);

      // Appears transparent since the background color is the same as the scaffold.
      expect(find.byType(CupertinoNavigationBar), paints..rect(color: const Color(0xFFFFFFFF)));

      scrollController.jumpTo(100.0);
      await tester.pump();

      final DecoratedBox decoratedBoxAfterSroll = tester.widgetList(find.descendant(
        of: find.byType(CupertinoNavigationBar),
        matching: find.byType(DecoratedBox),
      )).first as DecoratedBox;
      expect(decoratedBoxAfterSroll.decoration.runtimeType, BoxDecoration);

      final BorderSide borderAfterScroll = (decoratedBoxAfterSroll.decoration as BoxDecoration).border!.bottom;

      expect(borderAfterScroll.color.opacity, 1.0);

      expect(find.byType(CupertinoNavigationBar), paints..rect(color: const Color(0xFFE5E5E5)));
    },
  );

  testWidgets(
    'automaticBackgroundVisibility parameter has no effect if nav bar is not a child of CupertinoPageScaffold',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoNavigationBar(
            backgroundColor: Color(0xFFE5E5E5),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFAABBCC),
                width: 0.0,
              ),
            ),
            middle: Text('Title'),
          ),
        ),
      );

      final DecoratedBox decoratedBox = tester.widgetList(find.descendant(
        of: find.byType(CupertinoNavigationBar),
        matching: find.byType(DecoratedBox),
      )).first as DecoratedBox;
      expect(decoratedBox.decoration.runtimeType, BoxDecoration);

      final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
      final BorderSide side = decoration.border!.bottom;
      expect(side.color, const Color(0xFFAABBCC));

      expect(find.byType(CupertinoNavigationBar), paints..rect(color: const Color(0xFFE5E5E5)));
    },
  );

  testWidgets(
    'Nav bar background is always visible if `automaticBackgroundVisibility` is false',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              automaticBackgroundVisibility: false,
              backgroundColor: Color(0xFFE5E5E5),
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFAABBCC),
                  width: 0.0,
                ),
              ),
              middle: Text('Title'),
            ),
            child: Placeholder(),
          ),
        ),
      );

      DecoratedBox decoratedBox = tester.widgetList(find.descendant(
        of: find.byType(CupertinoNavigationBar),
        matching: find.byType(DecoratedBox),
      )).first as DecoratedBox;
      expect(decoratedBox.decoration.runtimeType, BoxDecoration);

      BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
      BorderSide side = decoration.border!.bottom;
      expect(side.color, const Color(0xFFAABBCC));

      expect(find.byType(CupertinoNavigationBar), paints..rect(color: const Color(0xFFE5E5E5)));

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: CustomScrollView(
              slivers: <Widget>[
                const CupertinoSliverNavigationBar(
                  automaticBackgroundVisibility: false,
                  backgroundColor: Color(0xFFE5E5E5),
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFAABBCC),
                      width: 0.0,
                    ),
                  ),
                  largeTitle: Text('Title'),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1200.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      decoratedBox = tester.widgetList(find.descendant(
        of: find.byType(CupertinoSliverNavigationBar),
        matching: find.byType(DecoratedBox),
      )).first as DecoratedBox;
      expect(decoratedBox.decoration.runtimeType, BoxDecoration);

      decoration = decoratedBox.decoration as BoxDecoration;
      side = decoration.border!.bottom;
      expect(side.color, const Color(0xFFAABBCC));

      expect(find.byType(CupertinoSliverNavigationBar), paints..rect(color: const Color(0xFFE5E5E5)));
    },
  );

  testWidgets(
    'CupertinoSliverNavigationBar background is transparent if `automaticBackgroundVisibility` is true and has no content scrolled under it',
    (WidgetTester tester) async {
      final ScrollController scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            backgroundColor: const Color(0xFFFFFFFF),
            child: CustomScrollView(
              controller: scrollController,
              slivers: <Widget>[
                const CupertinoSliverNavigationBar(
                  backgroundColor: Color(0xFFE5E5E5),
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFAABBCC),
                      width: 0.0,
                    ),
                  ),
                  largeTitle: Text('Title'),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1200.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(scrollController.offset, 0.0);

      final DecoratedBox decoratedBox = tester.widgetList(find.descendant(
        of: find.byType(CupertinoSliverNavigationBar),
        matching: find.byType(DecoratedBox),
      )).first as DecoratedBox;
      expect(decoratedBox.decoration.runtimeType, BoxDecoration);

      final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
      final BorderSide side = decoration.border!.bottom;
      expect(side.color.opacity, 0.0);

      // Appears transparent since the background color is the same as the scaffold.
      expect(find.byType(CupertinoSliverNavigationBar), paints..rect(color: const Color(0xFFFFFFFF)));

      scrollController.jumpTo(400.0);
      await tester.pump();

      final DecoratedBox decoratedBoxAfterSroll = tester.widgetList(find.descendant(
        of: find.byType(CupertinoSliverNavigationBar),
        matching: find.byType(DecoratedBox),
      )).first as DecoratedBox;
      expect(decoratedBoxAfterSroll.decoration.runtimeType, BoxDecoration);

      final BorderSide borderAfterScroll = (decoratedBoxAfterSroll.decoration as BoxDecoration).border!.bottom;

      expect(borderAfterScroll.color.opacity, 1.0);

      expect(find.byType(CupertinoSliverNavigationBar), paints..rect(color: const Color(0xFFE5E5E5)));
    },
  );

  testWidgets('NavBar draws a light system bar for a dark background', (WidgetTester tester) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFFFFFFFF),
        onGenerateRoute: (RouteSettings settings) {
          return CupertinoPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) {
              return const CupertinoNavigationBar(
                middle: Text('Test'),
                backgroundColor: Color(0xFF000000),
              );
            },
          );
        },
      ),
    );
    expectSameStatusBarStyle(SystemChrome.latestStyle!, SystemUiOverlayStyle.light);
  });

  testWidgets('NavBar draws a dark system bar for a light background', (WidgetTester tester) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFFFFFFFF),
        onGenerateRoute: (RouteSettings settings) {
          return CupertinoPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) {
              return const CupertinoNavigationBar(
                middle: Text('Test'),
                backgroundColor: Color(0xFFFFFFFF),
              );
            },
          );
        },
      ),
    );
    expectSameStatusBarStyle(SystemChrome.latestStyle!, SystemUiOverlayStyle.dark);
  });

  testWidgets('CupertinoNavigationBarBackButton shows an error when manually added outside a route', (WidgetTester tester) async {
    await tester.pumpWidget(const CupertinoNavigationBarBackButton());

    final dynamic exception = tester.takeException();
    expect(exception, isAssertionError);
    expect(exception.toString(), contains('CupertinoNavigationBarBackButton should only be used in routes that can be popped'));
  });

  testWidgets('CupertinoNavigationBarBackButton shows an error when placed in a route that cannot be popped', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoNavigationBarBackButton(),
      ),
    );

    final dynamic exception = tester.takeException();
    expect(exception, isAssertionError);
    expect(exception.toString(), contains('CupertinoNavigationBarBackButton should only be used in routes that can be popped'));
  });

  testWidgets('CupertinoNavigationBarBackButton with a custom onPressed callback can be placed anywhere', (WidgetTester tester) async {
    bool backPressed = false;

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoNavigationBarBackButton(
          onPressed: () => backPressed = true,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(String.fromCharCode(CupertinoIcons.back.codePoint)), findsOneWidget);

    await tester.tap(find.byType(CupertinoNavigationBarBackButton));

    expect(backPressed, true);
  });

  testWidgets(
    'Manually inserted CupertinoNavigationBarBackButton still automatically '
        'show previous page title when possible',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Placeholder(),
        ),
      );

      tester.state<NavigatorState>(find.byType(Navigator)).push(
        CupertinoPageRoute<void>(
          title: 'An iPod',
          builder: (BuildContext context) {
            return const CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(),
              child: Placeholder(),
            );
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      tester.state<NavigatorState>(find.byType(Navigator)).push(
        CupertinoPageRoute<void>(
          title: 'A Phone',
          builder: (BuildContext context) {
            return const CupertinoNavigationBarBackButton();
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.widgetWithText(CupertinoButton, 'An iPod'), findsOneWidget);
    },
  );

  testWidgets(
    'CupertinoNavigationBarBackButton onPressed overrides default pop behavior',
    (WidgetTester tester) async {
      bool backPressed = false;
      await tester.pumpWidget(
        const CupertinoApp(
          home: Placeholder(),
        ),
      );

      tester.state<NavigatorState>(find.byType(Navigator)).push(
        CupertinoPageRoute<void>(
          title: 'An iPod',
          builder: (BuildContext context) {
            return const CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(),
              child: Placeholder(),
            );
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      tester.state<NavigatorState>(find.byType(Navigator)).push(
        CupertinoPageRoute<void>(
          title: 'A Phone',
          builder: (BuildContext context) {
            return CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                leading: CupertinoNavigationBarBackButton(
                  onPressed: () => backPressed = true,
                ),
              ),
              child: const Placeholder(),
            );
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // The second page is still on top and didn't pop.
      expect(find.text('A Phone'), findsOneWidget);
      // Custom onPressed called.
      expect(backPressed, true);
    },
  );

  testWidgets('textScaleFactor is set to 1.0', (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(builder: (BuildContext context) {
          return MediaQuery.withClampedTextScaling(
            minScaleFactor: 99,
            maxScaleFactor: 99,
            child: const CupertinoPageScaffold(
              child: CustomScrollView(
                slivers: <Widget>[
                  CupertinoSliverNavigationBar(
                    leading: Text('leading'),
                    middle: Text('middle'),
                    largeTitle: Text('Large Title'),
                    trailing: Text('trailing'),
                  ),
                  SliverToBoxAdapter(
                    child: Text('content'),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );

    final Iterable<RichText> barItems = tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(CupertinoSliverNavigationBar),
        matching: find.byType(RichText),
      ),
    );

    final Iterable<RichText> contents = tester.widgetList<RichText>(
      find.descendant(
        of: find.text('content'),
        matching: find.byType(RichText),
      ),
    );

    expect(barItems.length, greaterThan(0));
    expect(barItems, isNot(contains(predicate((RichText t) => t.textScaler != TextScaler.noScaling))));

    expect(contents.length, greaterThan(0));
    expect(contents, isNot(contains(predicate((RichText t) => t.textScaler != const TextScaler.linear(99.0)))));

    // Also works with implicitly added widgets.
    tester.state<NavigatorState>(find.byType(Navigator)).push(CupertinoPageRoute<void>(
      title: 'title',
      builder: (BuildContext context) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 99,
          maxScaleFactor: 99,
          child: const CupertinoPageScaffold(
            child: CustomScrollView(
              slivers: <Widget>[
                CupertinoSliverNavigationBar(
                  previousPageTitle: 'previous title',
                ),
              ],
            ),
          ),
        );
      },
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final Iterable<RichText> barItems2 = tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(CupertinoSliverNavigationBar),
        matching: find.byType(RichText),
      ),
    );

    expect(barItems2.length, greaterThan(0));
    expect(barItems2.any((RichText t) => t.textScaleFactor != 1), isFalse);
  });

  testWidgets(
    'CupertinoSliverNavigationBar stretches upon over-scroll and bounces back once over-scroll ends',
    (WidgetTester tester) async {
      const Text trailingText = Text('Bar Button');
      const Text titleText = Text('Large Title');

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: CustomScrollView(
              slivers: <Widget>[
                const CupertinoSliverNavigationBar(
                  trailing: trailingText,
                  largeTitle: titleText,
                  stretch: true,
                ),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1200.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final Finder trailingTextFinder = find.byWidget(trailingText).first;
      final Finder titleTextFinder = find.byWidget(titleText).first;

      final Offset initialTrailingTextToLargeTitleOffset = tester.getTopLeft(trailingTextFinder) - tester.getTopLeft(titleTextFinder);

      // Drag for overscroll
      await tester.drag(find.byType(Scrollable), const Offset(0.0, 150.0));
      await tester.pump();

      final Offset stretchedTrailingTextToLargeTitleOffset = tester.getTopLeft(trailingTextFinder) - tester.getTopLeft(titleTextFinder);

      expect(
        stretchedTrailingTextToLargeTitleOffset.dy.abs(),
        greaterThan(initialTrailingTextToLargeTitleOffset.dy.abs()),
      );

      // Ensure overscroll retracts to original size after releasing gesture
      await tester.pumpAndSettle();

      final Offset finalTrailingTextToLargeTitleOffset = tester.getTopLeft(trailingTextFinder) - tester.getTopLeft(titleTextFinder);

      expect(
        finalTrailingTextToLargeTitleOffset.dy.abs(),
        initialTrailingTextToLargeTitleOffset.dy.abs(),
      );
    },
  );

  testWidgets(
    'CupertinoSliverNavigationBar does not stretch upon over-scroll if stretch parameter is false',
    (WidgetTester tester) async {
      const Text trailingText = Text('Bar Button');
      const Text titleText = Text('Large Title');

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: CustomScrollView(
              slivers: <Widget>[
                const CupertinoSliverNavigationBar(
                  trailing: trailingText,
                  largeTitle: titleText,
                ),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1200.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final Finder trailingTextFinder = find.byWidget(trailingText).first;
      final Finder titleTextFinder = find.byWidget(titleText).first;

      final Offset initialTrailingTextToLargeTitleOffset = tester.getTopLeft(trailingTextFinder) - tester.getTopLeft(titleTextFinder);

      // Drag for overscroll
      await tester.drag(find.byType(Scrollable), const Offset(0.0, 150.0));
      await tester.pump();

      final Offset stretchedTrailingTextToLargeTitleOffset = tester.getTopLeft(trailingTextFinder) - tester.getTopLeft(titleTextFinder);

      expect(
        stretchedTrailingTextToLargeTitleOffset.dy.abs(),
        initialTrailingTextToLargeTitleOffset.dy.abs(),
      );

      // Ensure overscroll is zero after releasing gesture
      await tester.pumpAndSettle();

      final Offset finalTrailingTextToLargeTitleOffset = tester.getTopLeft(trailingTextFinder) - tester.getTopLeft(titleTextFinder);

      expect(
        finalTrailingTextToLargeTitleOffset.dy.abs(),
        initialTrailingTextToLargeTitleOffset.dy.abs(),
      );
    },
  );

  testWidgets('Null NavigationBar border transition', (WidgetTester tester) async {
    // This is a regression test for https://github.com/flutter/flutter/issues/71389
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text('Page 1'),
            border: null,
          ),
          child: Placeholder(),
        ),
      ),
    );

    tester.state<NavigatorState>(find.byType(Navigator)).push(
      CupertinoPageRoute<void>(
        builder: (BuildContext context) {
          return const CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text('Page 2'),
              border: null,
            ),
            child: Placeholder(),
          );
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Page 1'), findsNothing);
    expect(find.text('Page 2'), findsOneWidget);

    await tester.tap(find.text(String.fromCharCode(CupertinoIcons.back.codePoint)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Page 2'), findsNothing);
  });

  testWidgets(
    'CupertinoSliverNavigationBar magnifies upon over-scroll and shrinks back once over-scroll ends',
    (WidgetTester tester) async {
      const Text titleText = Text('Large Title');

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: CustomScrollView(
              slivers: <Widget>[
                const CupertinoSliverNavigationBar(
                  largeTitle: titleText,
                  stretch: true,
                ),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1200.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final Finder titleTextFinder = find.byWidget(titleText).first;

      // Gets the height of the large title
      final Offset initialLargeTitleTextOffset =
          tester.getBottomLeft(titleTextFinder) -
              tester.getTopLeft(titleTextFinder);

      // Drag for overscroll
      await tester.drag(find.byType(Scrollable), const Offset(0.0, 150.0));
      await tester.pump();

      final Offset magnifiedTitleTextOffset =
          tester.getBottomLeft(titleTextFinder) -
              tester.getTopLeft(titleTextFinder);

      expect(
        magnifiedTitleTextOffset.dy.abs(),
        greaterThan(initialLargeTitleTextOffset.dy.abs()),
      );

      // Ensure title text retracts to original size after releasing gesture
      await tester.pumpAndSettle();

      final Offset finalTitleTextOffset = tester.getBottomLeft(titleTextFinder) -
          tester.getTopLeft(titleTextFinder);

      expect(
        finalTitleTextOffset.dy.abs(),
        initialLargeTitleTextOffset.dy.abs(),
      );
    },
  );

  testWidgets(
    'CupertinoSliverNavigationBar large title text does not get clipped when magnified',
    (WidgetTester tester) async {
      const Text titleText = Text('Very very very long large title');

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: CustomScrollView(
              slivers: <Widget>[
                const CupertinoSliverNavigationBar(
                  largeTitle: titleText,
                  stretch: true,
                ),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1200.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final Finder titleTextFinder = find.byWidget(titleText).first;

      // Gets the width of the large title
      final Offset initialLargeTitleTextOffset =
          tester.getBottomLeft(titleTextFinder) -
              tester.getBottomRight(titleTextFinder);

      // Drag for overscroll
      await tester.drag(find.byType(Scrollable), const Offset(0.0, 150.0));
      await tester.pump();

      final Offset magnifiedTitleTextOffset =
          tester.getBottomLeft(titleTextFinder) -
              tester.getBottomRight(titleTextFinder);

      expect(
        magnifiedTitleTextOffset.dx.abs(),
        equals(initialLargeTitleTextOffset.dx.abs()),
      );
    },
  );

  testWidgets(
    'CupertinoSliverNavigationBar large title can be hit tested when magnified',
    (WidgetTester tester) async {
      final ScrollController scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: CustomScrollView(
              controller: scrollController,
              slivers: <Widget>[
                const CupertinoSliverNavigationBar(
                  largeTitle: Text('Large title'),
                  stretch: true,
                ),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1200.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final Finder largeTitleFinder = find.text('Large title').first;

      // Drag for overscroll
      await tester.drag(find.byType(Scrollable), const Offset(0.0, 250.0));

      // Hold position of the scroll view, so the Scrollable unblocks the hit-testing
      scrollController.position.hold(() {});
      await tester.pumpAndSettle();

      expect(largeTitleFinder.hitTestable(), findsOneWidget);
    },
  );
}

class _ExpectStyles extends StatelessWidget {
  const _ExpectStyles({
    required this.color,
    required this.index,
  });

  final Color color;
  final int index;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = DefaultTextStyle.of(context).style;
    expect(style.color, isSameColorAs(color));
    expect(style.fontFamily, 'CupertinoSystemText');
    expect(style.fontSize, 17.0);
    expect(style.letterSpacing, -0.41);
    count += index;
    return Container();
  }
}
