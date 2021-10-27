// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart';

import 'debug.dart';

/// Information collected for an annotation that is found in the layer tree.
///
/// See also:
///
///  * [Layer.findAnnotations], which create and use objects of this class.
@immutable
class AnnotationEntry<T> {
  /// Create an entry of found annotation by providing the object and related
  /// information.
  const AnnotationEntry({
    required this.annotation,
    required this.localPosition,
  }) : assert(localPosition != null);

  /// The annotation object that is found.
  final T annotation;

  /// The target location described by the local coordinate space of the
  /// annotation object.
  final Offset localPosition;

  @override
  String toString() {
    return '${objectRuntimeType(this, 'AnnotationEntry')}(annotation: $annotation, localPosition: $localPosition)';
  }
}

/// Information collected about a list of annotations that are found in the
/// layer tree.
///
/// See also:
///
///  * [AnnotationEntry], which are members of this class.
///  * [Layer.findAllAnnotations], and [Layer.findAnnotations], which create and
///    use an object of this class.
class AnnotationResult<T> {
  final List<AnnotationEntry<T>> _entries = <AnnotationEntry<T>>[];

  /// Add a new entry to the end of the result.
  ///
  /// Usually, entries should be added in order from most specific to least
  /// specific, typically during an upward walk of the tree.
  void add(AnnotationEntry<T> entry) => _entries.add(entry);

  /// An unmodifiable list of [AnnotationEntry] objects recorded.
  ///
  /// The first entry is the most specific, typically the one at the leaf of
  /// tree.
  Iterable<AnnotationEntry<T>> get entries => _entries;

  /// An unmodifiable list of annotations recorded.
  ///
  /// The first entry is the most specific, typically the one at the leaf of
  /// tree.
  ///
  /// It is similar to [entries] but does not contain other information.
  Iterable<T> get annotations sync* {
    for (final AnnotationEntry<T> entry in _entries)
      yield entry.annotation;
  }
}

/// A composited layer.
///
/// During painting, the render tree generates a tree of composited layers that
/// are uploaded into the engine and displayed by the compositor. This class is
/// the base class for all composited layers.
///
/// Most layers can have their properties mutated, and layers can be moved to
/// different parents. The scene must be explicitly recomposited after such
/// changes are made; the layer tree does not maintain its own dirty state.
///
/// To composite the tree, create a [SceneBuilder] object, pass it to the
/// root [Layer] object's [addToScene] method, and then call
/// [SceneBuilder.build] to obtain a [Scene]. A [Scene] can then be painted
/// using [dart:ui.FlutterView.render].
///
/// ## Memory
///
/// Layers retain resources between frames to speed up rendering. A layer will
/// retain these resources until all [LayerHandle]s referring to the layer have
/// nulled out their references.
///
/// Layers must not be used after disposal. If a RenderObject needs to maintain
/// a layer for later usage, it must create a handle to that layer. This is
/// handled automatically for the [RenderObject.layer] property, but additional
/// layers must use their own [LayerHandle].
///
/// {@tool snippet}
///
/// This [RenderObject] is a repaint boundary that pushes an additional
/// [ClipRectLayer].
///
/// ```dart
/// class ClippingRenderObject extends RenderBox {
///   final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();
///
///   @override
///   bool get isRepaintBoundary => true; // The [layer] property will be used.
///
///   @override
///   void paint(PaintingContext context, Offset offset) {
///     _clipRectLayer.layer = context.pushClipRect(
///       needsCompositing,
///       offset,
///       Offset.zero & size,
///       super.paint,
///       clipBehavior: Clip.hardEdge,
///       oldLayer: _clipRectLayer.layer,
///     );
///   }
///
///   @override
///   void dispose() {
///     _clipRectLayer.layer = null;
///     super.dispose();
///   }
/// }
/// ```
/// {@end-tool}
/// See also:
///
///  * [RenderView.compositeFrame], which implements this recomposition protocol
///    for painting [RenderObject] trees on the display.
abstract class Layer extends AbstractNode with DiagnosticableTreeMixin {
  /// If asserts are enabled, returns whether [dispose] has
  /// been called since the last time any retained resources were created.
  ///
  /// Throws an exception if asserts are disabled.
  bool get debugDisposed {
    late bool disposed;
    assert(() {
      disposed = _debugDisposed;
      return true;
    }());
    return disposed;
  }
  bool _debugDisposed = false;

  /// Set when this layer is appended to a [ContainerLayer], and
  /// unset when it is removed.
  ///
  /// This cannot be set from [attach] or [detach] which is called when an
  /// entire subtree is attached to or detached from an owner. Layers may be
  /// appended to or removed from a [ContainerLayer] regardless of whether they
  /// are attached or detached, and detaching a layer from an owner does not
  /// imply that it has been removed from its parent.
  final LayerHandle<Layer> _parentHandle = LayerHandle<Layer>();

  /// Incremented by [LayerHandle].
  int _refCount = 0;

  /// Called by [LayerHandle].
  void _unref() {
    assert(_refCount > 0);
    _refCount -= 1;
    if (_refCount == 0) {
      dispose();
    }
  }

  /// Returns the number of objects holding a [LayerHandle] to this layer.
  ///
  /// This method throws if asserts are disabled.
  int get debugHandleCount {
    late int count;
    assert(() {
      count = _refCount;
      return true;
    }());
    return count;
  }

  /// Clears any retained resources that this layer holds.
  ///
  /// This method must dispose resources such as [EngineLayer] and [Picture]
  /// objects. The layer is still usable after this call, but any graphics
  /// related resources it holds will need to be recreated.
  ///
  /// This method _only_ disposes resources for this layer. For example, if it
  /// is a [ContainerLayer], it does not dispose resources of any children.
  /// However, [ContainerLayer]s do remove any children they have when
  /// this method is called, and if this layer was the last holder of a removed
  /// child handle, the child may recursively clean up its resources.
  ///
  /// This method automatically gets called when all outstanding [LayerHandle]s
  /// are disposed. [LayerHandle] objects are typically held by the [parent]
  /// layer of this layer and any [RenderObject]s that participated in creating
  /// it.
  ///
  /// After calling this method, the object is unusable.
  @mustCallSuper
  @protected
  @visibleForTesting
  void dispose() {
    assert(
      !_debugDisposed,
      'Layers must only be disposed once. This is typically handled by '
      'LayerHandle and createHandle. Subclasses should not directly call '
      'dispose, except to call super.dispose() in an overridden dispose  '
      'method. Tests must only call dispose once.',
    );
    assert(() {
      assert(
        _refCount == 0,
        'Do not directly call dispose on a $runtimeType. Instead, '
        'use createHandle and LayerHandle.dispose.',
      );
      _debugDisposed = true;
      return true;
    }());
    _engineLayer?.dispose();
    _engineLayer = null;
  }

  /// This layer's parent in the layer tree.
  ///
  /// The [parent] of the root node in the layer tree is null.
  ///
  /// Only subclasses of [ContainerLayer] can have children in the layer tree.
  /// All other layer classes are used for leaves in the layer tree.
  @override
  ContainerLayer? get parent => super.parent as ContainerLayer?;

  // Whether this layer has any changes since its last call to [addToScene].
  //
  // Initialized to true as a new layer has never called [addToScene], and is
  // set to false after calling [addToScene]. The value can become true again
  // if [markNeedsAddToScene] is called, or when [updateSubtreeNeedsAddToScene]
  // is called on this layer or on an ancestor layer.
  //
  // The values of [_needsAddToScene] in a tree of layers are said to be
  // _consistent_ if every layer in the tree satisfies the following:
  //
  // - If [alwaysNeedsAddToScene] is true, then [_needsAddToScene] is also true.
  // - If [_needsAddToScene] is true and [parent] is not null, then
  //   `parent._needsAddToScene` is true.
  //
  // Typically, this value is set during the paint phase and during compositing.
  // During the paint phase render objects create new layers and call
  // [markNeedsAddToScene] on existing layers, causing this value to become
  // true. After the paint phase the tree may be in an inconsistent state.
  // During compositing [ContainerLayer.buildScene] first calls
  // [updateSubtreeNeedsAddToScene] to bring this tree to a consistent state,
  // then it calls [addToScene], and finally sets this field to false.
  bool _needsAddToScene = true;

  /// Mark that this layer has changed and [addToScene] needs to be called.
  @protected
  @visibleForTesting
  void markNeedsAddToScene() {
    assert(
      !alwaysNeedsAddToScene,
      '$runtimeType with alwaysNeedsAddToScene set called markNeedsAddToScene.\n'
      "The layer's alwaysNeedsAddToScene is set to true, and therefore it should not call markNeedsAddToScene.",
    );
    assert(!_debugDisposed);

    // Already marked. Short-circuit.
    if (_needsAddToScene) {
      return;
    }

    _needsAddToScene = true;
  }

  /// Mark that this layer is in sync with engine.
  ///
  /// This is for debugging and testing purposes only. In release builds
  /// this method has no effect.
  @visibleForTesting
  void debugMarkClean() {
    assert(() {
      _needsAddToScene = false;
      return true;
    }());
  }

  /// Subclasses may override this to true to disable retained rendering.
  @protected
  bool get alwaysNeedsAddToScene => false;

  /// Whether this or any descendant layer in the subtree needs [addToScene].
  ///
  /// This is for debug and test purpose only. It only becomes valid after
  /// calling [updateSubtreeNeedsAddToScene].
  @visibleForTesting
  bool? get debugSubtreeNeedsAddToScene {
    bool? result;
    assert(() {
      result = _needsAddToScene;
      return true;
    }());
    return result;
  }

  /// Stores the engine layer created for this layer in order to reuse engine
  /// resources across frames for better app performance.
  ///
  /// This value may be passed to [ui.SceneBuilder.addRetained] to communicate
  /// to the engine that nothing in this layer or any of its descendants
  /// changed. The native engine could, for example, reuse the texture rendered
  /// in a previous frame. The web engine could, for example, reuse the HTML
  /// DOM nodes created for a previous frame.
  ///
  /// This value may be passed as `oldLayer` argument to a "push" method to
  /// communicate to the engine that a layer is updating a previously rendered
  /// layer. The web engine could, for example, update the properties of
  /// previously rendered HTML DOM nodes rather than creating new nodes.
  @protected
  @visibleForTesting
  ui.EngineLayer? get engineLayer => _engineLayer;

