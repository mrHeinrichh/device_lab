import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'device_lab_controller.dart';

class ZoomControls extends StatelessWidget {
  const ZoomControls({super.key, required this.controller});

  final DeviceLabController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([controller, controller.stageMetrics]),
        builder: (context, _) {
          final metrics = controller.stageMetrics.value;
          final theme = Theme.of(context);
          final fit = controller.isFit;
          final max = math.max(metrics.fitLimit, 0.3);

          return Row(
            children: [
              IconButton(
                tooltip: 'Zoom out',
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: controller.canZoomOut ? controller.zoomOut : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  '${(metrics.scale * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Zoom in',
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: controller.canZoomIn ? controller.zoomIn : null,
                icon: const Icon(Icons.add),
              ),
              Expanded(
                child: Slider(
                  min: 0.2,
                  max: max,
                  value: metrics.scale.clamp(0.2, max).toDouble(),
                  onChanged: controller.setZoom,
                ),
              ),
              IconButton(
                tooltip: 'Fit to screen',
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                color: fit ? theme.colorScheme.primary : null,
                onPressed: fit ? null : () => controller.setZoom(null),
                icon: const Icon(Icons.fit_screen),
              ),
            ],
          );
        },
      );
}
