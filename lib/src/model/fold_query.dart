import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/widgets.dart';

extension FoldQuery on MediaQueryData {
  Iterable<DisplayFeature> get hinges => displayFeatures.where((f) =>
      f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge);

  Iterable<DisplayFeature> get cutouts =>
      displayFeatures.where((f) => f.type == DisplayFeatureType.cutout);

  DisplayFeature? get separatingFold {
    for (final f in hinges) {
      if (f.state == DisplayFeatureState.postureHalfOpened ||
          f.bounds.shortestSide > 0) {
        return f;
      }
    }
    return hinges.isEmpty ? null : hinges.first;
  }

  bool get hasFold => hinges.isNotEmpty;

  bool get isBookPosture =>
      separatingFold != null &&
      separatingFold!.bounds.height >= separatingFold!.bounds.width;

  bool get isTabletopPosture =>
      separatingFold != null &&
      separatingFold!.bounds.width > separatingFold!.bounds.height;
}

extension FoldQueryContext on BuildContext {
  bool get hasFold => MediaQuery.of(this).hasFold;
  DisplayFeature? get separatingFold => MediaQuery.of(this).separatingFold;
}
