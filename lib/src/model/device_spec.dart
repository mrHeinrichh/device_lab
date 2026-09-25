import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/widgets.dart';

enum DevicePlatform { ios, android, macos, windows, linux, fuchsia, web }

enum DeviceCategory { phone, foldable, tablet, desktop, watch, tv }

enum CutoutShape { none, notch, dynamicIsland, punchHole, pill }

enum FoldPosture { folded, halfOpened, flat }

@immutable
class ScreenCutout {
  const ScreenCutout({
    required this.shape,
    required this.size,
    this.alignment = Alignment.topCenter,
    this.offset = Offset.zero,
    this.obstructing = true,
  });

  final CutoutShape shape;
  final Size size;
  final Alignment alignment;
  final Offset offset;
  final bool obstructing;

  Rect resolve(Size screen) {
    final x = (screen.width - size.width) / 2 * (1 + alignment.x) + offset.dx;
    final y = (screen.height - size.height) / 2 * (1 + alignment.y) + offset.dy;
    return Rect.fromLTWH(x, y, size.width, size.height);
  }

  DisplayFeature toDisplayFeature(Size screen) => DisplayFeature(
        bounds: resolve(screen),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      );
}

@immutable
class HingeSpec {
  const HingeSpec({
    required this.axis,
    this.thickness = 0,
    this.supportsHalfOpen = true,
  });

  final Axis axis;
  final double thickness;
  final bool supportsHalfOpen;

  DisplayFeature toDisplayFeature(
    Size screen,
    FoldPosture posture,
    Axis effectiveAxis,
  ) {
    final state = posture == FoldPosture.halfOpened
        ? DisplayFeatureState.postureHalfOpened
        : DisplayFeatureState.postureFlat;
    final bounds = effectiveAxis == Axis.vertical
        ? Rect.fromLTWH(
            (screen.width - thickness) / 2, 0, thickness, screen.height)
        : Rect.fromLTWH(
            0, (screen.height - thickness) / 2, screen.width, thickness);
    return DisplayFeature(
      bounds: bounds,
      type: thickness > 0 ? DisplayFeatureType.hinge : DisplayFeatureType.fold,
      state: state,
    );
  }
}

@immutable
class DeviceScreen {
  const DeviceScreen({
    required this.label,
    required this.logicalSize,
    required this.pixelRatio,
    required this.safeArea,
    EdgeInsets? safeAreaRotated,
    this.cutouts = const [],
    this.hinge,
    this.cornerRadius = 0,
    this.rotatable = true,
    this.naturalOrientation = Orientation.portrait,
  }) : _safeAreaRotated = safeAreaRotated;

  final String label;
  final Size logicalSize;
  final double pixelRatio;
  final EdgeInsets safeArea;
  final EdgeInsets? _safeAreaRotated;
  final List<ScreenCutout> cutouts;
  final HingeSpec? hinge;
  final double cornerRadius;
  final bool rotatable;
  final Orientation naturalOrientation;

  EdgeInsets get safeAreaRotated =>
      _safeAreaRotated ??
      EdgeInsets.only(
        left: safeArea.top > 24 ? safeArea.top * 0.8 : 0,
        right: safeArea.top > 24 ? safeArea.top * 0.8 : 0,
        bottom: safeArea.bottom > 0 ? 21 : 0,
      );

  Size get resolution =>
      Size(logicalSize.width * pixelRatio, logicalSize.height * pixelRatio);

  double get aspectRatio => logicalSize.height / logicalSize.width;

  Size sizeFor(Orientation orientation) => orientation == Orientation.portrait
      ? logicalSize
      : Size(logicalSize.height, logicalSize.width);

  EdgeInsets paddingFor(Orientation orientation) =>
      orientation == naturalOrientation ? safeArea : safeAreaRotated;

  Axis hingeAxisFor(Orientation orientation) {
    final axis = hinge!.axis;
    if (orientation == naturalOrientation) return axis;
    return axis == Axis.vertical ? Axis.horizontal : Axis.vertical;
  }

  List<DisplayFeature> displayFeaturesFor(
    Orientation orientation,
    FoldPosture posture,
  ) {
    final size = sizeFor(orientation);
    return [
      for (final cutout in cutouts)
        if (cutout.obstructing && orientation == naturalOrientation)
          cutout.toDisplayFeature(size),
      if (hinge != null)
        hinge!.toDisplayFeature(size, posture, hingeAxisFor(orientation)),
    ];
  }

  DeviceScreen copyWith({
    String? label,
    Size? logicalSize,
    double? pixelRatio,
    EdgeInsets? safeArea,
    EdgeInsets? safeAreaRotated,
    List<ScreenCutout>? cutouts,
    HingeSpec? hinge,
    double? cornerRadius,
  }) =>
      DeviceScreen(
        naturalOrientation: naturalOrientation,
        label: label ?? this.label,
        logicalSize: logicalSize ?? this.logicalSize,
        pixelRatio: pixelRatio ?? this.pixelRatio,
        safeArea: safeArea ?? this.safeArea,
        safeAreaRotated: safeAreaRotated ?? _safeAreaRotated,
        cutouts: cutouts ?? this.cutouts,
        hinge: hinge ?? this.hinge,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        rotatable: rotatable,
      );
}

@immutable
class DeviceFrame {
  const DeviceFrame({
    this.bezel = const EdgeInsets.all(12),
    this.outerRadius = 48,
    this.bodyColor = const Color(0xFF1C1C1E),
    this.edgeColor = const Color(0xFF48484A),
    this.buttons = const [],
  });

  static const none = DeviceFrame(
    bezel: EdgeInsets.zero,
    outerRadius: 0,
    bodyColor: Color(0x00000000),
  );

  final EdgeInsets bezel;
  final double outerRadius;
  final Color bodyColor;
  final Color edgeColor;
  final List<DeviceButton> buttons;
}

@immutable
class DeviceButton {
  const DeviceButton(this.side, this.start, this.length);
  final AxisDirection side;
  final double start;
  final double length;
}

@immutable
class DeviceSpec {
  const DeviceSpec({
    required this.id,
    required this.name,
    required this.platform,
    required this.category,
    required this.screens,
    this.frame = const DeviceFrame(),
    this.vendor,
    this.diagonalInches,
    this.releaseYear,
  }) : assert(screens.length > 0);

  final String id;
  final String name;
  final DevicePlatform platform;
  final DeviceCategory category;
  final List<DeviceScreen> screens;
  final DeviceFrame frame;
  final String? vendor;
  final double? diagonalInches;
  final int? releaseYear;

  DeviceScreen get primaryScreen => screens.first;

  bool get isFoldable => category == DeviceCategory.foldable;

  TargetPlatform get targetPlatform => switch (platform) {
        DevicePlatform.ios => TargetPlatform.iOS,
        DevicePlatform.android => TargetPlatform.android,
        DevicePlatform.macos => TargetPlatform.macOS,
        DevicePlatform.windows => TargetPlatform.windows,
        DevicePlatform.linux => TargetPlatform.linux,
        DevicePlatform.fuchsia => TargetPlatform.fuchsia,
        DevicePlatform.web => TargetPlatform.android,
      };

  DeviceScreen screenFor(FoldPosture posture) {
    if (!isFoldable || screens.length < 2) return screens.first;
    return posture == FoldPosture.folded ? screens.last : screens.first;
  }
}