  /// Sets the engine layer used to render this layer.
  ///
  /// Typically this field is set to the value returned by [addToScene], which
  /// in turn returns the engine layer produced by one of [ui.SceneBuilder]'s
  /// "push" methods, such as [ui.SceneBuilder.pushOpacity].
  @protected
  @visibleForTesting
  set engineLayer(ui.EngineLayer? value) {
    assert(!_debugDisposed);

    _engineLayer?.dispose();
    _engineLayer = value;
    if (!alwaysNeedsAddToScene) {
      // The parent must construct a new engine layer to add this layer to, and
      // so we mark it as needing [addToScene].
      //
      // This is designed to handle two situations:
      //
      // 1. When rendering the complete layer tree as normal. In this case we
      // call child `addToScene` methods first, then we call `set engineLayer`
      // for the parent. The children will call `markNeedsAddToScene` on the
      // parent to signal that they produced new engine layers and therefore
      // the parent needs to update. In this case, the parent is already adding
      // itself to the scene via [addToScene], and so after it's done, its
      // `set engineLayer` is called and it clears the `_needsAddToScene` flag.
      //
      // 2. When rendering an interior layer (e.g. `OffsetLayer.toImage`). In
      // this case we call `addToScene` for one of the children but not the
      // parent, i.e. we produce new engine layers for children but not for the
      // parent. Here the children will mark the parent as needing
      // `addToScene`, but the parent does not clear the flag until some future
      // frame decides to render it, at which point the parent knows that it
      // cannot retain its engine layer and will call `addToScene` again.
      if (parent != null && !parent!.alwaysNeedsAddToScene) {
        parent!.markNeedsAddToScene();
      }
    }
  }
  ui.EngineLayer? _engineLayer;

  /// Traverses the layer subtree starting from this layer and determines whether it needs [addToScene].
  ///
  /// A layer needs [addToScene] if any of the following is true:
  ///
  /// - [alwaysNeedsAddToScene] is true.
  /// - [markNeedsAddToScene] has been called.
  /// - Any of its descendants need [addToScene].
  ///
  /// [ContainerLayer] overrides this method to recursively call it on its children.
  @protected
  @visibleForTesting
  void updateSubtreeNeedsAddToScene() {
    _needsAddToScene = _needsAddToScene || alwaysNeedsAddToScene;
  }

  /// This layer's next sibling in the parent layer's child list.
  Layer? get nextSibling => _nextSibling;
  Layer? _nextSibling;

  /// This layer's previous sibling in the parent layer's child list.
  Layer? get previousSibling => _previousSibling;
  Layer? _previousSibling;

  @override
  void dropChild(AbstractNode child) {
    if (!alwaysNeedsAddToScene) {
      markNeedsAddToScene();
    }
    super.dropChild(child);
  }

  @override
  void adoptChild(AbstractNode child) {
    if (!alwaysNeedsAddToScene) {
      markNeedsAddToScene();
    }
    super.adoptChild(child);
  }

  /// Removes this layer from its parent layer's child list.
  ///
  /// This has no effect if the layer's parent is already null.
  @mustCallSuper
  void remove() {
    parent?._removeChild(this);
  }

  /// Search this layer and its subtree for annotations of type `S` at the
  /// location described by `localPosition`.
  ///
  /// This method is called by the default implementation of [find] and
  /// [findAllAnnotations]. Override this method to customize how the layer
  /// should search for annotations, or if the layer has its own annotations to
  /// add.
  ///
  /// The default implementation simply returns `false`, which means neither
  /// the layer nor its children has annotations, and the annotation search
  /// is not absorbed either (see below for explanation).
  ///
  /// ## About layer annotations
  ///
  /// {@template flutter.rendering.Layer.findAnnotations.aboutAnnotations}
  /// An annotation is an optional object of any type that can be carried with a
  /// layer. An annotation can be found at a location as long as the owner layer
  /// contains the location and is walked to.
  ///
  /// The annotations are searched by first visiting each child recursively,
  /// then this layer, resulting in an order from visually front to back.
  /// Annotations must meet the given restrictions, such as type and position.
  ///
  /// The common way for a value to be found here is by pushing an
  /// [AnnotatedRegionLayer] into the layer tree, or by adding the desired
  /// annotation by overriding [findAnnotations].
  /// {@endtemplate}
  ///
  /// ## Parameters and return value
  ///
  /// The [result] parameter is where the method outputs the resulting
  /// annotations. New annotations found during the walk are added to the tail.
  ///
  /// The [onlyFirst] parameter indicates that, if true, the search will stop
  /// when it finds the first qualified annotation; otherwise, it will walk the
  /// entire subtree.
  ///
  /// The return value indicates the opacity of this layer and its subtree at
  /// this position. If it returns true, then this layer's parent should skip
  /// the children behind this layer. In other words, it is opaque to this type
  /// of annotation and has absorbed the search so that its siblings behind it
  /// are not aware of the search. If the return value is false, then the parent
  /// might continue with other siblings.
  ///
  /// The return value does not affect whether the parent adds its own
  /// annotations; in other words, if a layer is supposed to add an annotation,
  /// it will always add it even if its children are opaque to this type of
  /// annotation. However, the opacity that the parents return might be affected
  /// by their children, hence making all of its ancestors opaque to this type
  /// of annotation.
  @protected
  bool findAnnotations<S extends Object>(
    AnnotationResult<S> result,
    Offset localPosition, {
    required bool onlyFirst,
  }) {
    return false;
  }

  /// Search this layer and its subtree for the first annotation of type `S`
  /// under the point described by `localPosition`.
  ///
  /// Returns null if no matching annotations are found.
  ///
  /// By default this method simply calls [findAnnotations] with `onlyFirst:
  /// true` and returns the annotation of the first result. Prefer overriding
  /// [findAnnotations] instead of this method, because during an annotation
  /// search, only [findAnnotations] is recursively called, while custom
  /// behavior in this method is ignored.
  ///
  /// ## About layer annotations
  ///
  /// {@macro flutter.rendering.Layer.findAnnotations.aboutAnnotations}
  ///
  /// See also:
  ///
  ///  * [findAllAnnotations], which is similar but returns all annotations found
  ///    at the given position.
  ///  * [AnnotatedRegionLayer], for placing values in the layer tree.
  S? find<S extends Object>(Offset localPosition) {
    final AnnotationResult<S> result = AnnotationResult<S>();
    findAnnotations<S>(result, localPosition, onlyFirst: true);
    return result.entries.isEmpty ? null : result.entries.first.annotation;
  }

  /// Search this layer and its subtree for all annotations of type `S` under
  /// the point described by `localPosition`.
  ///
  /// Returns a result with empty entries if no matching annotations are found.
  ///
  /// By default this method simply calls [findAnnotations] with `onlyFirst:
  /// false` and returns the annotations of its result. Prefer overriding
  /// [findAnnotations] instead of this method, because during an annotation
  /// search, only [findAnnotations] is recursively called, while custom
  /// behavior in this method is ignored.
  ///
  /// ## About layer annotations
  ///
  /// {@macro flutter.rendering.Layer.findAnnotations.aboutAnnotations}
  ///
  /// See also:
  ///
  ///  * [find], which is similar but returns the first annotation found at the
  ///    given position.
  ///  * [AnnotatedRegionLayer], for placing values in the layer tree.
  AnnotationResult<S> findAllAnnotations<S extends Object>(Offset localPosition) {
    final AnnotationResult<S> result = AnnotationResult<S>();
    findAnnotations<S>(result, localPosition, onlyFirst: false);
    return result;
  }

  /// Override this method to upload this layer to the engine.
  ///
  /// Return the engine layer for retained rendering. When there's no
  /// corresponding engine layer, null is returned.
  @protected
  void addToScene(ui.SceneBuilder builder);

  void _addToSceneWithRetainedRendering(ui.SceneBuilder builder) {
    // There can't be a loop by adding a retained layer subtree whose
    // _needsAddToScene is false.
    //
    // Proof by contradiction:
    //
    // If we introduce a loop, this retained layer must be appended to one of
    // its descendant layers, say A. That means the child structure of A has
    // changed so A's _needsAddToScene is true. This contradicts
    // _needsAddToScene being false.
    if (!_needsAddToScene && _engineLayer != null) {
      builder.addRetained(_engineLayer!);
      return;
    }
    addToScene(builder);
    // Clearing the flag _after_ calling `addToScene`, not _before_. This is
    // because `addToScene` calls children's `addToScene` methods, which may
    // mark this layer as dirty.
    _needsAddToScene = false;
  }

  /// The object responsible for creating this layer.
  ///
  /// Defaults to the value of [RenderObject.debugCreator] for the render object
  /// that created this layer. Used in debug messages.
  Object? debugCreator;

  @override
  String toStringShort() => '${super.toStringShort()}${ owner == null ? " DETACHED" : ""}';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Object>('owner', owner, level: parent != null ? DiagnosticLevel.hidden : DiagnosticLevel.info, defaultValue: null));
    properties.add(DiagnosticsProperty<Object?>('creator', debugCreator, defaultValue: null, level: DiagnosticLevel.debug));
    if (_engineLayer != null) {
      properties.add(DiagnosticsProperty<String>('engine layer', describeIdentity(_engineLayer)));
    }
    properties.add(DiagnosticsProperty<int>('handles', debugHandleCount));
  }
}

/// A handle to prevent a [Layer]'s platform graphics resources from being
/// disposed.
///
/// [Layer] objects retain native resources such as [EngineLayer]s and [Picture]
/// objects. These objects may in turn retain large chunks of texture memory,
/// either directly or indirectly.
///
/// The layer's native resources must be retained as long as there is some
/// object that can add it to a scene. Typically, this is either its
/// [Layer.parent] or an undisposed [RenderObject] that will append it to a
/// [ContainerLayer]. Layers automatically hold a handle to their children, and
/// RenderObjects automatically hold a handle to their [RenderObject.layer] as
/// well as any [PictureLayer]s that they paint into using the
/// [PaintingContext.canvas]. A layer automatically releases its resources once
/// at least one handle has been acquired and all handles have been disposed.
/// [RenderObject]s that create additional layer objects must manually manage
/// the handles for that layer similarly to the implementation of
/// [RenderObject.layer].
///
/// A handle is automatically managed for [RenderObject.layer].
///
/// If a [RenderObject] creates layers in addition to its [RenderObject.layer]
/// and it intends to reuse those layers separately from [RenderObject.layer],
/// it must create a handle to that layer and dispose of it when the layer is
/// no longer needed. For example, if it re-creates or nulls out an existing
/// layer in [RenderObject.paint], it should dispose of the handle to the
/// old layer. It should also dispose of any layer handles it holds in
/// [RenderObject.dispose].
class LayerHandle<T extends Layer> {
  /// Create a new layer handle, optionally referencing a [Layer].
  LayerHandle([this._layer]) {
    if (_layer != null) {
      _layer!._refCount += 1;
    }
  }

