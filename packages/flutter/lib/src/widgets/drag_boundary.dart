// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'framework.dart';

/// The interface for defining the algorithm for a boundary that a specified shape is dragged within.
///
/// See also:
///  * [DragBoundary], which uses this class.
///
/// `T` is a data class that defines the shape being dragged. For example, when dragging a rectangle within the boundary,
/// `T` should be a `Rect`.
abstract class DragBoundaryDelegate<T> {
  /// Returns whether the specified dragged object is within the boundary.
  bool isWithinBoundary(T draggedObject);

  /// Returns the given dragged object after moving it fully inside
  /// the boundary with the shortest distance.
  ///
  /// If the bounds cannot contain the dragged object, an exception is thrown.
  T nearestPositionWithinBoundary(T draggedObject);
}

class _DragBoundaryDelegateForRect extends DragBoundaryDelegate<Rect> {
  _DragBoundaryDelegateForRect(this.boundary);
  final Rect? boundary;
  @override
  bool isWithinBoundary(Rect draggedObject) {
    if (boundary == null) {
      return true;
    }
    return boundary!.contains(draggedObject.topLeft) && boundary!.contains(draggedObject.bottomRight);
  }

  @override
  Rect nearestPositionWithinBoundary(Rect draggedObject) {
    if (boundary == null) {
      return draggedObject;
    }
    if (boundary!.right - draggedObject.width < boundary!.left ||
        boundary!.bottom - draggedObject.height < boundary!.top) {
      throw FlutterError(
        'The rect is larger than the boundary. '
        'The rect width must be less than the boundary width, and the rect height must be less than the boundary height.',
      );
    }
    final double left = clampDouble(
      draggedObject.left,
      boundary!.left,
      boundary!.right - draggedObject.width,
    );
    final double top = clampDouble(
      draggedObject.top,
      boundary!.top,
      boundary!.bottom - draggedObject.height,
    );
    return Rect.fromLTWH(left, top, draggedObject.width, draggedObject.height);
  }
}

/// Provides a [DragBoundaryDelegate] for its descendants whose bounds are those defined by this widget.
///
/// {@tool dartpad}
/// This example demonstrates dragging a red box, constrained within the bounds
/// of a green box.
///
/// ** See code in examples/api/lib/widgets/gesture_detector/gesture_detector.3.dart **
/// {@end-tool}
class DragBoundary extends InheritedWidget {
  /// Creates a widget that provides a boundary to its descendants.
  const DragBoundary({required super.child, super.key});

  /// Retrieve the [DragBoundary] from the nearest ancestor to
  /// get its [DragBoundaryDelegate] of [Rect].
  ///
  /// The [useGlobalPosition] flag specifies whether to use global position.
  /// If false, the local position of the bounds are used. It defaults to true.
  ///
  /// If no [DragBoundary] ancestor is found, the delegate will return a delegate that allows the drag object to move freely.
  static DragBoundaryDelegate<Rect> forRectOf(BuildContext context, {bool useGlobalPosition = true}) {
    final InheritedElement? element =
        context.getElementForInheritedWidgetOfExactType<DragBoundary>();
    if (element == null) {
      return _DragBoundaryDelegateForRect(null);
    }
    final RenderBox? rb = element.findRenderObject() as RenderBox?;
    assert(rb != null && rb.hasSize, 'DragBoundary is not available');
    final Rect boundary = useGlobalPosition
      ? Rect.fromPoints(rb!.localToGlobal(Offset.zero), rb.localToGlobal(rb.size.bottomRight(Offset.zero)))
      : Offset.zero & rb!.size;
    return _DragBoundaryDelegateForRect(boundary);
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }
}
