import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../model/device_spec.dart';

/// Drives `flutter_test` from the same device specs as the preview.
///
/// Import `package:device_lab/device_lab_testing.dart` to use these.
extension DeviceLabTester on WidgetTester {
  /// Configures the test view to match [device].
  ///
  /// Sets size, pixel ratio, padding and display features, and restores the
  /// view automatically when the test ends.
  void applyDevice(
    DeviceSpec device, {
    Orientation orientation = Orientation.portrait,
    FoldPosture posture = FoldPosture.flat,
  }) {
    final screen = device.screenFor(posture);
    final size = screen.sizeFor(orientation);
    final padding = screen.paddingFor(orientation);
    final dpr = screen.pixelRatio;

    view.devicePixelRatio = dpr;
    view.physicalSize = Size(size.width * dpr, size.height * dpr);
    view.padding = FakeViewPadding(
      left: padding.left * dpr,
      top: padding.top * dpr,
      right: padding.right * dpr,
      bottom: padding.bottom * dpr,
    );
    view.viewPadding = view.padding;
    view.displayFeatures = screen.displayFeaturesFor(orientation, posture);

    addTearDown(view.reset);
  }

  /// Calls [applyDevice], pumps [widget] and settles.
  Future<void> pumpOnDevice(
    Widget widget,
    DeviceSpec device, {
    Orientation orientation = Orientation.portrait,
    FoldPosture posture = FoldPosture.flat,
    Duration? duration,
  }) async {
    applyDevice(device, orientation: orientation, posture: posture);
    await pumpWidget(widget);
    await pumpAndSettle(duration ?? const Duration(milliseconds: 100));
  }
}

/// A stable golden file name for [device] under the given [scenario].
///
/// Includes the posture for foldables so cover and unfolded goldens do not
/// collide.
String goldenNameFor(
  DeviceSpec device, {
  required String scenario,
  Orientation orientation = Orientation.portrait,
  FoldPosture posture = FoldPosture.flat,
}) {
  final parts = [
    scenario,
    device.id.replaceAll('.', '-'),
    orientation.name,
    if (device.isFoldable) posture.name,
  ];
  return 'goldens/${parts.join('_')}.png';
}
