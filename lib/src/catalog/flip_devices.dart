import 'package:flutter/widgets.dart';

import '../model/device_spec.dart';
import 'android_devices.dart' show punchHole;
import 'physical.dart';

const _density = 3.0;
const _glass = Color(0xFF0B0B0D);
const _samsungRim = Color(0xFFC9CDD4);
const _motorolaRim = Color(0xFFB4B8BF);

const _openKeys = [
  DeviceButton(AxisDirection.right, 0.19, 0.077),
  DeviceButton(AxisDirection.right, 0.35, 0.041),
];

const _closedKeys = [
  DeviceButton(AxisDirection.left, 0.37, 0.15),
  DeviceButton(AxisDirection.left, 0.68, 0.08),
];

DeviceSpec _flip({
  required String id,
  required String name,
  required String vendor,
  required int year,
  required double diagonal,
  required Size openMm,
  required Size closedMm,
  required Size mainPx,
  required double mainPpi,
  required Size coverPx,
  required double coverPpi,
  required double coverTopMm,
  required Color rim,
  double? coverLeftMm,
  List<Offset> lensesMm = const [],
  double lensRadiusMm = 4.4,
  List<Offset> coverHolesMm = const [],
  double coverHoleMm = 9.5,
  double bodyRadiusMm = 11,
}) {
  final main = Size(mainPx.width / _density, mainPx.height / _density);
  final cover = Size(coverPx.width / _density, coverPx.height / _density);
  final mainK = pointsPerMm(screen: main, pixels: mainPx, ppi: mainPpi);
  final coverK = pointsPerMm(screen: cover, pixels: coverPx, ppi: coverPpi);
  final coverWidthMm = coverPx.width / coverPpi * 25.4;

  final open = DeviceFrame(
    bezel: bezelFromBody(
      screen: main,
      pixels: mainPx,
      ppi: mainPpi,
      bodyMm: openMm,
    ),
    corners: BorderRadius.circular(bodyRadiusMm * mainK),
    bodyColor: _glass,
    edgeColor: rim,
    rimWidth: 4,
    buttons: _openKeys,
  );

  final closed = DeviceFrame(
    bezel: insetsFromBody(
      screen: cover,
      pixels: coverPx,
      ppi: coverPpi,
      bodyMm: closedMm,
      leftMm: coverLeftMm ?? (closedMm.width - coverWidthMm) / 2,
      topMm: coverTopMm,
    ),
    corners: BorderRadius.circular(bodyRadiusMm * coverK),
    bodyColor: _glass,
    edgeColor: rim,
    rimWidth: 4,
    buttons: _closedKeys,
    spine: FrameSpine(side: AxisDirection.down, width: 4 * coverK, color: rim),
    lenses: [
      for (final c in lensesMm)
        FrameLens(center: c * coverK, radius: lensRadiusMm * coverK),
    ],
  );

  final holeSize = coverHoleMm * coverK;

  return DeviceSpec(
    id: id,
    name: name,
    vendor: vendor,
    platform: DevicePlatform.android,
    category: DeviceCategory.foldable,
    diagonalInches: diagonal,
    releaseYear: year,
    frame: open,
    screens: [
      DeviceScreen(
        label: 'Main',
        logicalSize: main,
        pixelRatio: _density,
        ppi: mainPpi,
        safeArea: const EdgeInsets.only(top: 32, bottom: 24),
        safeAreaRotated: const EdgeInsets.only(bottom: 24),
        cutouts: const [punchHole],
        hinge: const HingeSpec(axis: Axis.horizontal),
        corners: BorderRadius.circular((bodyRadiusMm - 2) * mainK),
        frame: open,
      ),
      DeviceScreen(
        label: 'Cover',
        logicalSize: cover,
        pixelRatio: _density,
        ppi: coverPpi,
        safeArea: const EdgeInsets.only(top: 8, bottom: 8),
        safeAreaRotated: const EdgeInsets.only(top: 8, bottom: 8),
        cutouts: [
          for (final c in coverHolesMm)
            ScreenCutout(
              shape: CutoutShape.punchHole,
              size: Size(holeSize, holeSize),
              alignment: Alignment.topLeft,
              offset: Offset(
                  c.dx * coverK - holeSize / 2, c.dy * coverK - holeSize / 2),
            ),
        ],
        corners: BorderRadius.circular((bodyRadiusMm - 2.5) * coverK),
        frame: closed,
      ),
    ],
  );
}

const _samsungMain = Size(1080, 2520);
const _samsungMainTall = Size(1080, 2640);

