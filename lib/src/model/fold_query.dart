import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/widgets.dart';

/// Foldable-aware reads over [MediaQueryData.displayFeatures].
///
/// These work against the real API, so layout written with them behaves the
/// same in the preview and on a physical device.
extension FoldQuery on MediaQueryData {
  /// Every fold or hinge feature.
  Iterable<DisplayFeature> get hinges => displayFeatures.where((f) =>
      f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge);

  /// Every camera cutout feature.
  Iterable<DisplayFeature> get cutouts =>
      displayFeatures.where((f) => f.type == DisplayFeatureType.cutout);

  /// The fold that splits the screen into two panes, or null.
  ///
  /// Use this to decide between a single-pane and a two-pane layout.
  DisplayFeature? get separatingFold {
    for (final f in hinges) {
      if (f.state == DisplayFeatureState.postureHalfOpened ||
          f.bounds.shortestSide > 0) {
        return f;
      }
    }
    return hinges.isEmpty ? null : hinges.first;
  }

  /// Whether this screen has a fold or hinge at all.
  bool get hasFold => hinges.isNotEmpty;

  /// Whether the fold runs vertically, splitting the screen left and right.
  bool get isBookPosture =>
      separatingFold != null &&
      separatingFold!.bounds.height >= separatingFold!.bounds.width;

  /// Whether the fold runs horizontally, splitting the screen top and bottom.
  bool get isTabletopPosture =>
      separatingFold != null &&
      separatingFold!.bounds.width > separatingFold!.bounds.height;
}

/// Shorthand for the most common [FoldQuery] reads.
extension FoldQueryContext on BuildContext {
  /// Whether the nearest [MediaQuery] reports a fold.
  bool get hasFold => MediaQuery.of(this).hasFold;

  /// The separating fold from the nearest [MediaQuery], or null.
  DisplayFeature? get separatingFold => MediaQuery.of(this).separatingFold;
}
