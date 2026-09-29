import 'package:flutter/widgets.dart';

Size rotateSize(Size size) => Size(size.height, size.width);

Rect rotateRectCcw(Rect rect, Size natural) => Rect.fromLTWH(
    rect.top, natural.width - rect.right, rect.height, rect.width);

EdgeInsets rotateInsetsCcw(EdgeInsets insets) =>
    EdgeInsets.fromLTRB(insets.top, insets.right, insets.bottom, insets.left);

BorderRadius rotateRadiiCcw(BorderRadius radii) => BorderRadius.only(
      topLeft: radii.topRight,
      topRight: radii.bottomRight,
      bottomRight: radii.bottomLeft,
      bottomLeft: radii.topLeft,
    );