  T? _layer;

  /// The [Layer] whose resources this object keeps alive.
  ///
  /// Setting a new value or null will dispose the previously held layer if
  /// there are no other open handles to that layer.
  T? get layer => _layer;

  set layer(T? layer) {
    assert(
      layer?.debugDisposed != true,
      'Attempted to create a handle to an already disposed layer: $layer.',
    );
    if (identical(layer, _layer)) {
      return;
    }
    _layer?._unref();
    _layer = layer;
    if (_layer != null) {
      _layer!._refCount += 1;
    }
  }

  @override
  String toString() => 'LayerHandle(${_layer != null ? _layer.toString() : 'DISPOSED'})';
}

/// A composited layer containing a [Picture].
///
/// Picture layers are always leaves in the layer tree. They are also
/// responsible for disposing of the [Picture] object they hold. This is
/// typically done when their parent and all [RenderObject]s that participated
/// in painting the picture have been disposed.
class PictureLayer extends Layer {
  /// Creates a leaf layer for the layer tree.
  PictureLayer(this.canvasBounds);

  /// The bounds that were used for the canvas that drew this layer's [picture].
  ///
  /// This is purely advisory. It is included in the information dumped with
  /// [debugDumpLayerTree] (which can be triggered by pressing "L" when using
  /// "flutter run" at the console), which can help debug why certain drawing
  /// commands are being culled.
  final Rect canvasBounds;

  /// The picture recorded for this layer.
  ///
  /// The picture's coordinate system matches this layer's coordinate system.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ui.Picture? get picture => _picture;
  ui.Picture? _picture;
  set picture(ui.Picture? picture) {
    assert(!_debugDisposed);
    markNeedsAddToScene();
    _picture?.dispose();
    _picture = picture;
  }

  /// Hints that the painting in this layer is complex and would benefit from
  /// caching.
  ///
  /// If this hint is not set, the compositor will apply its own heuristics to
  /// decide whether the this layer is complex enough to benefit from caching.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  bool get isComplexHint => _isComplexHint;
  bool _isComplexHint = false;
  set isComplexHint(bool value) {
    if (value != _isComplexHint) {
      _isComplexHint = value;
      markNeedsAddToScene();
    }
  }

  /// Hints that the painting in this layer is likely to change next frame.
  ///
  /// This hint tells the compositor not to cache this layer because the cache
  /// will not be used in the future. If this hint is not set, the compositor
  /// will apply its own heuristics to decide whether this layer is likely to be
  /// reused in the future.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  bool get willChangeHint => _willChangeHint;
  bool _willChangeHint = false;
  set willChangeHint(bool value) {
    if (value != _willChangeHint) {
      _willChangeHint = value;
      markNeedsAddToScene();
    }
  }

  @override
  void dispose() {
    picture = null; // Will dispose _picture.
    super.dispose();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(picture != null);
    builder.addPicture(Offset.zero, picture!, isComplexHint: isComplexHint, willChangeHint: willChangeHint);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Rect>('paint bounds', canvasBounds));
    properties.add(DiagnosticsProperty<String>('picture', describeIdentity(_picture)));
    properties.add(DiagnosticsProperty<String>(
      'raster cache hints',
      'isComplex = $isComplexHint, willChange = $willChangeHint',
    ));
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    return false;
  }
}

/// A composited layer that maps a backend texture to a rectangle.
///
/// Backend textures are images that can be applied (mapped) to an area of the
/// Flutter view. They are created, managed, and updated using a
/// platform-specific texture registry. This is typically done by a plugin
/// that integrates with host platform video player, camera, or OpenGL APIs,
/// or similar image sources.
///
/// A texture layer refers to its backend texture using an integer ID. Texture
/// IDs are obtained from the texture registry and are scoped to the Flutter
/// view. Texture IDs may be reused after deregistration, at the discretion
/// of the registry. The use of texture IDs currently unknown to the registry
/// will silently result in a blank rectangle.
///
/// Once inserted into the layer tree, texture layers are repainted autonomously
/// as dictated by the backend (e.g. on arrival of a video frame). Such
/// repainting generally does not involve executing Dart code.
///
/// Texture layers are always leaves in the layer tree.
///
/// See also:
///
///  * <https://api.flutter.dev/javadoc/io/flutter/view/TextureRegistry.html>
///    for how to create and manage backend textures on Android.
///  * <https://api.flutter.dev/objcdoc/Protocols/FlutterTextureRegistry.html>
///    for how to create and manage backend textures on iOS.
class TextureLayer extends Layer {
  /// Creates a texture layer bounded by [rect] and with backend texture
  /// identified by [textureId], if [freeze] is true new texture frames will not be
  /// populated to the texture, and use [filterQuality] to set layer's [FilterQuality].
  TextureLayer({
    required this.rect,
    required this.textureId,
    this.freeze = false,
    this.filterQuality = ui.FilterQuality.low,
  }) : assert(rect != null),
       assert(textureId != null);

  /// Bounding rectangle of this layer.
  final Rect rect;

  /// The identity of the backend texture.
  final int textureId;

  /// When true the texture will not be updated with new frames.
  ///
  /// This is used for resizing embedded Android views: when resizing there
  /// is a short period during which the framework cannot tell if the newest
  /// texture frame has the previous or new size, to workaround this the
  /// framework "freezes" the texture just before resizing the Android view and
  /// un-freezes it when it is certain that a frame with the new size is ready.
  final bool freeze;

  /// {@macro flutter.widgets.Texture.filterQuality}
  final ui.FilterQuality filterQuality;

  @override
  void addToScene(ui.SceneBuilder builder) {
    builder.addTexture(
      textureId,
      offset: rect.topLeft,
      width: rect.width,
      height: rect.height,
      freeze: freeze,
      filterQuality: filterQuality,
    );
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    return false;
  }
}

/// A layer that shows an embedded [UIView](https://developer.apple.com/documentation/uikit/uiview)
/// on iOS.
class PlatformViewLayer extends Layer {
  /// Creates a platform view layer.
  ///
  /// The `rect` and `viewId` parameters must not be null.
  PlatformViewLayer({
    required this.rect,
    required this.viewId,
  }) : assert(rect != null),
       assert(viewId != null);

  /// Bounding rectangle of this layer in the global coordinate space.
  final Rect rect;

  /// The unique identifier of the UIView displayed on this layer.
  ///
  /// A UIView with this identifier must have been created by [PlatformViewsService.initUiKitView].
  final int viewId;

  @override
  void addToScene(ui.SceneBuilder builder) {
    builder.addPlatformView(
      viewId,
      offset: rect.topLeft,
      width: rect.width,
      height: rect.height,
    );
  }
}

/// A layer that indicates to the compositor that it should display
/// certain performance statistics within it.
///
/// Performance overlay layers are always leaves in the layer tree.
class PerformanceOverlayLayer extends Layer {
  /// Creates a layer that displays a performance overlay.
  PerformanceOverlayLayer({
    required Rect overlayRect,
    required this.optionsMask,
    required this.rasterizerThreshold,
    required this.checkerboardRasterCacheImages,
    required this.checkerboardOffscreenLayers,
  }) : _overlayRect = overlayRect;

  /// The rectangle in this layer's coordinate system that the overlay should occupy.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  Rect get overlayRect => _overlayRect;
  Rect _overlayRect;
  set overlayRect(Rect value) {
    if (value != _overlayRect) {
      _overlayRect = value;
      markNeedsAddToScene();
    }
  }

  /// The mask is created by shifting 1 by the index of the specific
  /// [PerformanceOverlayOption] to enable.
  final int optionsMask;

  /// The rasterizer threshold is an integer specifying the number of frame
  /// intervals that the rasterizer must miss before it decides that the frame
  /// is suitable for capturing an SkPicture trace for further analysis.
  final int rasterizerThreshold;

  /// Whether the raster cache should checkerboard cached entries.
  ///
  /// The compositor can sometimes decide to cache certain portions of the
  /// widget hierarchy. Such portions typically don't change often from frame to
  /// frame and are expensive to render. This can speed up overall rendering. However,
  /// there is certain upfront cost to constructing these cache entries. And, if
  /// the cache entries are not used very often, this cost may not be worth the
  /// speedup in rendering of subsequent frames. If the developer wants to be certain
  /// that populating the raster cache is not causing stutters, this option can be
  /// set. Depending on the observations made, hints can be provided to the compositor
  /// that aid it in making better decisions about caching.
  final bool checkerboardRasterCacheImages;

  /// Whether the compositor should checkerboard layers that are rendered to offscreen
  /// bitmaps. This can be useful for debugging rendering performance.
  ///
  /// Render target switches are caused by using opacity layers (via a [FadeTransition] or
  /// [Opacity] widget), clips, shader mask layers, etc. Selecting a new render target
  /// and merging it with the rest of the scene has a performance cost. This can sometimes
  /// be avoided by using equivalent widgets that do not require these layers (for example,
  /// replacing an [Opacity] widget with an [widgets.Image] using a [BlendMode]).
  final bool checkerboardOffscreenLayers;

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(optionsMask != null);
    builder.addPerformanceOverlay(optionsMask, overlayRect);
    builder.setRasterizerTracingThreshold(rasterizerThreshold);
    builder.setCheckerboardRasterCacheImages(checkerboardRasterCacheImages);
    builder.setCheckerboardOffscreenLayers(checkerboardOffscreenLayers);
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    return false;
  }
}

/// A composited layer that has a list of children.
///
/// A [ContainerLayer] instance merely takes a list of children and inserts them
/// into the composited rendering in order. There are subclasses of
/// [ContainerLayer] which apply more elaborate effects in the process.
class ContainerLayer extends Layer {
  /// The first composited layer in this layer's child list.
  Layer? get firstChild => _firstChild;
  Layer? _firstChild;

