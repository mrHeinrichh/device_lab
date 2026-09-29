import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/widgets.dart';

import 'quarter_turn.dart';

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

  /// The intrusion's bounds once the device is turned a quarter turn away
  /// from [naturalScreen], the screen size in its natural orientation.
  Rect resolveRotated(Size naturalScreen) =>
      rotateRectCcw(resolve(naturalScreen), naturalScreen);

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
    this.corners,
    this.rotatable = true,
    this.naturalOrientation = Orientation.portrait,
    this.frame,
    this.ppi,
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

  /// Per-corner rounding, overriding [cornerRadius] when set.
  ///
  /// Given for the screen in its natural orientation. Foldables use this
  /// because the spine side is nearly square while the outer side is round.
  final BorderRadius? corners;

  /// Whether the orientation toggle applies to this screen.
  final bool rotatable;

  /// The body drawn around this screen, overriding [DeviceSpec.frame].
  ///
  /// A foldable's cover screen and its open screen sit in very different
  /// bodies, so each can carry its own.
  final DeviceFrame? frame;

  /// Pixel density in pixels per inch, when the vendor publishes it.
  final double? ppi;

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

  /// The screen's corner rounding in its natural orientation.
  BorderRadius get borderRadius =>
      corners ?? BorderRadius.circular(cornerRadius);

  /// [borderRadius] for the given orientation, turned with the device.
  BorderRadius borderRadiusFor(Orientation orientation) =>
      orientation == naturalOrientation
          ? borderRadius
          : rotateRadiiCcw(borderRadius);

  /// Where each entry of [cutouts] sits on the screen in the given
  /// orientation, in the same order.
  ///
  /// Turning the device carries the camera intrusion with it, so a Dynamic
  /// Island at the top in portrait is a vertical pill on the left edge in
  /// landscape.
  List<Rect> cutoutRectsFor(Orientation orientation) {
    final natural = sizeFor(naturalOrientation);
    return [
      for (final cutout in cutouts)
        orientation == naturalOrientation
            ? cutout.resolve(natural)
            : cutout.resolveRotated(natural),
    ];
  }

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
  /// Cutouts are reported in every orientation, moved to wherever the device
  /// turn carries them, and the hinge, when present, comes with its rotated
  /// axis.
  List<DisplayFeature> displayFeaturesFor(
    Orientation orientation,
    FoldPosture posture,
  ) {
    final size = sizeFor(orientation);
    final rects = cutoutRectsFor(orientation);
    return [
      for (var i = 0; i < cutouts.length; i++)
        if (cutouts[i].obstructing)
          DisplayFeature(
            bounds: rects[i],
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
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
    BorderRadius? corners,
    DeviceFrame? frame,
    double? ppi,
  }) =>
      DeviceScreen(
        naturalOrientation: naturalOrientation,
        corners: corners ?? this.corners,
        frame: frame ?? this.frame,
        ppi: ppi ?? this.ppi,
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
    this.corners,
    this.bodyColor = const Color(0xFF1C1C1E),
    this.edgeColor = const Color(0xFF48484A),
    this.rimWidth = 3,
    this.buttons = const [],
    this.spine,
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

  /// Per-corner rounding of the device body, overriding [outerRadius].
  ///
  /// Given in the body's natural orientation.
  final BorderRadius? corners;

  /// The body's corner rounding in its natural orientation.
  BorderRadius get outerBorderRadius =>
      corners ?? BorderRadius.circular(outerRadius);

  /// Fill colour of the device body.
  final Color bodyColor;

  /// Colour of the metal rim around the body.
  final Color edgeColor;

  /// Thickness of the metal rim.
  final double rimWidth;

  /// Physical buttons drawn along the edges.
  final List<DeviceButton> buttons;

  /// The hinge spine seen edge-on along one side of a closed foldable.
  final FrameSpine? spine;
}

/// The hinge spine of a closed foldable, seen edge-on along one side.
@immutable
class FrameSpine {
  /// Creates a spine on [side], [width] thick.
  const FrameSpine({
    required this.side,
    this.width = 9,
    this.color = const Color(0xFF8E8A80),
  });

  /// Which edge of the body the spine runs along.
  final AxisDirection side;

  /// Thickness of the spine.
  final double width;

  /// Metal colour of the spine.
  final Color color;
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

  /// The button's rectangle on a body of the given natural size.
  ///
  /// It stands [protrusion] proud of the edge, and overlaps the body by one
  /// unit so there is no visible seam.
  Rect rect(Size body, {double protrusion = 3}) {
    switch (side) {
      case AxisDirection.left:
        return Rect.fromLTWH(
          -protrusion,
          start * body.height,
          protrusion + 1,
          length * body.height,
        );
      case AxisDirection.right:
        return Rect.fromLTWH(
          body.width - 1,
          start * body.height,
          protrusion + 1,
          length * body.height,
        );
      case AxisDirection.up:
        return Rect.fromLTWH(
          start * body.width,
          -protrusion,
          length * body.width,
          protrusion + 1,
        );
      case AxisDirection.down:
        return Rect.fromLTWH(
          start * body.width,
          body.height - 1,
          length * body.width,
          protrusion + 1,
        );
    }
  }
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

  /// The body drawn around [screen]: its own frame when it has one,
  /// otherwise this device's [frame].
  DeviceFrame frameFor(DeviceScreen screen) => screen.frame ?? frame;

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
