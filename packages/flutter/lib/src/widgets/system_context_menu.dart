// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/material.dart';
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'editable_text.dart';
import 'framework.dart';
import 'localizations.dart';
import 'media_query.dart';
import 'text_selection_toolbar_anchors.dart';

/// Displays the system context menu on top of the Flutter view.
///
/// Currently, only supports iOS 16.0 and above and displays nothing on other
/// platforms.
///
/// The context menu is the menu that appears, for example, when doing text
/// selection. Flutter typically draws this menu itself, but this class deals
/// with the platform-rendered context menu instead.
///
/// There can only be one system context menu visible at a time. Building this
/// widget when the system context menu is already visible will hide the old one
/// and display this one. A system context menu that is hidden is informed via
/// [onSystemHide].
///
/// To check if the current device supports showing the system context menu,
/// call [isSupported].
///
/// {@tool dartpad}
/// This example shows how to create a [TextField] that uses the system context
/// menu where supported and does not show a system notification when the user
/// presses the "Paste" button.
///
/// ** See code in examples/api/lib/widgets/system_context_menu/system_context_menu.0.dart **
/// {@end-tool}
///
/// See also:
///
///  * [SystemContextMenuController], which directly controls the hiding and
///    showing of the system context menu.
class SystemContextMenu extends StatefulWidget {
  /// Creates an instance of [SystemContextMenu] that points to the given
  /// [anchor].
  const SystemContextMenu._({
    super.key,
    required this.anchor,
    this.items,
    this.onSystemHide,
  });

  /// Creates an instance of [SystemContextMenu] for the field indicated by the
  /// given [EditableTextState].
  factory SystemContextMenu.editableText({
    Key? key,
    required EditableTextState editableTextState,
    List<SystemContextMenuItem>? items,
  }) {
    final (
      startGlyphHeight: double startGlyphHeight,
      endGlyphHeight: double endGlyphHeight,
    ) = editableTextState.getGlyphHeights();
    return SystemContextMenu._(
      key: key,
      anchor: TextSelectionToolbarAnchors.getSelectionRect(
        editableTextState.renderEditable,
        startGlyphHeight,
        endGlyphHeight,
        editableTextState.renderEditable.getEndpointsForSelection(
          editableTextState.textEditingValue.selection,
        ),
      ),
      items: items,
      onSystemHide: () {
        editableTextState.hideToolbar();
      },
    );
  }

  /// The [Rect] that the context menu should point to.
  final Rect anchor;

  /// A list of the items to be displayed in the system context menu.
  final List<SystemContextMenuItem>? items;

  /// Called when the system hides this context menu.
  ///
  /// For example, tapping outside of the context menu typically causes the
  /// system to hide the menu.
  ///
  /// This is not called when showing a new system context menu causes another
  /// to be hidden.
  final VoidCallback? onSystemHide;

  /// Whether the current device supports showing the system context menu.
  ///
  /// Currently, this is only supported on newer versions of iOS.
  static bool isSupported(BuildContext context) {
    return MediaQuery.maybeSupportsShowingSystemContextMenu(context) ?? false;
  }

  @override
  State<SystemContextMenu> createState() => _SystemContextMenuState();
}

class _SystemContextMenuState extends State<SystemContextMenu> {
  bool isFirstBuild = true;
  late final SystemContextMenuController _systemContextMenuController;

