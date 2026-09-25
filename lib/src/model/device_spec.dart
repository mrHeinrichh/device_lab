import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/widgets.dart';

/// The operating system a device runs, used to pick its [TargetPlatform].
enum DevicePlatform { ios, android, macos, windows, linux, fuchsia, web }

/// Broad form factor, used to group devices in the picker and in queries.
enum DeviceCategory { phone, foldable, tablet, desktop, watch, tv }

/// The shape of a camera intrusion drawn over the screen.
enum CutoutShape { none, notch, dynamicIsland, punchHole, pill }

/// How far a foldable is opened.
///
/// [folded] resolves to the cover screen; [halfOpened] and [flat] resolve to
/// the main screen and differ only in the reported [DisplayFeatureState].
enum FoldPosture { folded, halfOpened, flat }

/// A camera intrusion such as a notch, Dynamic Island or punch hole.
///
/// Rendered over the screen and, when [obstructing], reported to the app as a
/// [DisplayFeatureType.cutout] so layout code can route around it.
@immutable
class ScreenCutout {
  const ScreenCutout({
    required this.shape,
    required this.size,
    this.alignment = Alignment.topCenter,
    this.offset = Offset.zero,
    this.obstructing = true,
  });

  /// Shape used when painting the intrusion.
  final CutoutShape shape;

  /// Size of the intrusion in logical pixels.
  final Size size;

  /// Where the intrusion sits on the screen.
  final Alignment alignment;

  /// Extra displacement applied after [alignment].
  final Offset offset;

  /// Whether this intrusion is reported as a [DisplayFeature].
  final bool obstructing;

  /// The intrusion's bounds on a screen of the given logical [screen] size.
  Rect resolve(Size screen) {
    final x = (screen.width - size.width) / 2 * (1 + alignment.x) + offset.dx;
    final y = (screen.height - size.height) / 2 * (1 + alignment.y) + offset.dy;
    return Rect.fromLTWH(x, y, size.width, size.height);
  }

  /// This intrusion as a [DisplayFeature] for [MediaQueryData.displayFeatures].
  DisplayFeature toDisplayFeature(Size screen) => DisplayFeature(
        bounds: resolve(screen),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      );
}

/// The fold or hinge of a foldable device.
///
/// A [Axis.vertical] hinge describes a book fold such as a Galaxy Z Fold or
/// iPhone Duo; [Axis.horizontal] describes a flip phone such as a Z Flip.
/// The axis is relative to the screen's [DeviceScreen.naturalOrientation] and
/// rotates with the device.
@immutable
class HingeSpec {
  const HingeSpec({
    required this.axis,
    this.thickness = 0,
    this.supportsHalfOpen = true,
  });

  /// Hinge direction in the screen's natural orientation.
  final Axis axis;

  /// Width of the physical gap in logical pixels.
  ///
  /// Zero describes a seamless fold, reported as [DisplayFeatureType.fold];
  /// anything larger is reported as [DisplayFeatureType.hinge].
  final double thickness;

  /// Whether the device can rest half opened.
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

/// One physical display of a device.
///
/// Most devices have a single screen. Foldables have two: the main screen
/// first and the cover screen second, selected by [DeviceSpec.screenFor].
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

  /// Human readable name, such as `Main` or `Cover`.
  final String label;

  /// Size in logical pixels with the device held in portrait.
  ///
  /// This is the value Flutter layout sees as `MediaQuery.sizeOf`. Physical
  /// pixels are available from [resolution].
  final Size logicalSize;

  /// Ratio of physical to logical pixels.
  final double pixelRatio;

  /// Insets in the screen's [naturalOrientation].
  final EdgeInsets safeArea;
  final EdgeInsets? _safeAreaRotated;

  /// Camera intrusions on this screen.
  final List<ScreenCutout> cutouts;

  /// The fold, when this screen is the inner display of a foldable.
  final HingeSpec? hinge;

  /// Corner rounding in logical pixels, used to clip the preview.
  final double cornerRadius;

