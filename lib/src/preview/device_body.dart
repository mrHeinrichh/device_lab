import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../model/device_spec.dart';
import '../model/quarter_turn.dart';

class DeviceBodyPainter extends CustomPainter {
  const DeviceBodyPainter({required this.frame, required this.turns});

  final DeviceFrame frame;
  final int turns;

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.bodyColor.a == 0) return;

    final rotated = turns.isOdd;
    final natural = rotated ? rotateSize(size) : size;
    final radii = frame.outerBorderRadius;

    final screenRadii = rotated ? rotateRadiiCcw(radii) : radii;
    canvas.drawRRect(
      screenRadii.toRRect(Offset.zero & size).shift(const Offset(0, 12)),
      Paint()
        ..color = const Color(0x4D000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.save();
    if (rotated) {
      canvas.translate(0, size.height);
      canvas.rotate(-math.pi / 2);
    }

    final body = radii.toRRect(Offset.zero & natural);
    _paintButtons(canvas, natural);
    _paintRim(canvas, body, natural);
    canvas.drawRRect(
      body.deflate(frame.rimWidth),
      Paint()..color = frame.bodyColor,
    );
    _paintSpine(canvas, body, natural);
    canvas.restore();
  }

  void _paintRim(Canvas canvas, RRect body, Size natural) {
    final rim = frame.edgeColor;
    final light = Color.lerp(rim, const Color(0xFFFFFFFF), 0.4)!;
    final dark = Color.lerp(rim, const Color(0xFF000000), 0.4)!;
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(natural.width, natural.height),
          [light, rim, dark, rim, light],
          [0, 0.25, 0.5, 0.75, 1],
        ),
    );
  }

  void _paintButtons(Canvas canvas, Size natural) {
    final fill = Color.lerp(frame.edgeColor, const Color(0xFF000000), 0.3)!;
    final highlight =
        Color.lerp(frame.edgeColor, const Color(0xFFFFFFFF), 0.3)!;
    for (final button in frame.buttons) {
      final rect = button.rect(natural);
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(1.5));
      canvas.drawRRect(shape, Paint()..color = fill);
      canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = highlight,
      );
    }
  }

  void _paintSpine(Canvas canvas, RRect body, Size natural) {
    final spine = frame.spine;
    if (spine == null) return;

    final vertical =
        spine.side == AxisDirection.left || spine.side == AxisDirection.right;
    final rect = switch (spine.side) {
      AxisDirection.left => Rect.fromLTWH(0, 0, spine.width, natural.height),
      AxisDirection.right => Rect.fromLTWH(
          natural.width - spine.width,
          0,
          spine.width,
          natural.height,
        ),
      AxisDirection.up => Rect.fromLTWH(0, 0, natural.width, spine.width),
      AxisDirection.down => Rect.fromLTWH(
          0,
          natural.height - spine.width,
          natural.width,
          spine.width,
        ),
    };
    final light = Color.lerp(spine.color, const Color(0xFFFFFFFF), 0.5)!;
    final dark = Color.lerp(spine.color, const Color(0xFF000000), 0.5)!;

    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          vertical ? rect.topRight : rect.bottomLeft,
          [dark, light, spine.color, dark],
          [0, 0.3, 0.7, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DeviceBodyPainter old) =>
      old.frame != frame || old.turns != turns;
}