  /// The last composited layer in this layer's child list.
  Layer? get lastChild => _lastChild;
  Layer? _lastChild;

  /// Returns whether this layer has at least one child layer.
  bool get hasChildren => _firstChild != null;

  /// Consider this layer as the root and build a scene (a tree of layers)
  /// in the engine.
  // The reason this method is in the `ContainerLayer` class rather than
  // `PipelineOwner` or other singleton level is because this method can be used
  // both to render the whole layer tree (e.g. a normal application frame) and
  // to render a subtree (e.g. `OffsetLayer.toImage`).
  ui.Scene buildScene(ui.SceneBuilder builder) {
    updateSubtreeNeedsAddToScene();
    addToScene(builder);
    // Clearing the flag _after_ calling `addToScene`, not _before_. This is
    // because `addToScene` calls children's `addToScene` methods, which may
    // mark this layer as dirty.
    _needsAddToScene = false;
    final ui.Scene scene = builder.build();
    return scene;
  }

  bool _debugUltimatePreviousSiblingOf(Layer child, { Layer? equals }) {
    assert(child.attached == attached);
    while (child.previousSibling != null) {
      assert(child.previousSibling != child);
      child = child.previousSibling!;
      assert(child.attached == attached);
    }
    return child == equals;
  }

  bool _debugUltimateNextSiblingOf(Layer child, { Layer? equals }) {
    assert(child.attached == attached);
    while (child._nextSibling != null) {
      assert(child._nextSibling != child);
      child = child._nextSibling!;
      assert(child.attached == attached);
    }
    return child == equals;
  }

  @override
  void dispose() {
    removeAllChildren();
    super.dispose();
  }

  @override
  void updateSubtreeNeedsAddToScene() {
    super.updateSubtreeNeedsAddToScene();
    Layer? child = firstChild;
    while (child != null) {
      child.updateSubtreeNeedsAddToScene();
      _needsAddToScene = _needsAddToScene || child._needsAddToScene;
      child = child.nextSibling;
    }
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    for (Layer? child = lastChild; child != null; child = child.previousSibling) {
      final bool isAbsorbed = child.findAnnotations<S>(result, localPosition, onlyFirst: onlyFirst);
      if (isAbsorbed)
        return true;
      if (onlyFirst && result.entries.isNotEmpty)
        return isAbsorbed;
    }
    return false;
  }

  @override
  void attach(Object owner) {
    super.attach(owner);
    Layer? child = firstChild;
    while (child != null) {
      child.attach(owner);
      child = child.nextSibling;
    }
  }

  @override
  void detach() {
    super.detach();
    Layer? child = firstChild;
    while (child != null) {
      child.detach();
      child = child.nextSibling;
    }
  }

  /// Adds the given layer to the end of this layer's child list.
  void append(Layer child) {
    assert(child != this);
    assert(child != firstChild);
    assert(child != lastChild);
    assert(child.parent == null);
    assert(!child.attached);
    assert(child.nextSibling == null);
    assert(child.previousSibling == null);
    assert(child._parentHandle.layer == null);
    assert(() {
      Layer node = this;
      while (node.parent != null)
        node = node.parent!;
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());
    adoptChild(child);
    child._previousSibling = lastChild;
    if (lastChild != null)
      lastChild!._nextSibling = child;
    _lastChild = child;
    _firstChild ??= child;
    child._parentHandle.layer = child;
    assert(child.attached == attached);
  }

  // Implementation of [Layer.remove].
  void _removeChild(Layer child) {
    assert(child.parent == this);
    assert(child.attached == attached);
    assert(_debugUltimatePreviousSiblingOf(child, equals: firstChild));
    assert(_debugUltimateNextSiblingOf(child, equals: lastChild));
    assert(child._parentHandle.layer != null);
    if (child._previousSibling == null) {
      assert(_firstChild == child);
      _firstChild = child._nextSibling;
    } else {
      child._previousSibling!._nextSibling = child.nextSibling;
    }
    if (child._nextSibling == null) {
      assert(lastChild == child);
      _lastChild = child.previousSibling;
    } else {
      child.nextSibling!._previousSibling = child.previousSibling;
    }
    assert((firstChild == null) == (lastChild == null));
    assert(firstChild == null || firstChild!.attached == attached);
    assert(lastChild == null || lastChild!.attached == attached);
    assert(firstChild == null || _debugUltimateNextSiblingOf(firstChild!, equals: lastChild));
    assert(lastChild == null || _debugUltimatePreviousSiblingOf(lastChild!, equals: firstChild));
    child._previousSibling = null;
    child._nextSibling = null;
    dropChild(child);
    child._parentHandle.layer = null;
    assert(!child.attached);
  }

  /// Removes all of this layer's children from its child list.
  void removeAllChildren() {
    Layer? child = firstChild;
    while (child != null) {
      final Layer? next = child.nextSibling;
      child._previousSibling = null;
      child._nextSibling = null;
      assert(child.attached == attached);
      dropChild(child);
      assert(child._parentHandle != null);
      child._parentHandle.layer = null;
      child = next;
    }
    _firstChild = null;
    _lastChild = null;
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    addChildrenToScene(builder);
  }

  /// Uploads all of this layer's children to the engine.
  ///
  /// This method is typically used by [addToScene] to insert the children into
  /// the scene. Subclasses of [ContainerLayer] typically override [addToScene]
  /// to apply effects to the scene using the [SceneBuilder] API, then insert
  /// their children using [addChildrenToScene], then reverse the aforementioned
  /// effects before returning from [addToScene].
  void addChildrenToScene(ui.SceneBuilder builder) {
    Layer? child = firstChild;
    while (child != null) {
      child._addToSceneWithRetainedRendering(builder);
      child = child.nextSibling;
    }
  }

  /// Applies the transform that would be applied when compositing the given
  /// child to the given matrix.
  ///
  /// Specifically, this should apply the transform that is applied to child's
  /// _origin_. When using [applyTransform] with a chain of layers, results will
  /// be unreliable unless the deepest layer in the chain collapses the
  /// `layerOffset` in [addToScene] to zero, meaning that it passes
  /// [Offset.zero] to its children, and bakes any incoming `layerOffset` into
  /// the [SceneBuilder] as (for instance) a transform (which is then also
  /// included in the transformation applied by [applyTransform]).
  ///
  /// For example, if [addToScene] applies the `layerOffset` and then
  /// passes [Offset.zero] to the children, then it should be included in the
  /// transform applied here, whereas if [addToScene] just passes the
  /// `layerOffset` to the child, then it should not be included in the
  /// transform applied here.
  ///
  /// This method is only valid immediately after [addToScene] has been called,
  /// before any of the properties have been changed.
  ///
  /// The default implementation does nothing, since [ContainerLayer], by
  /// default, composites its children at the origin of the [ContainerLayer]
  /// itself.
  ///
  /// The `child` argument should generally not be null, since in principle a
  /// layer could transform each child independently. However, certain layers
  /// may explicitly allow null as a value, for example if they know that they
  /// transform all their children identically.
  ///
  /// The `transform` argument must not be null.
  ///
  /// Used by [FollowerLayer] to transform its child to a [LeaderLayer]'s
  /// position.
  void applyTransform(Layer? child, Matrix4 transform) {
    assert(child != null);
    assert(transform != null);
  }

  /// Returns the descendants of this layer in depth first order.
  @visibleForTesting
  List<Layer> depthFirstIterateChildren() {
    if (firstChild == null)
      return <Layer>[];
    final List<Layer> children = <Layer>[];
    Layer? child = firstChild;
    while(child != null) {
      children.add(child);
      if (child is ContainerLayer) {
        children.addAll(child.depthFirstIterateChildren());
      }
      child = child.nextSibling;
    }
    return children;
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> children = <DiagnosticsNode>[];
    if (firstChild == null)
      return children;
    Layer? child = firstChild;
    int count = 1;
    while (true) {
      children.add(child!.toDiagnosticsNode(name: 'child $count'));
      if (child == lastChild)
        break;
      count += 1;
      child = child.nextSibling;
    }
    return children;
  }
}

/// A layer that is displayed at an offset from its parent layer.
///
/// Offset layers are key to efficient repainting because they are created by
/// repaint boundaries in the [RenderObject] tree (see
/// [RenderObject.isRepaintBoundary]). When a render object that is a repaint
/// boundary is asked to paint at given offset in a [PaintingContext], the
/// render object first checks whether it needs to repaint itself. If not, it
/// reuses its existing [OffsetLayer] (and its entire subtree) by mutating its
/// [offset] property, cutting off the paint walk.
class OffsetLayer extends ContainerLayer {
  /// Creates an offset layer.
  ///
  /// By default, [offset] is zero. It must be non-null before the compositing
  /// phase of the pipeline.
  OffsetLayer({ Offset offset = Offset.zero }) : _offset = offset;

  /// Offset from parent in the parent's coordinate system.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ///
  /// The [offset] property must be non-null before the compositing phase of the
  /// pipeline.
  Offset get offset => _offset;
  Offset _offset;
  set offset(Offset value) {
    if (value != _offset) {
      markNeedsAddToScene();
    }
    _offset = value;
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    return super.findAnnotations<S>(result, localPosition - offset, onlyFirst: onlyFirst);
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    assert(child != null);
    assert(transform != null);
    transform.multiply(Matrix4.translationValues(offset.dx, offset.dy, 0.0));
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    // Skia has a fast path for concatenating scale/translation only matrices.
    // Hence pushing a translation-only transform layer should be fast. For
    // retained rendering, we don't want to push the offset down to each leaf
    // node. Otherwise, changing an offset layer on the very high level could
    // cascade the change to too many leaves.
    engineLayer = builder.pushOffset(
      offset.dx,
      offset.dy,
      oldLayer: _engineLayer as ui.OffsetEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('offset', offset));
  }