  /// Return the SystemContextMenuItemData for the given SystemContextMenuItem.
  ///
  /// SystemContextMenuItem is a format that is designed to be consumed as
  /// SystemContextMenu.items, where users might want a default localized title
  /// to be set for them.
  ///
  /// SystemContextMenuItemData is a format that is meant to be consumed by
  /// SystemContextMenuController.show, where there is no expectation that
  /// localizations can be used under the hood.
  SystemContextMenuItemData _itemToData(SystemContextMenuItem item, WidgetsLocalizations localizations) {
    return switch (item) {
      SystemContextMenuItemCut() => const SystemContextMenuItemDataCut(),
      SystemContextMenuItemCopy() => const SystemContextMenuItemDataCopy(),
      SystemContextMenuItemPaste() => const SystemContextMenuItemDataPaste(),
      SystemContextMenuItemSelectAll() => const SystemContextMenuItemDataSelectAll(),
      SystemContextMenuItemLookUp() => SystemContextMenuItemDataLookUp(
        title: item.title ?? localizations.lookUpButtonLabel,
      ),
      SystemContextMenuItemShare() => SystemContextMenuItemDataShare(
        title: item.title ?? localizations.shareButtonLabel,
      ),
      SystemContextMenuItemSearchWeb() => SystemContextMenuItemDataSearchWeb(
        title: item.title ?? localizations.searchWebButtonLabel,
      ),
      SystemContextMenuItemCustom() => SystemContextMenuItemDataCustom(
        title: item.title!,
        onPressed: item.onPressed!,
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    _systemContextMenuController = SystemContextMenuController(
      onSystemHide: widget.onSystemHide,
    );
  }

  @override
  void didUpdateWidget(SystemContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // TODO(justinmc): Or if items changed.
    if (widget.anchor != oldWidget.anchor) {
      // TODO(justinmc): Deduplicate with the `show` call in the first build below.
      final WidgetsLocalizations localizations = WidgetsLocalizations.of(context);
      final Iterable<SystemContextMenuItemData>? datas =
        widget.items?.map((SystemContextMenuItem item) => _itemToData(item, localizations));
      _systemContextMenuController.show(
        widget.anchor,
        // TODO(justinmc): Don't show irrelevant items, like don't show "search" if there is no selection.
        datas?.toList(),
      );
    }
  }

  @override
  void dispose() {
    _systemContextMenuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(SystemContextMenu.isSupported(context));
    if (isFirstBuild) {
      isFirstBuild = false;
      final WidgetsLocalizations localizations = WidgetsLocalizations.of(context);
      final Iterable<SystemContextMenuItemData>? datas =
        widget.items?.map((SystemContextMenuItem item) => _itemToData(item, localizations));
      _systemContextMenuController.show(
        widget.anchor,
        datas?.toList(),
      );
    }

    return const SizedBox.shrink();
  }
}

// TODO(justinmc): Still need to decide to name this as ios specific or not.
// Probably should make it ios-specific, because these classes encode
// ios-specific logic, such as the fact that you can't change the title of the
// paste button, etc.
/// Describes a context menu button that will be rendered in the system context
/// menu and not by Flutter itself.
///
/// See also:
///
///  * [SystemContextMenuItemData], which performs a similar role but at the
///    method channel level and mirrors the requirements of the method channel
///    API.
///  * [ContextMenuButtonItem], which performs a similar role for Flutter-drawn
///    context menus.
sealed class SystemContextMenuItem {
  const SystemContextMenuItem();

  /// The text to display to the user.
  ///
  /// Not exposed for some built-in menu items whose title is always set by the
  /// platform.
  String? get title => null;

  /// The callback to be called when the menu item is pressed.
  ///
  /// Not exposed for built-in menu items, which handle their own action when
  /// pressed.
  VoidCallback? get onPressed => null;
}

/// Creates an instance of [SystemContextMenuItem] for the system's built-in cut
/// button.
///
/// Should only appear when there is a selection that can be cut.
class SystemContextMenuItemCut extends SystemContextMenuItem {
  /// Creates an instance of [SystemContextMenuItemCut].
  const SystemContextMenuItemCut();
}

/// Creates an instance of [SystemContextMenuItem] for the system's built-in
/// copy button.
///
/// Should only appear when there is a selection that can be copied.
class SystemContextMenuItemCopy extends SystemContextMenuItem {
  /// Creates an instance of [SystemContextMenuItemCopy].
  const SystemContextMenuItemCopy();
}

/// Creates an instance of [SystemContextMenuItem] for the system's built-in
/// paste button.
///
/// Should only appear when the field can receive pasted content.
class SystemContextMenuItemPaste extends SystemContextMenuItem {
  /// Creates an instance of [SystemContextMenuItemPaste].
  const SystemContextMenuItemPaste();
}

/// Creates an instance of [SystemContextMenuItem] for the system's built-in
/// select all button.
///
/// Should only appear when the field can have its selection changed.
class SystemContextMenuItemSelectAll extends SystemContextMenuItem {
  /// Creates an instance of [SystemContextMenuItemSelectAll].
  const SystemContextMenuItemSelectAll();
}

/// Creates an instance of [SystemContextMenuItem] for the
/// system's built-in search web button.
///
/// Should only appear when content is selected.
class SystemContextMenuItemSearchWeb extends SystemContextMenuItem {
  /// Creates an instance of [SystemContextMenuItemSearchWeb].
  const SystemContextMenuItemSearchWeb({
    this.title,
  });

  @override
  final String? title;
}

/// Creates an instance of [SystemContextMenuItem] for the
/// system's built-in look up button.
///
/// Should only appear when content is selected.
class SystemContextMenuItemLookUp extends SystemContextMenuItem {
  /// Creates an instance of [SystemContextMenuItemLookUp].
  const SystemContextMenuItemLookUp({
    this.title,
  });

  @override
  final String? title;
}

/// Creates an instance of [SystemContextMenuItem] for the
/// system's built-in share button.
///
/// Opens the system share dialog.
///
/// Should only appear when shareable content is selected.
class SystemContextMenuItemShare extends SystemContextMenuItem {
  /// Creates an instance of [SystemContextMenuItemShare].
  ///
  /// If no [title] is given, [WidgetsLocalizations.shareButtonLabel] should be
  /// used.
  const SystemContextMenuItemShare({
    this.title,
  });

  @override
  final String? title;
}

// TODO(justinmc): Support the "custom" type.
// https://github.com/flutter/flutter/issues/103163
/// Creates an instance of [SystemContextMenuItem] for a custom menu item whose
/// [title] and [onPressed] are as specified.
class SystemContextMenuItemCustom extends SystemContextMenuItem {
  /// Creates an instance of [SystemContextMenuItemCustom].
  const SystemContextMenuItemCustom({
    required String this.title,
    required VoidCallback this.onPressed,
  });

  @override
  final String? title;

  @override
  final VoidCallback? onPressed;
}
