import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/device_spec.dart';
import '../model/quarter_turn.dart';
import 'device_body.dart';
import 'device_lab_controller.dart';

const _minScale = 0.2;
const _maxScale = 1.6;
const _floorScale = 0.05;

class DeviceStage extends StatelessWidget {
  const DeviceStage({
    super.key,
    required this.controller,
    required this.child,
  });

  final DeviceLabController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final previewing = controller.previewing;
    final screen = controller.screen;
    final orientation = controller.orientation;
    final turns =
        previewing && orientation != screen.naturalOrientation ? 1 : 0;
    final frame = previewing && controller.showFrame
        ? controller.frame
        : DeviceFrame.none;
    final bezel = turns == 1 ? rotateInsetsCcw(frame.bezel) : frame.bezel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = previewing
            ? controller.logicalSize
            : Size(constraints.maxWidth, constraints.maxHeight);
        final outer = Size(
          size.width + bezel.horizontal,
          size.height + bezel.vertical,
        );
        final fitLimit = math.max(
          math.min(
            (constraints.maxWidth - 40) / outer.width,
            (constraints.maxHeight - 40) / outer.height,
          ),
          _floorScale,
        );
        final manual = controller.zoom;
        final scale = !previewing
            ? 1.0
            : manual == null
                ? fitLimit.clamp(_minScale, _maxScale).toDouble()
                : manual.clamp(_floorScale, fitLimit).toDouble();
        if (previewing) {
          controller.reportStage(scale: scale, fitLimit: fitLimit);
        }

        return OverflowBox(
          minWidth: outer.width,
          maxWidth: outer.width,
          minHeight: outer.height,
          maxHeight: outer.height,
          child: Transform.scale(
            scale: scale,
            child: _Frame(
              frame: frame,
              bezel: bezel,
              turns: turns,
              controller: controller,
              screen: screen,
              orientation: orientation,
              size: size,
              previewing: previewing,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.frame,
    required this.bezel,
    required this.turns,
    required this.controller,
    required this.screen,
    required this.orientation,
    required this.size,
    required this.previewing,
    required this.child,
  });

  final DeviceFrame frame;
  final EdgeInsets bezel;
  final int turns;
  final DeviceLabController controller;
  final DeviceScreen screen;
  final Orientation orientation;
  final Size size;
  final bool previewing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decorated = previewing && controller.showFrame;
    final cutoutRects =
        decorated ? screen.cutoutRectsFor(orientation) : const <Rect>[];

    return CustomPaint(
      painter: DeviceBodyPainter(frame: frame, turns: turns),
      child: Padding(
        padding: bezel,
        child: ClipRRect(
          borderRadius: decorated
              ? screen.borderRadiusFor(orientation)
              : BorderRadius.zero,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (previewing && controller.showSafeAreas)
                  _SafeAreaOverlay(
                    padding: controller.isFreeform
                        ? EdgeInsets.zero
                        : screen.paddingFor(orientation),
                  ),
                if (decorated)
                  for (var i = 0; i < cutoutRects.length; i++)
                    _CutoutOverlay(
                      shape: screen.cutouts[i].shape,
                      rect: cutoutRects[i],
                    ),
                if (decorated && screen.hinge != null)
                  _HingeOverlay(
                    hinge: screen.hinge!,
                    posture: controller.posture,
                    axis: screen.hingeAxisFor(orientation),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SafeAreaOverlay extends StatelessWidget {
  const _SafeAreaOverlay({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: _SafeAreaPainter(padding),
          size: Size.infinite,
        ),
      );
}

class _SafeAreaPainter extends CustomPainter {
  const _SafeAreaPainter(this.padding);

  final EdgeInsets padding;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0x2600E5FF);
    final rect = Offset.zero & size;
    final inner = padding.deflateRect(rect);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRect(inner),
      ),
      fill,
    );
    canvas.drawRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x9900E5FF),
    );
  }

  @override
  bool shouldRepaint(_SafeAreaPainter old) => old.padding != padding;
}

class _CutoutOverlay extends StatelessWidget {
  const _CutoutOverlay({required this.shape, required this.rect});

  final CutoutShape shape;
  final Rect rect;

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(
                switch (shape) {
                  CutoutShape.notch => 16,
                  CutoutShape.none => 0,
                  _ => rect.shortestSide / 2,
                },
              ),
            ),
          ),
        ),
      );
}

class _HingeOverlay extends StatelessWidget {
  const _HingeOverlay({
    required this.hinge,
    required this.posture,
    required this.axis,
  });

  final HingeSpec hinge;
  final FoldPosture posture;
  final Axis axis;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: _HingePainter(hinge, posture, axis),
          size: Size.infinite,
        ),
      );
}

class _HingePainter extends CustomPainter {
  const _HingePainter(this.hinge, this.posture, this.axis);

  final HingeSpec hinge;
  final FoldPosture posture;
  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    final vertical = axis == Axis.vertical;
    final width = hinge.thickness > 0 ? hinge.thickness : 16.0;
    final strength = posture == FoldPosture.halfOpened ? 1.8 : 1.0;
    final center = size.center(Offset.zero);
    final rect = vertical
        ? Rect.fromCenter(center: center, width: width, height: size.height)
        : Rect.fromCenter(center: center, width: size.width, height: width);
    final valley = Color.fromRGBO(0, 0, 0, (0.16 * strength).clamp(0.0, 1.0));
    final ridge =
        Color.fromRGBO(255, 255, 255, (0.10 * strength).clamp(0.0, 1.0));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: vertical ? Alignment.centerLeft : Alignment.topCenter,
          end: vertical ? Alignment.centerRight : Alignment.bottomCenter,
          colors: [
            const Color(0x00000000),
            valley,
            ridge,
            const Color(0x00000000),
          ],
          stops: const [0, 0.46, 0.54, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HingePainter old) =>
      old.posture != posture || old.hinge != hinge || old.axis != axis;
}