  /// Capture an image of the current state of this layer and its children.
  ///
  /// The returned [ui.Image] has uncompressed raw RGBA bytes, will be offset
  /// by the top-left corner of [bounds], and have dimensions equal to the size
  /// of [bounds] multiplied by [pixelRatio].
  ///
  /// The [pixelRatio] describes the scale between the logical pixels and the
  /// size of the output image. It is independent of the
  /// [dart:ui.FlutterView.devicePixelRatio] for the device, so specifying 1.0
  /// (the default) will give you a 1:1 mapping between logical pixels and the
  /// output pixels in the image.
  ///
  /// See also:
  ///
  ///  * [RenderRepaintBoundary.toImage] for a similar API at the render object level.
  ///  * [dart:ui.Scene.toImage] for more information about the image returned.
  Future<ui.Image> toImage(Rect bounds, { double pixelRatio = 1.0 }) async {
    assert(bounds != null);
    assert(pixelRatio != null);
    final ui.SceneBuilder builder = ui.SceneBuilder();
    final Matrix4 transform = Matrix4.translationValues(
      (-bounds.left  - offset.dx) * pixelRatio,
      (-bounds.top - offset.dy) * pixelRatio,
      0.0,
    );
    transform.scale(pixelRatio, pixelRatio);
    builder.pushTransform(transform.storage);
    final ui.Scene scene = buildScene(builder);

    try {
      // Size is rounded up to the next pixel to make sure we don't clip off
      // anything.
      return await scene.toImage(
        (pixelRatio * bounds.width).ceil(),
        (pixelRatio * bounds.height).ceil(),
      );
    } finally {
      scene.dispose();
    }
  }
}

/// A composite layer that clips its children using a rectangle.
///
/// When debugging, setting [debugDisableClipLayers] to true will cause this
/// layer to be skipped (directly replaced by its children). This can be helpful
/// to track down the cause of performance problems.
class ClipRectLayer extends ContainerLayer {
  /// Creates a layer with a rectangular clip.
  ///
  /// The [clipRect] argument must not be null before the compositing phase of
  /// the pipeline.
  ///
  /// The [clipBehavior] argument must not be null, and must not be [Clip.none].
  ClipRectLayer({
    Rect? clipRect,
    Clip clipBehavior = Clip.hardEdge,
  }) : _clipRect = clipRect,
       _clipBehavior = clipBehavior,
       assert(clipBehavior != null),
       assert(clipBehavior != Clip.none);

  /// The rectangle to clip in the parent's coordinate system.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  Rect? get clipRect => _clipRect;
  Rect? _clipRect;
  set clipRect(Rect? value) {
    if (value != _clipRect) {
      _clipRect = value;
      markNeedsAddToScene();
    }
  }

  /// {@template flutter.rendering.ClipRectLayer.clipBehavior}
  /// Controls how to clip.
  ///
  /// Must not be set to null or [Clip.none].
  /// {@endtemplate}
  ///
  /// Defaults to [Clip.hardEdge].
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    assert(value != null);
    assert(value != Clip.none);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsAddToScene();
    }
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    if (!clipRect!.contains(localPosition))
      return false;
    return super.findAnnotations<S>(result, localPosition, onlyFirst: onlyFirst);
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(clipRect != null);
    assert(clipBehavior != null);
    bool enabled = true;
    assert(() {
      enabled = !debugDisableClipLayers;
      return true;
    }());
    if (enabled) {
      engineLayer = builder.pushClipRect(
        clipRect!,
        clipBehavior: clipBehavior,
        oldLayer: _engineLayer as ui.ClipRectEngineLayer?,
      );
    } else {
      engineLayer = null;
    }
    addChildrenToScene(builder);
    if (enabled)
      builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Rect>('clipRect', clipRect));
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior));
  }
}

/// A composite layer that clips its children using a rounded rectangle.
///
/// When debugging, setting [debugDisableClipLayers] to true will cause this
/// layer to be skipped (directly replaced by its children). This can be helpful
/// to track down the cause of performance problems.
class ClipRRectLayer extends ContainerLayer {
  /// Creates a layer with a rounded-rectangular clip.
  ///
  /// The [clipRRect] and [clipBehavior] properties must be non-null before the
  /// compositing phase of the pipeline.
  ClipRRectLayer({
    RRect? clipRRect,
    Clip clipBehavior = Clip.antiAlias,
  }) : _clipRRect = clipRRect,
       _clipBehavior = clipBehavior,
       assert(clipBehavior != null),
       assert(clipBehavior != Clip.none);

  /// The rounded-rect to clip in the parent's coordinate system.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  RRect? get clipRRect => _clipRRect;
  RRect? _clipRRect;
  set clipRRect(RRect? value) {
    if (value != _clipRRect) {
      _clipRRect = value;
      markNeedsAddToScene();
    }
  }

  /// {@macro flutter.rendering.ClipRectLayer.clipBehavior}
  ///
  /// Defaults to [Clip.antiAlias].
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    assert(value != null);
    assert(value != Clip.none);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsAddToScene();
    }
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    if (!clipRRect!.contains(localPosition))
      return false;
    return super.findAnnotations<S>(result, localPosition, onlyFirst: onlyFirst);
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(clipRRect != null);
    assert(clipBehavior != null);
    bool enabled = true;
    assert(() {
      enabled = !debugDisableClipLayers;
      return true;
    }());
    if (enabled) {
      engineLayer = builder.pushClipRRect(
        clipRRect!,
        clipBehavior: clipBehavior,
        oldLayer: _engineLayer as ui.ClipRRectEngineLayer?,
      );
    } else {
      engineLayer = null;
    }
    addChildrenToScene(builder);
    if (enabled)
      builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<RRect>('clipRRect', clipRRect));
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior));
  }
}

/// A composite layer that clips its children using a path.
///
/// When debugging, setting [debugDisableClipLayers] to true will cause this
/// layer to be skipped (directly replaced by its children). This can be helpful
/// to track down the cause of performance problems.
class ClipPathLayer extends ContainerLayer {
  /// Creates a layer with a path-based clip.
  ///
  /// The [clipPath] and [clipBehavior] properties must be non-null before the
  /// compositing phase of the pipeline.
  ClipPathLayer({
    Path? clipPath,
    Clip clipBehavior = Clip.antiAlias,
  }) : _clipPath = clipPath,
       _clipBehavior = clipBehavior,
       assert(clipBehavior != null),
       assert(clipBehavior != Clip.none);

  /// The path to clip in the parent's coordinate system.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  Path? get clipPath => _clipPath;
  Path? _clipPath;
  set clipPath(Path? value) {
    if (value != _clipPath) {
      _clipPath = value;
      markNeedsAddToScene();
    }
  }

  /// {@macro flutter.rendering.ClipRectLayer.clipBehavior}
  ///
  /// Defaults to [Clip.antiAlias].
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    assert(value != null);
    assert(value != Clip.none);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsAddToScene();
    }
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    if (!clipPath!.contains(localPosition))
      return false;
    return super.findAnnotations<S>(result, localPosition, onlyFirst: onlyFirst);
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(clipPath != null);
    assert(clipBehavior != null);
    bool enabled = true;
    assert(() {
      enabled = !debugDisableClipLayers;
      return true;
    }());
    if (enabled) {
      engineLayer = builder.pushClipPath(
        clipPath!,
        clipBehavior: clipBehavior,
        oldLayer: _engineLayer as ui.ClipPathEngineLayer?,
      );
    } else {
      engineLayer = null;
    }
    addChildrenToScene(builder);
    if (enabled)
      builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior));
  }
}

/// A composite layer that applies a [ColorFilter] to its children.
class ColorFilterLayer extends ContainerLayer {
  /// Creates a layer that applies a [ColorFilter] to its children.
  ///
  /// The [colorFilter] property must be non-null before the compositing phase
  /// of the pipeline.
  ColorFilterLayer({
    ColorFilter? colorFilter,
  }) : _colorFilter = colorFilter;

  /// The color filter to apply to children.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ColorFilter? get colorFilter => _colorFilter;
  ColorFilter? _colorFilter;
  set colorFilter(ColorFilter? value) {
    assert(value != null);
    if (value != _colorFilter) {
      _colorFilter = value;
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(colorFilter != null);
    engineLayer = builder.pushColorFilter(
      colorFilter!,
      oldLayer: _engineLayer as ui.ColorFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ColorFilter>('colorFilter', colorFilter));
  }
}

/// A composite layer that applies an [ImageFilter] to its children.
class ImageFilterLayer extends ContainerLayer {
  /// Creates a layer that applies an [ImageFilter] to its children.
  ///
  /// The [imageFilter] property must be non-null before the compositing phase
  /// of the pipeline.
  ImageFilterLayer({
    ui.ImageFilter? imageFilter,
  }) : _imageFilter = imageFilter;

  /// The image filter to apply to children.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ui.ImageFilter? get imageFilter => _imageFilter;
  ui.ImageFilter? _imageFilter;
  set imageFilter(ui.ImageFilter? value) {
    assert(value != null);
    if (value != _imageFilter) {
      _imageFilter = value;
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(imageFilter != null);
    engineLayer = builder.pushImageFilter(
      imageFilter!,
      oldLayer: _engineLayer as ui.ImageFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ui.ImageFilter>('imageFilter', imageFilter));
  }
}

/// A composited layer that applies a given transformation matrix to its
/// children.
///
/// This class inherits from [OffsetLayer] to make it one of the layers that
/// can be used at the root of a [RenderObject] hierarchy.
class TransformLayer extends OffsetLayer {
  /// Creates a transform layer.
  ///
  /// The [transform] and [offset] properties must be non-null before the
  /// compositing phase of the pipeline.
  TransformLayer({ Matrix4? transform, Offset offset = Offset.zero })
    : _transform = transform,
      super(offset: offset);

  /// The matrix to apply.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ///
  /// This transform is applied before [offset], if both are set.
  ///
  /// The [transform] property must be non-null before the compositing phase of
  /// the pipeline.
  Matrix4? get transform => _transform;
  Matrix4? _transform;
  set transform(Matrix4? value) {
    assert(value != null);
    assert(value!.storage.every((double component) => component.isFinite));
    if (value == _transform)
      return;
    _transform = value;
    _inverseDirty = true;
    markNeedsAddToScene();
  }

