// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Flutter code sample for a [RawMenuAnchor.overlayBuilder] that demonstrates
/// how to create a custom, animated menu overlay.
void main() => runApp(const MenuOverlayBuilderApp());

class MenuItem {
  const MenuItem(this.label, {this.leading});
  final String label;
  final Widget? leading;
}

const List<MenuItem> menuItems = <MenuItem>[
  MenuItem('Cat'        , leading: Text('🦁')),
  MenuItem('Kitten'     , leading: Text('🐱')),
  MenuItem('Felis catus', leading: Text('🐈')),
  MenuItem('Dog'        , leading: Text('🐕')),
];

class MenuOverlayBuilderExample extends StatefulWidget {
  const MenuOverlayBuilderExample({super.key});

  static const double menuItemExtent = 44.0;

  @override
  State<MenuOverlayBuilderExample> createState() => _MenuOverlayBuilderExampleState();
}

class _MenuOverlayBuilderExampleState extends State<MenuOverlayBuilderExample> {

  final MenuController controller = MenuController();
  int? _selected;

  void _handlePressed(int index) {
    setState(() {
      _selected = index;
    });
    controller.close();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Favorite Animal:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 8),
          RawMenuAnchor.overlayBuilder(
            controller: controller,
            overlayBuilder: (
              BuildContext context,
              List<Widget> menuChildren,
              RawMenuAnchorOverlayPosition position,
            ) {
              return ItemAwareMenuSurface(
                selectedIndex: _selected ?? 0,
                position: position,
                itemExtent: MenuOverlayBuilderExample.menuItemExtent,
                padding: const EdgeInsets.symmetric(vertical: 6),
                constraints: const BoxConstraints(minWidth: 172),
                children: menuChildren,
              );
            },
            menuChildren: <Widget>[
              for (int i = 0; i < menuItems.length; i++)
                MenuItemButton(
                  autofocus: _selected == i,
                  onPressed: i != 3 ? () { _handlePressed(i); } : null,
                  leadingIcon: SizedBox(width: 24, child: menuItems[i].leading),
                  trailingIcon: _selected == i ? const Icon(Icons.check) : null,
                  child: Text(menuItems[i].label),
                ),
            ],
            builder: (
              BuildContext context,
              MenuController controller,
              Widget? child,
            ) {
              return SizedBox(
                width: 168,
                child: FilledButton(
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _selected == null
                            ? 'Select One'
                            : menuItems[_selected!].label
                        ),
                      ),
                      const Flexible(child: Icon(Icons.arrow_drop_down)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ItemAwareMenuSurface extends StatelessWidget {
  const ItemAwareMenuSurface({
    super.key,
    required this.selectedIndex,
    required this.position,
    required this.children,
    required this.itemExtent,
    this.padding = EdgeInsets.zero,
    this.constraints = const BoxConstraints(),
  });

  final int selectedIndex;
  final double itemExtent;
  final RawMenuAnchorOverlayPosition position;
  final List<Widget> children;
  final EdgeInsets padding;
  final BoxConstraints constraints;

  static const Cubic curve = Cubic(0.36, 1.1, 0, 1);

  static const Map<SingleActivator, Intent> shortcuts =
  <SingleActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.escape):    DismissIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
    SingleActivator(LogicalKeyboardKey.arrowUp):   DirectionalFocusIntent(TraversalDirection.up),
  };

  @override
  Widget build(BuildContext context) {
    final int lastIndex = math.max(children.length - 1, 1);
    final double bias   = (selectedIndex / lastIndex) * 2 - 1;
    final double height = itemExtent * children.length + padding.vertical;
    final double offset = -selectedIndex * itemExtent - padding.vertical;
    final Offset origin = position.anchorRect.topCenter.translate(-84, offset);
    final Alignment alignment = Alignment(0, bias);

    return Positioned(
      top: origin.dy,
      left: origin.dx,
      height: height,
      child: Semantics.fromProperties(
        explicitChildNodes: true,
        properties: const SemanticsProperties(scopesRoute: true),
        child: TapRegion(
          groupId: position.tapRegionGroupId,
          consumeOutsideTaps: true,
          onTapOutside: (PointerDownEvent event) {
            MenuController.maybeOf(context)?.close();
          },
          child: FocusScope(
            skipTraversal: true,
            descendantsAreFocusable: true,
            child: Shortcuts(
              shortcuts: shortcuts,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 350),
                curve: curve,
                builder: (
                  BuildContext context,
                  double value,
                  Widget? child,
                ) {
                  return Transform(
                    transform: Matrix4.identity()
                      ..scale(1.0, value)
                      ..translate(0.0, 24.0 * (1 - value)),
                    alignment: alignment,
                    child: Opacity(
                      opacity: ui.clampDouble(value, 0, 1),
                      child: Material(
                        elevation: 8,
                        clipBehavior: Clip.antiAlias,
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                        child: Transform.scale(
                          alignment: alignment,
                          scaleY: 1 / value,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: padding,
                  child: ConstrainedBox(
                    constraints: constraints,
                    child: IntrinsicWidth(
                      child: SingleChildScrollView(
                        child: ListBody(children: children),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MenuOverlayBuilderApp extends StatelessWidget {
  const MenuOverlayBuilderApp({super.key});

  static const ButtonStyle buttonStyle = ButtonStyle(
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.comfortable,
    iconSize: WidgetStatePropertyAll<double>(17),
    overlayColor: WidgetStatePropertyAll<Color>(ui.Color(0x1D82B0FF)),
    textStyle: WidgetStatePropertyAll<TextStyle>(TextStyle(fontSize: 15)),
    padding: WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 12)),
    shape: WidgetStatePropertyAll<RoundedRectangleBorder>(RoundedRectangleBorder()),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ).copyWith(
        filledButtonTheme: const FilledButtonThemeData(style: buttonStyle),
        menuButtonTheme: const MenuButtonThemeData(style: buttonStyle),
      ),
      home: const MenuOverlayBuilderExample(),
    );
  }
}
