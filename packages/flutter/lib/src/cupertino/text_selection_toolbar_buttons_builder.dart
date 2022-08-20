// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'desktop_text_selection_toolbar_button.dart';
import 'localizations.dart';
import 'text_selection_toolbar_button.dart';

/// A Function that builds a context menu given a List of `children` Widgets.
///
/// See also:
///
///   * [CupertinoTextSelectionToolbarButtonsBuilder], which receives an
///     instance of this as a parameter.
typedef ContextMenuFromChildrenBuilder = Widget Function(
  BuildContext context,
  List<Widget> children,
);

/// Calls [builder] with a List of Widgets generated by turning [buttonItems]
/// into the default Cupertino buttons for the platform.
///
/// Does not build Material buttons. On non-Apple platforms, Cupertino buttons
/// will still be used, because the Cupertino library does not access the
/// Material library. To build the the native-looking buttons on every platform,
/// use [TextSelectionToolbarButtonsBuilder] in the Material library.
///
/// See also:
///
/// * [AdaptiveTextSelectionToolbar], which builds the toolbar itself. By
///   wrapping [TextSelectionToolbarButtonsBuilder] with
///   [AdaptiveTextSelectionToolbar] and passing the given children to
///   [AdaptiveTextSelectionToolbar.children], a default toolbar can be built
///   with custom button actions and labels.
/// * [TextSelectionToolbarButtonsBuilder], which is in the Material library and
///   builds native-looking buttons for all platforms.
/// * [EditableTextContextMenuButtonItemsBuilder], which is similar to this class,
///   but calls its builder with [ContextMenuButtonItem]s instead of with fully
///   built children Widgets.
class CupertinoTextSelectionToolbarButtonsBuilder extends StatelessWidget {
  /// Creates an instance of [CupertinoTextSelectionToolbarButtonsBuilder].
  const CupertinoTextSelectionToolbarButtonsBuilder({
    super.key,
    required this.buttonItems,
    required this.builder,
  });

  /// The information used to create each button Widget.
  final List<ContextMenuButtonItem> buttonItems;

  /// Called with a List of Widgets created from the given [buttonItems].
  ///
  /// Typically builds a text selection toolbar with the Widgets it is given as
  /// children.
  final ContextMenuFromChildrenBuilder builder;

  /// Returns the default button label String for the button of the given
  /// [ContextMenuButtonItem]'s [ContextMenuButtonType].
  static String getButtonLabel(BuildContext context, ContextMenuButtonItem buttonItem) {
    if (buttonItem.label != null) {
      return buttonItem.label!;
    }

    assert(debugCheckHasCupertinoLocalizations(context));
    final CupertinoLocalizations localizations = CupertinoLocalizations.of(context);
    switch (buttonItem.type) {
      case ContextMenuButtonType.cut:
        return localizations.cutButtonLabel;
      case ContextMenuButtonType.copy:
        return localizations.copyButtonLabel;
      case ContextMenuButtonType.paste:
        return localizations.pasteButtonLabel;
      case ContextMenuButtonType.selectAll:
        return localizations.selectAllButtonLabel;
      case ContextMenuButtonType.custom:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return builder(
          context,
          buttonItems.map((ContextMenuButtonItem buttonItem) {
            return CupertinoTextSelectionToolbarButton.text(
              onPressed: buttonItem.onPressed,
              text: getButtonLabel(context, buttonItem),
            );
          }).toList(),
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        return builder(
          context,
          buttonItems.map((ContextMenuButtonItem buttonItem) {
            return CupertinoDesktopTextSelectionToolbarButton.text(
              context: context,
              onPressed: buttonItem.onPressed,
              text: getButtonLabel(context, buttonItem),
            );
          }).toList(),
        );
    }
  }
}
