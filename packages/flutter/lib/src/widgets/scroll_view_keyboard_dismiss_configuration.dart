// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/material.dart';
///
/// @docImport 'list_wheel_scroll_view.dart';
/// @docImport 'page_view.dart';
/// @docImport 'scroll_position.dart';
/// @docImport 'scroll_view.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'framework.dart';
import 'scroll_view.dart';

/// Controls how [Scrollable] will dismiss the keyboard automatically.
///
/// The scroll view keyboard dismiss configuration determines the
/// [ScrollViewKeyboardDismissBehavior] used by descendants of [child].
class ScrollViewKeyboardDismissConfiguration extends InheritedWidget {
  /// Creates a widget that controls how [Scrollable] widgets behave in a subtree.
  const ScrollViewKeyboardDismissConfiguration({
    super.key,
    required this.behavior,
    required super.child,
  });

  /// How [Scrollable] widgets that are descendants of [child] should behave.
  final ScrollViewKeyboardDismissBehavior behavior;

  /// The [ScrollViewKeyboardDismissConfiguration] for [Scrollable] widgets in the given [BuildContext].
  ///
  /// If no [ScrollConfiguration] widget is in scope of the given `context`,
  /// a default [ScrollBehavior] instance is returned.
  static ScrollViewKeyboardDismissBehavior? of(BuildContext context) {
    final ScrollViewKeyboardDismissConfiguration? configuration =
        context.dependOnInheritedWidgetOfExactType<
            ScrollViewKeyboardDismissConfiguration>();
    return configuration?.behavior;
  }

  @override
  bool updateShouldNotify(ScrollViewKeyboardDismissConfiguration oldWidget) {
    return behavior.runtimeType != oldWidget.behavior.runtimeType ||
        (behavior != oldWidget.behavior);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ScrollViewKeyboardDismissBehavior>(
        'behavior', behavior));
  }
}