  Matrix4? _lastEffectiveTransform;
  Matrix4? _invertedTransform;
  bool _inverseDirty = true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(transform != null);
    _lastEffectiveTransform = transform;
    if (offset != Offset.zero) {
      _lastEffectiveTransform = Matrix4.translationValues(offset.dx, offset.dy, 0.0)
        ..multiply(_lastEffectiveTransform!);
    }
    engineLayer = builder.pushTransform(
      _lastEffectiveTransform!.storage,
      oldLayer: _engineLayer as ui.TransformEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  Offset? _transformOffset(Offset localPosition) {
    if (_inverseDirty) {
      _invertedTransform = Matrix4.tryInvert(
        PointerEvent.removePerspectiveTransform(transform!),
      );
      _inverseDirty = false;
    }
    if (_invertedTransform == null)
      return null;

    return MatrixUtils.transformPoint(_invertedTransform!, localPosition);
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    final Offset? transformedOffset = _transformOffset(localPosition);
    if (transformedOffset == null)
      return false;
    return super.findAnnotations<S>(result, transformedOffset, onlyFirst: onlyFirst);
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    assert(child != null);
    assert(transform != null);
    assert(_lastEffectiveTransform != null || this.transform != null);
    if (_lastEffectiveTransform == null) {
      transform.multiply(this.transform!);
    } else {
      transform.multiply(_lastEffectiveTransform!);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(TransformProperty('transform', transform));
  }
}

/// A composited layer that makes its children partially transparent.
///
/// When debugging, setting [debugDisableOpacityLayers] to true will cause this
/// layer to be skipped (directly replaced by its children). This can be helpful
/// to track down the cause of performance problems.
///
/// Try to avoid an [OpacityLayer] with no children. Remove that layer if
/// possible to save some tree walks.
class OpacityLayer extends OffsetLayer {
  /// Creates an opacity layer.
  ///
  /// The [alpha] property must be non-null before the compositing phase of
  /// the pipeline.
  OpacityLayer({
    int? alpha,
    Offset offset = Offset.zero,
  }) : _alpha = alpha,
       super(offset: offset);

  /// The amount to multiply into the alpha channel.
  ///
  /// The opacity is expressed as an integer from 0 to 255, where 0 is fully
  /// transparent and 255 is fully opaque.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  int? get alpha => _alpha;
  int? _alpha;
  set alpha(int? value) {
    assert(value != null);
    if (value != _alpha) {
      if (value == 255 || _alpha == 255) {
        engineLayer = null;
      }
      _alpha = value;
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(alpha != null);
    bool enabled = firstChild != null;  // don't add this layer if there's no child
    if (!enabled) {
      // TODO(dnfield): Remove this if/when we can fix https://github.com/flutter/flutter/issues/90004
      return;
    }
    assert(() {
      enabled = enabled && !debugDisableOpacityLayers;
      return true;
    }());

    final int realizedAlpha = alpha!;
    // The type assertions work because the [alpha] setter nulls out the
    // engineLayer if it would have changed type (i.e. changed to or from 255).
    if (enabled && realizedAlpha < 255) {
      assert(_engineLayer is ui.OpacityEngineLayer?);
      engineLayer = builder.pushOpacity(
        realizedAlpha,
        offset: offset,
        oldLayer: _engineLayer as ui.OpacityEngineLayer?,
      );
    } else {
      assert(_engineLayer is ui.OffsetEngineLayer?);
      engineLayer = builder.pushOffset(
        offset.dx,
        offset.dy,
        oldLayer: _engineLayer as ui.OffsetEngineLayer?,
      );
    }
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('alpha', alpha));
  }
}

/// A composited layer that applies a shader to its children.
///
/// The shader is only applied inside the given [maskRect]. The shader itself
/// uses the top left of the [maskRect] as its origin.
///
/// The [maskRect] does not affect the positions of any child layers.
class ShaderMaskLayer extends ContainerLayer {
  /// Creates a shader mask layer.
  ///
  /// The [shader], [maskRect], and [blendMode] properties must be non-null
  /// before the compositing phase of the pipeline.
  ShaderMaskLayer({
    Shader? shader,
    Rect? maskRect,
    BlendMode? blendMode,
  }) : _shader = shader,
       _maskRect = maskRect,
       _blendMode = blendMode;

  /// The shader to apply to the children.
  ///
  /// The origin of the shader (e.g. of the coordinate system used by the `from`
  /// and `to` arguments to [ui.Gradient.linear]) is at the top left of the
  /// [maskRect].
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ///
  /// See also:
  ///
  ///  * [ui.Gradient] and [ui.ImageShader], two shader types that can be used.
  Shader? get shader => _shader;
  Shader? _shader;
  set shader(Shader? value) {
    if (value != _shader) {
      _shader = value;
      markNeedsAddToScene();
    }
  }

  /// The position and size of the shader.
  ///
  /// The [shader] is only rendered inside this rectangle, using the top left of
  /// the rectangle as its origin.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  Rect? get maskRect => _maskRect;
  Rect? _maskRect;
  set maskRect(Rect? value) {
    if (value != _maskRect) {
      _maskRect = value;
      markNeedsAddToScene();
    }
  }

  /// The blend mode to apply when blending the shader with the children.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  BlendMode? get blendMode => _blendMode;
  BlendMode? _blendMode;
  set blendMode(BlendMode? value) {
    if (value != _blendMode) {
      _blendMode = value;
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(shader != null);
    assert(maskRect != null);
    assert(blendMode != null);
    engineLayer = builder.pushShaderMask(
      shader!,
      maskRect! ,
      blendMode!,
      oldLayer: _engineLayer as ui.ShaderMaskEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Shader>('shader', shader));
    properties.add(DiagnosticsProperty<Rect>('maskRect', maskRect));
    properties.add(DiagnosticsProperty<BlendMode>('blendMode', blendMode));
  }
}

/// A composited layer that applies a filter to the existing contents of the scene.
class BackdropFilterLayer extends ContainerLayer {
  /// Creates a backdrop filter layer.
  ///
  /// The [filter] property must be non-null before the compositing phase of the
  /// pipeline.
  ///
  /// The [blendMode] property defaults to [BlendMode.srcOver].
  BackdropFilterLayer({
    ui.ImageFilter? filter,
    BlendMode blendMode = BlendMode.srcOver,
  }) : _filter = filter,
       _blendMode = blendMode;

  /// The filter to apply to the existing contents of the scene.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ui.ImageFilter? get filter => _filter;
  ui.ImageFilter? _filter;
  set filter(ui.ImageFilter? value) {
    if (value != _filter) {
      _filter = value;
      markNeedsAddToScene();
    }
  }

  /// The blend mode to use to apply the filtered background content onto the background
  /// surface.
  ///
  /// The default value of this property is [BlendMode.srcOver].
  /// {@macro flutter.widgets.BackdropFilter.blendMode}
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  BlendMode get blendMode => _blendMode;
  BlendMode _blendMode;
  set blendMode(BlendMode value) {
    if (value != _blendMode) {
      _blendMode = value;
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(filter != null);
    engineLayer = builder.pushBackdropFilter(
      filter!,
      blendMode: blendMode,
      oldLayer: _engineLayer as ui.BackdropFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }
}

/// A composited layer that uses a physical model to producing lighting effects.
///
/// For example, the layer casts a shadow according to its geometry and the
/// relative position of lights and other physically modeled objects in the
/// scene.
///
/// When debugging, setting [debugDisablePhysicalShapeLayers] to true will cause this
/// layer to be skipped (directly replaced by its children). This can be helpful
/// to track down the cause of performance problems.
class PhysicalModelLayer extends ContainerLayer {
  /// Creates a composited layer that uses a physical model to producing
  /// lighting effects.
  ///
  /// The [clipPath], [clipBehavior], [elevation], [color], and [shadowColor]
  /// arguments must be non-null before the compositing phase of the pipeline.
  PhysicalModelLayer({
    Path? clipPath,
    Clip clipBehavior = Clip.none,
    double? elevation,
    Color? color,
    Color? shadowColor,
  }) : _clipPath = clipPath,
       _clipBehavior = clipBehavior,
       _elevation = elevation,
       _color = color,
       _shadowColor = shadowColor;

  /// The path to clip in the parent's coordinate system.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  Path? get clipPath => _clipPath;
  Path? _clipPath;
  set clipPath(Path? value) {
    if (value != _clipPath) {
      _clipPath = value;
      markNeedsAddToScene();
    }
  }

  /// {@macro flutter.material.Material.clipBehavior}
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    assert(value != null);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsAddToScene();
    }
  }

  /// The z-coordinate at which to place this physical object.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ///
  /// In tests, the [debugDisableShadows] flag is set to true by default.
  /// Several widgets and render objects force all elevations to zero when this
  /// flag is set. For this reason, this property will often be set to zero in
  /// tests even if the layer should be raised. To verify the actual value,
  /// consider setting [debugDisableShadows] to false in your test.
  double? get elevation => _elevation;
  double? _elevation;
  set elevation(double? value) {
    if (value != _elevation) {
      _elevation = value;
      markNeedsAddToScene();
    }
  }

  /// The background color.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  Color? get color => _color;
  Color? _color;
  set color(Color? value) {
    if (value != _color) {
      _color = value;
      markNeedsAddToScene();
    }
  }

  /// The shadow color.
  Color? get shadowColor => _shadowColor;
  Color? _shadowColor;
  set shadowColor(Color? value) {
    if (value != _shadowColor) {
      _shadowColor = value;
      markNeedsAddToScene();
    }
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    if (!clipPath!.contains(localPosition))
      return false;
    return super.findAnnotations<S>(result, localPosition, onlyFirst: onlyFirst);
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(clipPath != null);
    assert(clipBehavior != null);
    assert(elevation != null);
    assert(color != null);
    assert(shadowColor != null);

    bool enabled = true;
    assert(() {
      enabled = !debugDisablePhysicalShapeLayers;
      return true;
    }());
    if (enabled) {
      engineLayer = builder.pushPhysicalShape(
        path: clipPath!,
        elevation: elevation!,
        color: color!,
        shadowColor: shadowColor,
        clipBehavior: clipBehavior,
        oldLayer: _engineLayer as ui.PhysicalShapeEngineLayer?,
      );
    } else {
      engineLayer = null;
    }
    addChildrenToScene(builder);
    if (enabled)
      builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('elevation', elevation));
    properties.add(ColorProperty('color', color));
  }
}

/// An object that a [LeaderLayer] can register with.
///
/// An instance of this class should be provided as the [LeaderLayer.link] and
/// the [FollowerLayer.link] properties to cause the [FollowerLayer] to follow
/// the [LeaderLayer].
///
/// See also:
///
///  * [CompositedTransformTarget], the widget that creates a [LeaderLayer].
///  * [CompositedTransformFollower], the widget that creates a [FollowerLayer].
///  * [RenderLeaderLayer] and [RenderFollowerLayer], the corresponding
///    render objects.
class LayerLink {
  LeaderLayer? _leader;

  int _connectedFollowers = 0;

  /// Whether a [LeaderLayer] is currently connected to this link.
  ///
  /// The connected [LeaderLayer] can be obtained from the [LayerLinkHandle]
  /// returned by [registerFollower].
  bool get leaderConnected => _leader != null;

  /// Called by the [FollowerLayer] to establish a link to a [LeaderLayer].
  ///
  /// The returned [LayerLinkHandle] provides access to the leader via
  /// [LayerLinkHandle.leader].
  ///
  /// When the [FollowerLayer] no longer wants to follow the [LeaderLayer],
  /// [LayerLinkHandle.dispose] must be called to disconnect the link.
  LayerLinkHandle registerFollower() {
    assert(_connectedFollowers >= 0);
    _connectedFollowers++;
    return LayerLinkHandle._(this);
  }

  /// Returns the [LeaderLayer] currently connected to this link.
  ///
  /// Valid in debug mode only. Returns null in all other modes.
  ///
  /// Use [registerFollower] to obtain the connected [LeaderLayer] for non-debug
  /// purposes.
  LeaderLayer? get debugLeader {
    LeaderLayer? result;
    if (kDebugMode) {
      result = _leader;
    }
    return result;
  }

  /// The total size of the content of the connected [LeaderLayer].
  ///
  /// Generally this should be set by the [RenderObject] that paints on the
  /// registered [LeaderLayer] (for instance a [RenderLeaderLayer] that shares
  /// this link with its followers). This size may be outdated before and during
  /// layout.
  Size? leaderSize;

  @override
  String toString() => '${describeIdentity(this)}(${ _leader != null ? "<linked>" : "<dangling>" })';
}

/// A handle provided by [LayerLink.registerFollower] to a calling
/// [FollowerLayer] to establish a link between that [FollowerLayer] and a
/// [LeaderLayer].
///
/// If the link is no longer needed, [dispose] must be called to disconnect it.
class LayerLinkHandle {
  LayerLinkHandle._(this._link);

  LayerLink? _link;

  /// The currently-registered [LeaderLayer], if any.
  LeaderLayer? get leader => _link!._leader;

  /// Disconnects the link between the [FollowerLayer] owning this handle and
  /// the [leader].
  ///
  /// The [LayerLinkHandle] becomes unusable after calling this method.
  void dispose() {
    assert(_link!._connectedFollowers > 0);
    _link!._connectedFollowers--;
    _link = null;
  }
}

/// A composited layer that can be followed by a [FollowerLayer].
///
/// This layer collapses the accumulated offset into a transform and passes
/// [Offset.zero] to its child layers in the [addToScene]/[addChildrenToScene]
/// methods, so that [applyTransform] will work reliably.
class LeaderLayer extends ContainerLayer {
  /// Creates a leader layer.
  ///
  /// The [link] property must not be null, and must not have been provided to
  /// any other [LeaderLayer] layers that are [attached] to the layer tree at
  /// the same time.
  ///
  /// The [offset] property must be non-null before the compositing phase of the
  /// pipeline.
  LeaderLayer({ required LayerLink link, Offset offset = Offset.zero }) : assert(link != null), _link = link, _offset = offset;

  /// The object with which this layer should register.
  ///
  /// The link will be established when this layer is [attach]ed, and will be
  /// cleared when this layer is [detach]ed.
  LayerLink get link => _link;
  LayerLink _link;
  set link(LayerLink value) {
    assert(value != null);
    if (_link == value) {
      return;
    }
    _link._leader = null;
    _link = value;
  }

  /// Offset from parent in the parent's coordinate system.
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ///
  /// The [offset] property must be non-null before the compositing phase of the
  /// pipeline.
  Offset get offset => _offset;
  Offset _offset;
  set offset(Offset value) {
    assert(value != null);
    if (value == _offset) {
      return;
    }
    _offset = value;
    if (!alwaysNeedsAddToScene) {
      markNeedsAddToScene();
    }
  }

  /// {@macro flutter.rendering.FollowerLayer.alwaysNeedsAddToScene}
  @override
  bool get alwaysNeedsAddToScene => _link._connectedFollowers > 0;

  @override
  void attach(Object owner) {
    super.attach(owner);
    assert(link._leader == null);
    _lastOffset = null;
    link._leader = this;
  }

  @override
  void detach() {
    assert(link._leader == this);
    link._leader = null;
    _lastOffset = null;
    super.detach();
  }

  /// The offset the last time this layer was composited.
  ///
  /// This is reset to null when the layer is attached or detached, to help
  /// catch cases where the follower layer ends up before the leader layer, but
  /// not every case can be detected.
  Offset? _lastOffset;

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    return super.findAnnotations<S>(result, localPosition - offset, onlyFirst: onlyFirst);
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(offset != null);
    _lastOffset = offset;
    if (_lastOffset != Offset.zero)
      engineLayer = builder.pushTransform(
        Matrix4.translationValues(_lastOffset!.dx, _lastOffset!.dy, 0.0).storage,
        oldLayer: _engineLayer as ui.TransformEngineLayer?,
      );
    addChildrenToScene(builder);
    if (_lastOffset != Offset.zero)
      builder.pop();
  }

  /// Applies the transform that would be applied when compositing the given
  /// child to the given matrix.
  ///
  /// See [ContainerLayer.applyTransform] for details.
  ///
  /// The `child` argument may be null, as the same transform is applied to all
  /// children.
  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    assert(_lastOffset != null);
    if (_lastOffset != Offset.zero)
      transform.translate(_lastOffset!.dx, _lastOffset!.dy);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('offset', offset));
    properties.add(DiagnosticsProperty<LayerLink>('link', link));
  }
}

/// A composited layer that applies a transformation matrix to its children such
/// that they are positioned to match a [LeaderLayer].
///
/// If any of the ancestors of this layer have a degenerate matrix (e.g. scaling
/// by zero), then the [FollowerLayer] will not be able to transform its child
/// to the coordinate space of the [LeaderLayer].
///
/// A [linkedOffset] property can be provided to further offset the child layer
/// from the leader layer, for example if the child is to follow the linked
/// layer at a distance rather than directly overlapping it.
class FollowerLayer extends ContainerLayer {
  /// Creates a follower layer.
  ///
  /// The [link] property must not be null.
  ///
  /// The [unlinkedOffset], [linkedOffset], and [showWhenUnlinked] properties
  /// must be non-null before the compositing phase of the pipeline.
  FollowerLayer({
    required LayerLink link,
    this.showWhenUnlinked = true,
    this.unlinkedOffset = Offset.zero,
    this.linkedOffset = Offset.zero,
  }) : assert(link != null), _link = link;