  /// Whether the orientation toggle applies to this screen.
  final bool rotatable;

  /// The orientation this screen is designed to be held in.
  ///
  /// Portrait for nearly every device. The iPhone Duo's inner display is
  /// landscape, because its open body is wider than it is tall. [safeArea],
  /// [paddingFor] and [hingeAxisFor] are all relative to this.
  final Orientation naturalOrientation;

  /// Insets when the device is turned 90 degrees from [naturalOrientation].
  ///
  /// Derived from [safeArea] when not given explicitly.
  EdgeInsets get safeAreaRotated =>
      _safeAreaRotated ??
      EdgeInsets.only(
        left: safeArea.top > 24 ? safeArea.top * 0.8 : 0,
        right: safeArea.top > 24 ? safeArea.top * 0.8 : 0,
        bottom: safeArea.bottom > 0 ? 21 : 0,
      );

  /// Size in physical pixels, that is [logicalSize] times [pixelRatio].
  Size get resolution =>
      Size(logicalSize.width * pixelRatio, logicalSize.height * pixelRatio);

  /// Height divided by width in portrait.
  double get aspectRatio => logicalSize.height / logicalSize.width;

  /// [logicalSize] for the given orientation, with the axes swapped for
  /// landscape.
  Size sizeFor(Orientation orientation) => orientation == Orientation.portrait
      ? logicalSize
      : Size(logicalSize.height, logicalSize.width);

  /// Safe area insets for the given orientation.
  EdgeInsets paddingFor(Orientation orientation) =>
      orientation == naturalOrientation ? safeArea : safeAreaRotated;

  /// The hinge axis once the device is rotated into [orientation].
  ///
  /// A book fold read as a vertical separator in its natural pose becomes a
  /// horizontal one when the device is turned.
  Axis hingeAxisFor(Orientation orientation) {
    final axis = hinge!.axis;
    if (orientation == naturalOrientation) return axis;
    return axis == Axis.vertical ? Axis.horizontal : Axis.vertical;
  }

  /// Display features to publish for the given orientation and posture.
  ///
  /// Cutouts are included only in [naturalOrientation]; the hinge, when
  /// present, is always included with its rotated axis.
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

  /// A copy of this screen with the given fields replaced.
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

/// The bezel drawn around a device's screen in the preview.
@immutable
class DeviceFrame {
  const DeviceFrame({
    this.bezel = const EdgeInsets.all(12),
    this.outerRadius = 48,
    this.bodyColor = const Color(0xFF1C1C1E),
    this.edgeColor = const Color(0xFF48484A),
    this.buttons = const [],
  });

  /// A frame that draws nothing, used for bare viewports.
  static const none = DeviceFrame(
    bezel: EdgeInsets.zero,
    outerRadius: 0,
    bodyColor: Color(0x00000000),
  );

  /// Bezel thickness on each side.
  final EdgeInsets bezel;

  /// Corner rounding of the device body.
  final double outerRadius;

  /// Fill colour of the device body.
  final Color bodyColor;

  /// Colour of the body's outline.
  final Color edgeColor;

  /// Physical buttons drawn along the edges.
  final List<DeviceButton> buttons;
}

/// A physical button drawn on the side of a device frame.
@immutable
class DeviceButton {
  /// Creates a button on [side], starting at [start] and [length] long, both
  /// as fractions of that edge.
  const DeviceButton(this.side, this.start, this.length);

  /// Which edge the button sits on.
  final AxisDirection side;

  /// Distance along the edge where the button starts, from 0 to 1.
  final double start;

  /// Length of the button as a fraction of the edge.
  final double length;
}

/// A device in the catalog.
///
/// Built from published vendor specifications where possible. Register your
/// own with [DeviceCatalog.register] or load them from JSON with
/// [DeviceCatalog.loadJson].
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

  /// Stable identifier, such as `apple.iphone-duo`.
  final String id;

  /// Marketing name shown in the picker.
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
