import 'package:flutter/material.dart';

import '../model/device_spec.dart';
import 'device_lab_controller.dart';

const _minScale = 0.2;
const _maxScale = 1.6;

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
    final frame = previewing && controller.showFrame
        ? controller.device.frame
        : DeviceFrame.none;
    final bezel = previewing
        ? (controller.orientation == Orientation.landscape
            ? _rotateInsets(frame.bezel)
            : frame.bezel)
        : EdgeInsets.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = previewing
            ? controller.logicalSize
            : Size(constraints.maxWidth, constraints.maxHeight);
        final outer = Size(
          size.width + bezel.horizontal,
          size.height + bezel.vertical,
        );
        final fitWidth = (constraints.maxWidth - 40) / outer.width;
        final fitHeight = (constraints.maxHeight - 40) / outer.height;
        final fit = fitWidth < fitHeight ? fitWidth : fitHeight;
        final scale =
            previewing ? fit.clamp(_minScale, _maxScale).toDouble() : 1.0;

        return Center(
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: outer.width,
              height: outer.height,
              child: _Frame(
                frame: frame,
                bezel: bezel,
                controller: controller,
                screen: screen,
                size: size,
                previewing: previewing,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  EdgeInsets _rotateInsets(EdgeInsets i) =>
      EdgeInsets.fromLTRB(i.top, i.right, i.bottom, i.left);
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.frame,
    required this.bezel,
    required this.controller,
    required this.screen,
    required this.size,
    required this.previewing,
    required this.child,
  });

  final DeviceFrame frame;
  final EdgeInsets bezel;
  final DeviceLabController controller;
  final DeviceScreen screen;
  final Size size;
  final bool previewing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decorated = previewing && controller.showFrame;
    final radius = decorated ? screen.cornerRadius : 0.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: frame.bodyColor,
        borderRadius: BorderRadius.circular(frame.outerRadius),
        border: frame.outerRadius > 0
            ? Border.all(color: frame.edgeColor, width: 1.5)
            : null,
        boxShadow: frame.outerRadius > 0
            ? const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: bezel,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
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
                        : screen.paddingFor(controller.orientation),
                  ),
                if (decorated &&
                    controller.orientation == screen.naturalOrientation)
                  ...screen.cutouts.map(
                    (c) => _CutoutOverlay(cutout: c, screen: size),
                  ),
                if (decorated && screen.hinge != null)
                  _HingeOverlay(
                    hinge: screen.hinge!,
                    posture: controller.posture,
                    axis: screen.hingeAxisFor(controller.orientation),
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
  const _CutoutOverlay({required this.cutout, required this.screen});

  final ScreenCutout cutout;
  final Size screen;

  @override
  Widget build(BuildContext context) {
    final rect = cutout.resolve(screen);
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(
              switch (cutout.shape) {
                CutoutShape.notch => 16,
                CutoutShape.dynamicIsland ||
                CutoutShape.pill =>
                  rect.height / 2,
                CutoutShape.punchHole => rect.height / 2,
                CutoutShape.none => 0,
              },
            ),
          ),
        ),
      ),
    );
  }
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
    final paint = Paint()
      ..color = posture == FoldPosture.halfOpened
          ? const Color(0x80FFFFFF)
          : const Color(0x33FFFFFF)
      ..strokeWidth = hinge.thickness > 0 ? hinge.thickness : 2;
    if (axis == Axis.vertical) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HingePainter old) =>
      old.posture != posture || old.hinge != hinge || old.axis != axis;
}