  /// The link to the [LeaderLayer].
  ///
  /// The same object should be provided to a [LeaderLayer] that is earlier in
  /// the layer tree. When this layer is composited, it will apply a transform
  /// that moves its children to match the position of the [LeaderLayer].
  LayerLink get link => _link;
  set link(LayerLink value) {
    assert(value != null);
    if (value != _link && _leaderHandle != null) {
      _leaderHandle!.dispose();
      _leaderHandle = value.registerFollower();
    }
    _link = value;
  }
  LayerLink _link;

  /// Whether to show the layer's contents when the [link] does not point to a
  /// [LeaderLayer].
  ///
  /// When the layer is linked, children layers are positioned such that they
  /// have the same global position as the linked [LeaderLayer].
  ///
  /// When the layer is not linked, then: if [showWhenUnlinked] is true,
  /// children are positioned as if the [FollowerLayer] was a [ContainerLayer];
  /// if it is false, then children are hidden.
  ///
  /// The [showWhenUnlinked] property must be non-null before the compositing
  /// phase of the pipeline.
  bool? showWhenUnlinked;

  /// Offset from parent in the parent's coordinate system, used when the layer
  /// is not linked to a [LeaderLayer].
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ///
  /// The [unlinkedOffset] property must be non-null before the compositing
  /// phase of the pipeline.
  ///
  /// See also:
  ///
  ///  * [linkedOffset], for when the layers are linked.
  Offset? unlinkedOffset;

  /// Offset from the origin of the leader layer to the origin of the child
  /// layers, used when the layer is linked to a [LeaderLayer].
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ///
  /// The [linkedOffset] property must be non-null before the compositing phase
  /// of the pipeline.
  ///
  /// See also:
  ///
  ///  * [unlinkedOffset], for when the layer is not linked.
  Offset? linkedOffset;

  LayerLinkHandle? _leaderHandle;

  @override
  void attach(Object owner) {
    super.attach(owner);
    _leaderHandle = _link.registerFollower();
  }

  @override
  void detach() {
    super.detach();
    _leaderHandle?.dispose();
    _leaderHandle = null;
  }

  Offset? _lastOffset;
  Matrix4? _lastTransform;
  Matrix4? _invertedTransform;
  bool _inverseDirty = true;

  Offset? _transformOffset(Offset localPosition) {
    if (_inverseDirty) {
      _invertedTransform = Matrix4.tryInvert(getLastTransform()!);
      _inverseDirty = false;
    }
    if (_invertedTransform == null)
      return null;
    final Vector4 vector = Vector4(localPosition.dx, localPosition.dy, 0.0, 1.0);
    final Vector4 result = _invertedTransform!.transform(vector);
    return Offset(result[0] - linkedOffset!.dx, result[1] - linkedOffset!.dy);
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    if (_leaderHandle!.leader == null) {
      if (showWhenUnlinked!) {
        return super.findAnnotations(result, localPosition - unlinkedOffset!, onlyFirst: onlyFirst);
      }
      return false;
    }
    final Offset? transformedOffset = _transformOffset(localPosition);
    if (transformedOffset == null) {
      return false;
    }
    return super.findAnnotations<S>(result, transformedOffset, onlyFirst: onlyFirst);
  }

  /// The transform that was used during the last composition phase.
  ///
  /// If the [link] was not linked to a [LeaderLayer], or if this layer has
  /// a degenerate matrix applied, then this will be null.
  ///
  /// This method returns a new [Matrix4] instance each time it is invoked.
  Matrix4? getLastTransform() {
    if (_lastTransform == null)
      return null;
    final Matrix4 result = Matrix4.translationValues(-_lastOffset!.dx, -_lastOffset!.dy, 0.0);
    result.multiply(_lastTransform!);
    return result;
  }

