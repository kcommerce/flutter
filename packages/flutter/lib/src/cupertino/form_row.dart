// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'theme.dart';

// Prefix widget padding determined via SwiftUI's `Form` view in iOS 14.2 SDK.
const EdgeInsetsGeometry _kDefaultMargins =
    EdgeInsetsDirectional.fromSTEB(16.0, 6.0, 6.0, 6.0);

/// An iOS-style form row.
///
/// Creates an iOS-style split form row with a standard prefix and child widget.
/// Also provides a space for error and helper widgets that appear underneath.
///
/// The [child] parameter is required. This widget is displayed at the end of
/// the row.
///
/// The [prefix] parameter is optional and is displayed at the start of the
/// row. Standard iOS guidelines encourage passing a [Text] widget to [prefix]
/// to detail the nature of the row's [child] widget.
///
/// The [margins] parameter is used to pad the contents of the row. It defaults
/// to the standard iOS padding. If no edge insets are intended, explicitly pass
/// [EdgeInsets.zero] to [margins].
///
/// The [helper] and [error] parameters are both optional widgets targeted at
/// displaying more information about the row. Both widgets are placed
/// underneath the [prefix] and [child], and will expand the row's height to
/// accomodate for their presence. When a [Text] is given to [error], it will
/// be shown in [CupertinoColors.destructiveRed] coloring and
/// medium-weighted font.
///
/// {@tool snippet}
///
/// Creates a [CupertinoFormSection] containing a [CupertinoFormRow] with the
/// [prefix], [child], [helper] and [error] widgets.
///
/// ```dart
/// class FlutterDemo extends StatefulWidget {
///   FlutterDemo({Key key}) : super(key: key);
///
///   @override
///   _FlutterDemoState createState() => _FlutterDemoState();
/// }
///
/// class _FlutterDemoState extends State<FlutterDemo> {
///   bool toggleValue = false;
///
///   @override
///   Widget build(BuildContext context) {
///     return CupertinoPageScaffold(
///       child: Center(
///         child: CupertinoFormSection(
///           title: "Section 1",
///           children: [
///             CupertinoFormRow(
///               prefix: Text('Toggle'),
///               helper: Text('Use your instincts'),
///               error: toggleValue ? Text('Can't be true') : null,
///               child: CupertinoSwitch(
///                 value: this.toggleValue,
///                 onChanged: (value) {
///                   setState(() {
///                     this.toggleValue = value;
///                   });
///                 },
///               ),
///             ),
///           ],
///         ),
///       ),
///     );
///   }
/// }
/// ```
/// {@end-tool}
class CupertinoFormRow extends StatelessWidget {
  /// Creates an iOS-style split form row with a standard prefix and child widget.
  /// Also provides a space for error and helper widgets that appear underneath.
  ///
  /// The [child] parameter is required. This widget is displayed at the end of
  /// the row.
  ///
  /// The [prefix] parameter is optional and is displayed at the start of the
  /// row. Standard iOS guidelines encourage passing a [Text] widget to [prefix]
  /// to detail the nature of the row's [child] widget.
  ///
  /// The [margins] parameter is used to pad the contents of the row. It defaults
  /// to the standard iOS padding. If no edge insets are intended, explicitly
  /// pass [EdgeInsets.zero] to [margins].
  ///
  /// The [helper] and [error] parameters are both optional widgets targeted at
  /// displaying more information about the row. Both widgets are placed
  /// underneath the [prefix] and [child], and will expand the row's height to
  /// accomodate for their presence. When a [Text] is given to [error], it will
  /// be shown in [CupertinoColors.destructiveRed] coloring and
  /// medium-weighted font.
  const CupertinoFormRow({
    Key? key,
    required this.child,
    this.prefix,
    this.margins,
    this.helper,
    this.error,
  }) : super(key: key);

  /// A widget that is displayed at the start of the row.
  ///
  /// The [prefix] parameter is displayed at the start of the row. Standard iOS
  /// guidelines encourage passing a [Text] widget to [prefix] to detail the
  /// nature of the row's [child] widget. If null, the [child] widget will take
  /// up all horizontal space in the row.
  final Widget? prefix;

  /// Margins used to pad the contents of the row.
  ///
  /// Defaults to the standard iOS padding for form rows. If no edge insets are
  /// intended, explicitly pass [EdgeInsets.zero] to [margins].
  final EdgeInsetsGeometry? margins;

  /// A widget that is displayed underneath the [prefix] and [child] widgets.
  ///
  /// The [helper] appears in primary label coloring, and is meant to inform the
  /// user about interaction with the child widget. The row becomes taller in
  /// order to display the [helper] widget underneath [prefix] and [child]. If
  /// null, the row is shorter.
  final Widget? helper;

  /// A widget that is displayed underneath the [prefix] and [child] widgets.
  ///
  /// The [error] widget is primarily used to inform users of input errors. When
  /// a [Text] is given to [error], it will be shown in
  /// [CupertinoColors.destructiveRed] coloring and medium-weighted font. The
  /// row becomes taller in order to display the [helper] widget underneath
  /// [prefix] and [child]. If null, the row is shorter.
  final Widget? error;

  /// Child widget.
  ///
  /// The [child] widget is primarily used for input. It end-aligned and
  /// horizontally flexible, taking up the entire space trailing past the
  /// [prefix] widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final CupertinoThemeData themeData = CupertinoTheme.of(context);
    final TextStyle textStyle = themeData.textTheme.textStyle;

    final List<Widget> rowChildren = <Widget>[
      if (prefix != null)
        DefaultTextStyle(
          style: textStyle,
          child: prefix!,
        ),
      Flexible(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: child,
        ),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
      ),
      child: Padding(
        padding: margins ?? _kDefaultMargins,
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: rowChildren,
            ),
            if (helper != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DefaultTextStyle(
                  style: textStyle,
                  child: helper!,
                ),
              ),
            if (error != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: CupertinoColors.destructiveRed,
                    fontWeight: FontWeight.w500,
                  ),
                  child: error!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
