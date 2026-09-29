import 'dart:math' as math;

import 'package:flutter/widgets.dart';

double ppiFromDiagonal(Size pixels, double diagonalMm) =>
    math.sqrt(pixels.width * pixels.width + pixels.height * pixels.height) /
    (diagonalMm / 25.4);

double pointsPerMm({
  required Size screen,
  required Size pixels,
  required double ppi,
}) =>
    screen.width / (pixels.width / ppi * 25.4);

EdgeInsets bezelFromBody({
  required Size screen,
  required Size pixels,
  required double ppi,
  required Size bodyMm,
}) {
  final k = pointsPerMm(screen: screen, pixels: pixels, ppi: ppi);
  return EdgeInsets.symmetric(
    horizontal: (bodyMm.width * k - screen.width) / 2,
    vertical: (bodyMm.height * k - screen.height) / 2,
  );
}

EdgeInsets insetsFromBody({
  required Size screen,
  required Size pixels,
  required double ppi,
  required Size bodyMm,
  required double leftMm,
  required double topMm,
}) {
  final k = pointsPerMm(screen: screen, pixels: pixels, ppi: ppi);
  final left = leftMm * k;
  final top = topMm * k;
  return EdgeInsets.fromLTRB(
    left,
    top,
    bodyMm.width * k - screen.width - left,
    bodyMm.height * k - screen.height - top,
  );
}