  /// Call [applyTransform] for each layer in the provided list.
  ///
  /// The list is in reverse order (deepest first). The first layer will be
  /// treated as the child of the second, and so forth. The first layer in the
  /// list won't have [applyTransform] called on it. The first layer may be
  /// null.
  static Matrix4 _collectTransformForLayerChain(List<ContainerLayer?> layers) {
    // Initialize our result matrix.
    final Matrix4 result = Matrix4.identity();
    // Apply each layer to the matrix in turn, starting from the last layer,
    // and providing the previous layer as the child.
    for (int index = layers.length - 1; index > 0; index -= 1)
      layers[index]?.applyTransform(layers[index - 1], result);
    return result;
  }

  /// Find the common ancestor of two layers [a] and [b] by searching towards
  /// the root of the tree, and append each ancestor of [a] or [b] visited along
  /// the path to [ancestorsA] and [ancestorsB] respectively.
  ///
  /// Returns null if [a] [b] do not share a common ancestor, in which case the
  /// results in [ancestorsA] and [ancestorsB] are undefined.
  static Layer? _pathsToCommonAncestor(
    Layer? a,
    Layer? b,
    List<ContainerLayer?> ancestorsA,
    List<ContainerLayer?> ancestorsB,
  ) {
    // No common ancestor found.
    if (a == null || b == null)
      return null;

    if (identical(a, b))
      return a;

    if (a.depth < b.depth) {
      ancestorsB.add(b.parent);
      return _pathsToCommonAncestor(a, b.parent, ancestorsA, ancestorsB);
    } else if (a.depth > b.depth) {
      ancestorsA.add(a.parent);
      return _pathsToCommonAncestor(a.parent, b, ancestorsA, ancestorsB);
    }

    ancestorsA.add(a.parent);
    ancestorsB.add(b.parent);
    return _pathsToCommonAncestor(a.parent, b.parent, ancestorsA, ancestorsB);
  }

  /// Populate [_lastTransform] given the current state of the tree.
  void _establishTransform() {
    assert(link != null);
    _lastTransform = null;
    final LeaderLayer? leader = _leaderHandle!.leader;
    // Check to see if we are linked.
    if (leader == null)
      return;
    // If we're linked, check the link is valid.
    assert(
      leader.owner == owner,
      'Linked LeaderLayer anchor is not in the same layer tree as the FollowerLayer.',
    );
    assert(
      leader._lastOffset != null,
      'LeaderLayer anchor must come before FollowerLayer in paint order, but the reverse was true.',
    );

    // Stores [leader, ..., commonAncestor] after calling _pathsToCommonAncestor.
    final List<ContainerLayer?> forwardLayers = <ContainerLayer>[leader];
    // Stores [this (follower), ..., commonAncestor] after calling
    // _pathsToCommonAncestor.
    final List<ContainerLayer?> inverseLayers = <ContainerLayer>[this];

    final Layer? ancestor = _pathsToCommonAncestor(
      leader, this,
      forwardLayers, inverseLayers,
    );
    assert(ancestor != null);

    final Matrix4 forwardTransform = _collectTransformForLayerChain(forwardLayers);
    // Further transforms the coordinate system to a hypothetical child (null)
    // of the leader layer, to account for the leader's additional paint offset
    // and layer offset (LeaderLayer._lastOffset).
    leader.applyTransform(null, forwardTransform);
    forwardTransform.translate(linkedOffset!.dx, linkedOffset!.dy);

    final Matrix4 inverseTransform = _collectTransformForLayerChain(inverseLayers);

    if (inverseTransform.invert() == 0.0) {
      // We are in a degenerate transform, so there's not much we can do.
      return;
    }
    // Combine the matrices and store the result.
    inverseTransform.multiply(forwardTransform);
    _lastTransform = inverseTransform;
    _inverseDirty = true;
  }

  /// {@template flutter.rendering.FollowerLayer.alwaysNeedsAddToScene}
  /// This disables retained rendering.
  ///
  /// A [FollowerLayer] copies changes from a [LeaderLayer] that could be anywhere
  /// in the Layer tree, and that leader layer could change without notifying the
  /// follower layer. Therefore we have to always call a follower layer's
  /// [addToScene]. In order to call follower layer's [addToScene], leader layer's
  /// [addToScene] must be called first so leader layer must also be considered
  /// as [alwaysNeedsAddToScene].
  /// {@endtemplate}
  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(link != null);
    assert(showWhenUnlinked != null);
    if (_leaderHandle!.leader == null && !showWhenUnlinked!) {
      _lastTransform = null;
      _lastOffset = null;
      _inverseDirty = true;
      engineLayer = null;
      return;
    }
    _establishTransform();
    if (_lastTransform != null) {
      engineLayer = builder.pushTransform(
        _lastTransform!.storage,
        oldLayer: _engineLayer as ui.TransformEngineLayer?,
      );
      addChildrenToScene(builder);
      builder.pop();
      _lastOffset = unlinkedOffset;
    } else {
      _lastOffset = null;
      final Matrix4 matrix = Matrix4.translationValues(unlinkedOffset!.dx, unlinkedOffset!.dy, .0);
      engineLayer = builder.pushTransform(
        matrix.storage,
        oldLayer: _engineLayer as ui.TransformEngineLayer?,
      );
      addChildrenToScene(builder);
      builder.pop();
    }
    _inverseDirty = true;
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    assert(child != null);
    assert(transform != null);
    if (_lastTransform != null) {
      transform.multiply(_lastTransform!);
    } else {
      transform.multiply(Matrix4.translationValues(unlinkedOffset!.dx, unlinkedOffset!.dy, 0));
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LayerLink>('link', link));
    properties.add(TransformProperty('transform', getLastTransform(), defaultValue: null));
  }
}

/// A composited layer which annotates its children with a value. Pushing this
/// layer to the tree is the common way of adding an annotation.
///
/// An annotation is an optional object of any type that, when attached with a
/// layer, can be retrieved using [Layer.find] or [Layer.findAllAnnotations]
/// with a position. The search process is done recursively, controlled by a
/// concept of being opaque to a type of annotation, explained in the document
/// of [Layer.findAnnotations].
///
/// When an annotation search arrives, this layer defers the same search to each
/// of this layer's children, respecting their opacity. Then it adds this
/// layer's annotation if all of the following restrictions are met:
///
/// {@template flutter.rendering.AnnotatedRegionLayer.restrictions}
/// * The target type must be identical to the annotated type `T`.
/// * If [size] is provided, the target position must be contained within the
///   rectangle formed by [size] and [offset].
/// {@endtemplate}
///
/// This layer is opaque to a type of annotation if any child is also opaque, or
/// if [opaque] is true and the layer's annotation is added.
class AnnotatedRegionLayer<T extends Object> extends ContainerLayer {
  /// Creates a new layer that annotates its children with [value].
  ///
  /// The [value] provided cannot be null.
  AnnotatedRegionLayer(
    this.value, {
    this.size,
    Offset? offset,
    this.opaque = false,
  }) : assert(value != null),
       assert(opaque != null),
       offset = offset ?? Offset.zero;

  /// The annotated object, which is added to the result if all restrictions are
  /// met.
  final T value;

  /// The size of the annotated object.
  ///
  /// If [size] is provided, then the annotation is found only if the target
  /// position is contained by the rectangle formed by [size] and [offset].
  /// Otherwise no such restriction is applied, and clipping can only be done by
  /// the ancestor layers.
  final Size? size;

  /// The position of the annotated object.
  ///
  /// The [offset] defaults to [Offset.zero] if not provided, and is ignored if
  /// [size] is not set.
  ///
  /// The [offset] only offsets the clipping rectangle, and does not affect
  /// how the painting or annotation search is propagated to its children.
  final Offset offset;

  /// Whether the annotation of this layer should be opaque during an annotation
  /// search of type `T`, preventing siblings visually behind it from being
  /// searched.
  ///
  /// If [opaque] is true, and this layer does add its annotation [value],
  /// then the layer will always be opaque during the search.
  ///
  /// If [opaque] is false, or if this layer does not add its annotation,
  /// then the opacity of this layer will be the one returned by the children,
  /// meaning that it will be opaque if any child is opaque.
  ///
  /// The [opaque] defaults to false.
  ///
  /// The [opaque] is effectively useless during [Layer.find] (more
  /// specifically, [Layer.findAnnotations] with `onlyFirst: true`), since the
  /// search process then skips the remaining tree after finding the first
  /// annotation.
  ///
  /// See also:
  ///
  ///  * [Layer.findAnnotations], which explains the concept of being opaque
  ///    to a type of annotation as the return value.
  ///  * [HitTestBehavior], which controls similar logic when hit-testing in the
  ///    render tree.
  final bool opaque;

  /// Searches the subtree for annotations of type `S` at the location
  /// `localPosition`, then adds the annotation [value] if applicable.
  ///
  /// This method always searches its children, and if any child returns `true`,
  /// the remaining children are skipped. Regardless of what the children
  /// return, this method then adds this layer's annotation if all of the
  /// following restrictions are met:
  ///
  /// {@macro flutter.rendering.AnnotatedRegionLayer.restrictions}
  ///
  /// This search process respects `onlyFirst`, meaning that when `onlyFirst` is
  /// true, the search will stop when it finds the first annotation from the
  /// children, and the layer's own annotation is checked only when none is
  /// given by the children.
  ///
  /// The return value is true if any child returns `true`, or if [opaque] is
  /// true and the layer's annotation is added.
  ///
  /// For explanation of layer annotations, parameters and return value, refer
  /// to [Layer.findAnnotations].
  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    bool isAbsorbed = super.findAnnotations(result, localPosition, onlyFirst: onlyFirst);
    if (result.entries.isNotEmpty && onlyFirst)
      return isAbsorbed;
    if (size != null && !(offset & size!).contains(localPosition)) {
      return isAbsorbed;
    }
    if (T == S) {
      isAbsorbed = isAbsorbed || opaque;
      final Object untypedValue = value;
      final S typedValue = untypedValue as S;
      result.add(AnnotationEntry<S>(
        annotation: typedValue,
        localPosition: localPosition - offset,
      ));
    }
    return isAbsorbed;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<T>('value', value));
    properties.add(DiagnosticsProperty<Size>('size', size, defaultValue: null));
    properties.add(DiagnosticsProperty<Offset>('offset', offset, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('opaque', opaque, defaultValue: false));
  }
}