final List<DeviceSpec> flipDevices = [
  _flip(
    id: 'samsung.galaxy-z-flip-8',
    name: 'Galaxy Z Flip8',
    vendor: 'Samsung',
    year: 2026,
    diagonal: 6.9,
    openMm: const Size(75.4, 166.9),
    closedMm: const Size(75.4, 85.7),
    mainPx: _samsungMain,
    mainPpi: ppiFromDiagonal(_samsungMain, 174.1),
    coverPx: const Size(948, 1048),
    coverPpi: ppiFromDiagonal(const Size(948, 1048), 104.8),
    coverTopMm: 2.5,
    rim: _samsungRim,
    coverHolesMm: const [Offset(8.6, 8.6), Offset(8.6, 20.6)],
  ),
  _flip(
    id: 'samsung.galaxy-z-flip-7',
    name: 'Galaxy Z Flip 7',
    vendor: 'Samsung',
    year: 2025,
    diagonal: 6.9,
    openMm: const Size(75.2, 166.7),
    closedMm: const Size(75.2, 85.5),
    mainPx: _samsungMain,
    mainPpi: ppiFromDiagonal(_samsungMain, 174.1),
    coverPx: const Size(948, 1048),
    coverPpi: ppiFromDiagonal(const Size(948, 1048), 104.8),
    coverTopMm: 2.5,
    rim: _samsungRim,
    coverHolesMm: const [Offset(8.6, 8.6), Offset(8.6, 20.6)],
  ),
  _flip(
    id: 'samsung.galaxy-z-flip-6',
    name: 'Galaxy Z Flip 6',
    vendor: 'Samsung',
    year: 2024,
    diagonal: 6.7,
    openMm: const Size(71.9, 165.1),
    closedMm: const Size(71.9, 85.1),
    mainPx: _samsungMainTall,
    mainPpi: ppiFromDiagonal(_samsungMainTall, 170.3),
    coverPx: const Size(720, 748),
    coverPpi: ppiFromDiagonal(const Size(720, 748), 86.1),
    coverTopMm: 16,
    rim: _samsungRim,
    lensesMm: const [Offset(12.5, 8.5), Offset(23.5, 8.5)],
  ),
  _flip(
    id: 'samsung.galaxy-z-flip-5',
    name: 'Galaxy Z Flip 5',
    vendor: 'Samsung',
    year: 2023,
    diagonal: 6.7,
    openMm: const Size(71.9, 165.1),
    closedMm: const Size(71.9, 85.1),
    mainPx: _samsungMainTall,
    mainPpi: ppiFromDiagonal(_samsungMainTall, 170.3),
    coverPx: const Size(720, 748),
    coverPpi: ppiFromDiagonal(const Size(720, 748), 86.1),
    coverTopMm: 16,
    rim: _samsungRim,
    lensesMm: const [Offset(12.5, 8.5), Offset(23.5, 8.5)],
  ),
  _flip(
    id: 'samsung.galaxy-z-flip-4',
    name: 'Galaxy Z Flip 4',
    vendor: 'Samsung',
    year: 2022,
    diagonal: 6.7,
    openMm: const Size(71.9, 165.2),
    closedMm: const Size(71.9, 84.9),
    mainPx: _samsungMainTall,
    mainPpi: ppiFromDiagonal(_samsungMainTall, 170.3),
    coverPx: const Size(512, 260),
    coverPpi: ppiFromDiagonal(const Size(512, 260), 48),
    coverTopMm: 4,
    coverLeftMm: 26.5,
    rim: _samsungRim,
    lensesMm: const [Offset(11, 9.5), Offset(11, 20)],
    lensRadiusMm: 4.2,
  ),
  _flip(
    id: 'motorola.razr-50-ultra',
    name: 'Motorola Razr 50 Ultra',
    vendor: 'Motorola',
    year: 2024,
    diagonal: 6.9,
    openMm: const Size(73.99, 171.42),
    closedMm: const Size(73.99, 88.09),
    mainPx: _samsungMainTall,
    mainPpi: 413,
    coverPx: const Size(1080, 1272),
    coverPpi: 417,
    coverTopMm: 4,
    rim: _motorolaRim,
    coverHolesMm: const [Offset(9.5, 9.5), Offset(9.5, 21)],
    coverHoleMm: 9,
    bodyRadiusMm: 12,
  ),
  _flip(
    id: 'motorola.razr-2023',
    name: 'Motorola Razr (2023)',
    vendor: 'Motorola',
    year: 2023,
    diagonal: 6.9,
    openMm: const Size(73.95, 170.82),
    closedMm: const Size(73.95, 88.24),
    mainPx: _samsungMainTall,
    mainPpi: 413,
    coverPx: const Size(368, 194),
    coverPpi: 282,
    coverTopMm: 3.6,
    coverLeftMm: 37.8,
    rim: _motorolaRim,
    lensesMm: const [Offset(12, 9.5), Offset(12, 20.5)],
    lensRadiusMm: 4.6,
    bodyRadiusMm: 12,
  ),
];
