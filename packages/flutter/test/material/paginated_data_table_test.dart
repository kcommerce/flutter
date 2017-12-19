// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_table_test_utils.dart';

class TestDataSource extends DataTableSource {
  int get generation => _generation;
  int _generation = 0;
  set generation(int value) {
    if (_generation == value)
      return;
    _generation = value;
    notifyListeners();
  }

  @override
  DataRow getRow(int index) {
    final Dessert dessert = kDesserts[index % kDesserts.length];
    final int page = index ~/ kDesserts.length;
    return new DataRow.byIndex(
      index: index,
      cells: <DataCell>[
        new DataCell(new Text('${dessert.name} ($page)')),
        new DataCell(new Text('${dessert.calories}')),
        new DataCell(new Text('$generation')),
      ],
    );
  }

  @override
  int get rowCount => 50 * kDesserts.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

void main() {
  testWidgets('PaginatedDataTable paging', (WidgetTester tester) async {
    final TestDataSource source = new TestDataSource();

    final List<String> log = <String>[];

    await tester.pumpWidget(new MaterialApp(
      home: new PaginatedDataTable(
        header: const Text('Test table'),
        source: source,
        rowsPerPage: 2,
        availableRowsPerPage: <int>[
          2, 4, 8, 16,
        ],
        onRowsPerPageChanged: (int rowsPerPage) {
          log.add('rows-per-page-changed: $rowsPerPage');
        },
        onPageChanged: (int rowIndex) {
          log.add('page-changed: $rowIndex');
        },
        columns: <DataColumn>[
          const DataColumn(label: const Text('Name')),
          const DataColumn(label: const Text('Calories'), numeric: true),
          const DataColumn(label: const Text('Generation')),
        ],
      )
    ));

    await tester.tap(find.byTooltip('Next page'));

    expect(log, <String>['page-changed: 2']);
    log.clear();

    await tester.pump();

    expect(find.text('Frozen yogurt (0)'), findsNothing);
    expect(find.text('Eclair (0)'), findsOneWidget);
    expect(find.text('Gingerbread (0)'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));

    expect(log, <String>['page-changed: 0']);
    log.clear();

    await tester.pump();

    expect(find.text('Frozen yogurt (0)'), findsOneWidget);
    expect(find.text('Eclair (0)'), findsNothing);
    expect(find.text('Gingerbread (0)'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));

    expect(log, isEmpty);

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    await tester.tap(find.text('8').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(log, <String>['rows-per-page-changed: 8']);
    log.clear();
  });

  testWidgets('PaginatedDataTable control test', (WidgetTester tester) async {
    TestDataSource source = new TestDataSource()
      ..generation = 42;

    final List<String> log = <String>[];

    Widget buildTable(TestDataSource source) {
      return new PaginatedDataTable(
        header: const Text('Test table'),
        source: source,
        onPageChanged: (int rowIndex) {
          log.add('page-changed: $rowIndex');
        },
        columns: <DataColumn>[
          const DataColumn(
            label: const Text('Name'),
            tooltip: 'Name',
          ),
          new DataColumn(
            label: const Text('Calories'),
            tooltip: 'Calories',
            numeric: true,
            onSort: (int columnIndex, bool ascending) {
              log.add('column-sort: $columnIndex $ascending');
            }
          ),
          const DataColumn(
            label: const Text('Generation'),
            tooltip: 'Generation',
          ),
        ],
        actions: <Widget>[
          new IconButton(
            icon: const Icon(Icons.adjust),
            onPressed: () {
              log.add('action: adjust');
            },
          ),
        ],
      );
    }

    await tester.pumpWidget(new MaterialApp(
      home: buildTable(source),
    ));

    // the column overflows because we're forcing it to 600 pixels high
    expect(tester.takeException(), contains('A RenderFlex overflowed by'));

    expect(find.text('Gingerbread (0)'), findsOneWidget);
    expect(find.text('Gingerbread (1)'), findsNothing);
    expect(find.text('42'), findsNWidgets(10));

    source.generation = 43;
    await tester.pump();

    expect(find.text('42'), findsNothing);
    expect(find.text('43'), findsNWidgets(10));

    source = new TestDataSource()
      ..generation = 15;

    await tester.pumpWidget(new MaterialApp(
      home: buildTable(source),
    ));

    expect(find.text('42'), findsNothing);
    expect(find.text('43'), findsNothing);
    expect(find.text('15'), findsNWidgets(10));

    final PaginatedDataTableState state = tester.state(find.byType(PaginatedDataTable));

    expect(log, isEmpty);
    state.pageTo(23);
    expect(log, <String>['page-changed: 20']);
    log.clear();

    await tester.pump();

    expect(find.text('Gingerbread (0)'), findsNothing);
    expect(find.text('Gingerbread (1)'), findsNothing);
    expect(find.text('Gingerbread (2)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.adjust));
    expect(log, <String>['action: adjust']);
    log.clear();
  });

  testWidgets('PaginatedDataTable text alignment', (WidgetTester tester) async {
    await tester.pumpWidget(new MaterialApp(
      home: new PaginatedDataTable(
        header: const Text('HEADER'),
        source: new TestDataSource(),
        rowsPerPage: 8,
        availableRowsPerPage: <int>[
          8, 9,
        ],
        onRowsPerPageChanged: (int rowsPerPage) { },
        columns: <DataColumn>[
          const DataColumn(label: const Text('COL1')),
          const DataColumn(label: const Text('COL2')),
          const DataColumn(label: const Text('COL3')),
        ],
      ),
    ));
    expect(find.text('Rows per page:'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(tester.getTopRight(find.text('8')).dx, tester.getTopRight(find.text('Rows per page:')).dx + 40.0); // per spec
  });

  testWidgets('PaginatedDataTable with large text', (WidgetTester tester) async {
    final TestDataSource source = new TestDataSource();
    await tester.pumpWidget(new MaterialApp(
      home: new MediaQuery(
        data: const MediaQueryData(
          textScaleFactor: 20.0,
        ),
        child: new PaginatedDataTable(
          header: const Text('HEADER'),
          source: source,
          rowsPerPage: 501,
          availableRowsPerPage: <int>[ 501 ],
          onRowsPerPageChanged: (int rowsPerPage) { },
          columns: <DataColumn>[
            const DataColumn(label: const Text('COL1')),
            const DataColumn(label: const Text('COL2')),
            const DataColumn(label: const Text('COL3')),
          ],
        ),
      ),
    ));
    // the column overflows because we're forcing it to 600 pixels high
    expect(tester.takeException(), contains('A RenderFlex overflowed by'));
    expect(find.text('Rows per page:'), findsOneWidget);
    // Test that we will show some options in the drop down even if the lowest option is bigger than the source:
    assert(501 > source.rowCount);
    expect(find.text('501'), findsOneWidget);
    // Test that it fits:
    expect(tester.getTopRight(find.text('501')).dx, greaterThanOrEqualTo(tester.getTopRight(find.text('Rows per page:')).dx + 40.0));
  });

  testWidgets('PaginatedDataTable footer scrolls', (WidgetTester tester) async {
    final TestDataSource source = new TestDataSource();
    await tester.pumpWidget(new MaterialApp(
      home: new Align(
        alignment: Alignment.topLeft,
        child: new SizedBox(
          width: 100.0,
          child: new PaginatedDataTable(
            header: const Text('HEADER'),
            source: source,
            rowsPerPage: 5,
            availableRowsPerPage: <int>[ 5 ],
            onRowsPerPageChanged: (int rowsPerPage) { },
            columns: <DataColumn>[
              const DataColumn(label: const Text('COL1')),
              const DataColumn(label: const Text('COL2')),
              const DataColumn(label: const Text('COL3')),
            ],
          ),
        ),
      ),
    ));
    expect(find.text('Rows per page:'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Rows per page:')).dx, lessThan(0.0)); // off screen
    await tester.dragFrom(
      new Offset(50.0, tester.getTopLeft(find.text('Rows per page:')).dy),
      const Offset(1000.0, 0.0),
    );
    await tester.pump();
    expect(find.text('Rows per page:'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Rows per page:')).dx, 18.0); // 14 padding in the footer row, 4 padding from the card
  });
}
