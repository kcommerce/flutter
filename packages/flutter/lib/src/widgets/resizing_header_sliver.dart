// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'framework.dart';
import 'sliver_coordinator.dart';
import 'slotted_render_object_widget.dart';

class ResizingHeaderSliverLayoutInfo extends SliverLayoutInfo{
  const ResizingHeaderSliverLayoutInfo({
    required super.constraints,
    required super.geometry,
    required this.minExtent,
    required this.maxExtent,
  });

  final double minExtent;
  final double maxExtent;
}

/// {@tool dartpad}
/// This sample ...
///
/// ** See code in examples/api/lib/widgets/sliver/resizing_header_sliver.0.dart **
/// {@end-tool}
class ResizingHeaderSliver extends StatelessWidget {
  const ResizingHeaderSliver({
    super.key,
    this.minExtentPrototype,
    this.maxExtentPrototype,
    this.child,
  });

  final Widget? minExtentPrototype;
  final Widget? maxExtentPrototype;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return _ResizingHeaderSliver(
      id: this,
      minExtentPrototype: minExtentPrototype,
      maxExtentPrototype: maxExtentPrototype,
      child: child,
    );
  }

  ResizingHeaderSliverLayoutInfo? getLayoutInfo(SliverCoordinatorData data) {
    return data.get<ResizingHeaderSliverLayoutInfo>(this);
  }
}

enum _Slot {
  minExtent,
  maxExtent,
  child,
}

class _ResizingHeaderSliver extends SlottedMultiChildRenderObjectWidget<_Slot, RenderBox> {
  const _ResizingHeaderSliver({
    required this.id,
    this.minExtentPrototype,
    this.maxExtentPrototype,
    this.child,
  });

  final Object id;
  final Widget? minExtentPrototype;
  final Widget? maxExtentPrototype;
  final Widget? child;

  @override
  Iterable<_Slot> get slots => _Slot.values;

  @override
  Widget? childForSlot(_Slot slot) {
    return switch (slot) {
      _Slot.minExtent => minExtentPrototype,
      _Slot.maxExtent => maxExtentPrototype,
      _Slot.child => child,
    };
  }

  @override
  _RenderResizingHeaderSliver createRenderObject(BuildContext context) {
    return _RenderResizingHeaderSliver(
      id: id,
      data: SliverCoordinator.of(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderResizingHeaderSliver renderObject) {
    renderObject.id = id;
    renderObject.data = SliverCoordinator.of(context);
  }
}

class _RenderResizingHeaderSliver extends RenderSliver with SlottedContainerRenderObjectMixin<_Slot, RenderBox>, RenderSliverHelpers {
  _RenderResizingHeaderSliver({
    required this.id,
    required this.data
  });

  Object id;
  SliverCoordinatorData data;
  RenderBox? get minExtentPrototype => childForSlot(_Slot.minExtent);
  RenderBox? get maxExtentPrototype => childForSlot(_Slot.maxExtent);
  RenderBox? get child => childForSlot(_Slot.child);

  @override
  Iterable<RenderBox> get children {
    return <RenderBox>[
      if (minExtentPrototype != null) minExtentPrototype!,
      if (maxExtentPrototype != null) maxExtentPrototype!,
      if (child != null) child!,
    ];
  }

  double boxExtent(RenderBox? box) {
    if (box == null) {
      return 0.0;
    }
    assert(box.hasSize);
    return switch (constraints.axis) {
      Axis.vertical => box.size.height,
      Axis.horizontal => box.size.width,
    };
  }

  double get childExtent => boxExtent(child);

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverPhysicalParentData) {
      child.parentData = SliverPhysicalParentData();
    }
  }

  @protected
  void setChildParentData(RenderObject child, SliverConstraints constraints, SliverGeometry geometry) {
    final SliverPhysicalParentData childParentData = child.parentData! as SliverPhysicalParentData;
    final AxisDirection direction = applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection);
    childParentData.paintOffset = switch (direction) {
      AxisDirection.up => Offset(0.0, -(geometry.scrollExtent - (geometry.paintExtent + constraints.scrollOffset))),
      AxisDirection.right => Offset(-constraints.scrollOffset, 0.0),
      AxisDirection.down => Offset(0.0, -constraints.scrollOffset),
      AxisDirection.left => Offset(-(geometry.scrollExtent - (geometry.paintExtent + constraints.scrollOffset)), 0.0),
    };
  }

  @override
  double childMainAxisPosition(covariant RenderObject child) => 0;

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    final BoxConstraints prototypeBoxConstraints = constraints.asBoxConstraints();

    double minExtent = 0;
    if (minExtentPrototype != null) {
      minExtentPrototype!.layout(prototypeBoxConstraints, parentUsesSize: true);
      minExtent = boxExtent(minExtentPrototype);
    }

    double maxExtent = double.infinity;
    if (maxExtentPrototype != null) {
      maxExtentPrototype!.layout(prototypeBoxConstraints, parentUsesSize: true);
      maxExtent = boxExtent(maxExtentPrototype);
    }

    final double scrollOffset = constraints.scrollOffset;
    final double shrinkOffset = math.min(scrollOffset, maxExtent);
    final BoxConstraints boxConstraints = constraints.asBoxConstraints(
      minExtent: minExtent,
      maxExtent: math.max(minExtent, maxExtent - shrinkOffset),
    );
    child?.layout(boxConstraints, parentUsesSize: true);

    final double remainingPaintExtent = constraints.remainingPaintExtent;
    final double layoutExtent = math.min(childExtent, maxExtent - scrollOffset);
    geometry = SliverGeometry(
      scrollExtent: maxExtent,
      paintOrigin: constraints.overlap,
      paintExtent: math.min(childExtent, remainingPaintExtent),
      layoutExtent: clampDouble(layoutExtent, 0, remainingPaintExtent),
      maxPaintExtent: childExtent,
      maxScrollObstructionExtent: childExtent,
      cacheExtent: calculateCacheOffset(constraints, from: 0.0, to: childExtent),
      hasVisualOverflow: true, // Conservatively say we do have overflow to avoid complexity.
    );

    data.put<ResizingHeaderSliverLayoutInfo>(id, ResizingHeaderSliverLayoutInfo(
      constraints: constraints,
      geometry: geometry!,
      minExtent: minExtent,
      maxExtent: maxExtent,
    ));
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final SliverPhysicalParentData childParentData = child.parentData! as SliverPhysicalParentData;
    childParentData.applyPaintTransform(transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && geometry!.visible) {
      final SliverPhysicalParentData childParentData = child!.parentData! as SliverPhysicalParentData;
      context.paintChild(child!, offset + childParentData.paintOffset);
    }
  }

  @override
  bool hitTestChildren(SliverHitTestResult result, { required double mainAxisPosition, required double crossAxisPosition }) {
    assert(geometry!.hitTestExtent > 0.0);
    if (child != null) {
      return hitTestBoxChild(BoxHitTestResult.wrap(result), child!, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
    }
    return false;
  }
}
