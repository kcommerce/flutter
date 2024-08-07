import 'package:a11y_assessments/use_cases/navigation_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  testWidgets('navigation drawer can run', (WidgetTester tester) async {
    await pumpsUseCase(tester, NavigationDrawerUseCase());

    final ScaffoldState state = tester.firstState(find.byType(Scaffold));
    state.openEndDrawer();

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NavigationDrawer), findsExactly(1));
  });
}
