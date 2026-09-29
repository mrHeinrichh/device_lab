import 'package:flutter/widgets.dart';

import '../model/device_spec.dart';
import 'physical.dart';

const _island = ScreenCutout(
  shape: CutoutShape.dynamicIsland,
  size: Size(126, 37),
  offset: Offset(0, 11),
);

const _notch = ScreenCutout(
  shape: CutoutShape.notch,
  size: Size(209, 32),
);

const _wideNotch = ScreenCutout(
  shape: CutoutShape.notch,
  size: Size(230, 33),
);

DeviceScreen _iphone(
  Size size, {
  required double top,
  double bottom = 34,
  ScreenCutout? cutout = _island,
  double radius = 55,
  String label = 'Main',
  HingeSpec? hinge,
  Orientation natural = Orientation.portrait,
  double pixelRatio = 3,
}) =>
    DeviceScreen(
      label: label,
      logicalSize: size,
      pixelRatio: pixelRatio,
      safeArea: EdgeInsets.only(top: top, bottom: bottom),
      cutouts: cutout == null ? const [] : [cutout],
      cornerRadius: radius,
      hinge: hinge,
      naturalOrientation: natural,
    );

DeviceScreen _ipad(Size size, {double radius = 24, double pixelRatio = 2}) =>
    DeviceScreen(
      label: 'Main',
      logicalSize: size,
      pixelRatio: pixelRatio,
      safeArea: const EdgeInsets.only(top: 24, bottom: 20),
      safeAreaRotated: const EdgeInsets.only(top: 24, bottom: 20),
      cornerRadius: radius,
    );

const _appleButtons = [
  DeviceButton(AxisDirection.left, 0.18, 0.05),
  DeviceButton(AxisDirection.left, 0.27, 0.09),
  DeviceButton(AxisDirection.left, 0.39, 0.09),
  DeviceButton(AxisDirection.right, 0.30, 0.13),
];

const _phoneFrame = DeviceFrame(
  bezel: EdgeInsets.all(10),
  outerRadius: 64,
  bodyColor: Color(0xFF2B2B2E),
  edgeColor: Color(0xFF6E6E73),
  buttons: _appleButtons,
);

const _homeButtonFrame = DeviceFrame(
  bezel: EdgeInsets.fromLTRB(10, 52, 10, 68),
  outerRadius: 24,
  bodyColor: Color(0xFF2B2B2E),
  edgeColor: Color(0xFF6E6E73),
);

const _tabletFrame = DeviceFrame(
  bezel: EdgeInsets.all(18),
  outerRadius: 38,
  bodyColor: Color(0xFF2B2B2E),
  edgeColor: Color(0xFF6E6E73),
);

DeviceSpec _phone({
  required String id,
  required String name,
  required List<DeviceScreen> screens,
  required double diagonal,
  required int year,
  DeviceCategory category = DeviceCategory.phone,
  DeviceFrame frame = _phoneFrame,
}) =>
    DeviceSpec(
      id: id,
      name: name,
      vendor: 'Apple',
      platform: DevicePlatform.ios,
      category: category,
      diagonalInches: diagonal,
      releaseYear: year,
      frame: frame,
      screens: screens,
    );

DeviceSpec _tablet({
  required String id,
  required String name,
  required Size size,
  required double diagonal,
  required int year,
  double radius = 24,
}) =>
    DeviceSpec(
      id: id,
      name: name,
      vendor: 'Apple',
      platform: DevicePlatform.ios,
      category: DeviceCategory.tablet,
      diagonalInches: diagonal,
      releaseYear: year,
      frame: _tabletFrame,
      screens: [_ipad(size, radius: radius)],
    );

const _titanium = Color(0xFFBDB6A8);
const _duoGlass = Color(0xFF0B0B0D);

DeviceSpec _iphoneDuo() {
  final openBezel = bezelFromBody(
    screen: const Size(890, 626),
    pixels: const Size(2670, 1878),
    ppi: 430,
    bodyMm: const Size(164.6, 117.8),
  );
  final closedBezel = bezelFromBody(
    screen: const Size(466, 678),
    pixels: const Size(1398, 2034),
    ppi: 460,
    bodyMm: const Size(84.1, 117.8),
  );
  const spineShift = 3.5;

  final open = DeviceFrame(
    bezel: openBezel,
    corners: BorderRadius.circular(64),
    bodyColor: _duoGlass,
    edgeColor: _titanium,
    rimWidth: 5,
    buttons: const [
      DeviceButton(AxisDirection.up, 0.733, 0.0225),
      DeviceButton(AxisDirection.up, 0.811, 0.0225),
      DeviceButton(AxisDirection.right, 0.29, 0.15),
    ],
  );
  final closed = DeviceFrame(
    bezel: EdgeInsets.fromLTRB(
      closedBezel.left + spineShift,
      closedBezel.top,
      closedBezel.right - spineShift,
      closedBezel.bottom,
    ),
    corners: const BorderRadius.only(
      topLeft: Radius.circular(20),
      topRight: Radius.circular(78),
      bottomRight: Radius.circular(78),
      bottomLeft: Radius.circular(20),
    ),
    bodyColor: _duoGlass,
    edgeColor: _titanium,
    rimWidth: 5,
    spine: const FrameSpine(side: AxisDirection.left, width: 11),
    buttons: const [
      DeviceButton(AxisDirection.up, 0.466, 0.045),
      DeviceButton(AxisDirection.up, 0.623, 0.045),
      DeviceButton(AxisDirection.right, 0.29, 0.15),
    ],
  );

  return _phone(
    id: 'apple.iphone-duo',
    name: 'iPhone Duo',
    diagonal: 7.6,
    year: 2026,
    category: DeviceCategory.foldable,
    frame: open,
    screens: [
      DeviceScreen(
        label: 'Main',
        logicalSize: const Size(626, 890),
        pixelRatio: 3,
        ppi: 430,
        safeArea: const EdgeInsets.only(top: 62, bottom: 34),
        naturalOrientation: Orientation.landscape,
        hinge: const HingeSpec(axis: Axis.vertical),
        corners: BorderRadius.circular(45),
        frame: open,
      ),
      DeviceScreen(
        label: 'Cover',
        logicalSize: const Size(466, 678),
        pixelRatio: 3,
        ppi: 460,
        safeArea: const EdgeInsets.only(top: 62, bottom: 34),
        cutouts: const [
          ScreenCutout(
            shape: CutoutShape.dynamicIsland,
            size: Size(38, 38),
            alignment: Alignment.topRight,
            offset: Offset(-29, 28),
          ),
        ],
        corners: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(58),
          bottomRight: Radius.circular(58),
          bottomLeft: Radius.circular(8),
        ),
        frame: closed,
      ),
    ],
  );
}

final List<DeviceSpec> appleDevices = [
  _iphoneDuo(),
  _phone(
    id: 'apple.iphone-18-pro-max',
    name: 'iPhone 18 Pro Max',
    diagonal: 6.9,
    year: 2026,
    screens: [_iphone(const Size(440, 956), top: 62)],
  ),
  _phone(
    id: 'apple.iphone-18-pro',
    name: 'iPhone 18 Pro',
    diagonal: 6.3,
    year: 2026,
    screens: [_iphone(const Size(402, 874), top: 62)],
  ),
  _phone(
    id: 'apple.iphone-air',
    name: 'iPhone Air',
    diagonal: 6.5,
    year: 2025,
    frame: const DeviceFrame(
      bezel: EdgeInsets.all(7),
      outerRadius: 64,
      bodyColor: Color(0xFF2B2B2E),
      edgeColor: Color(0xFF8E8E93),
      buttons: _appleButtons,
    ),
    screens: [_iphone(const Size(420, 912), top: 62)],
  ),
  _phone(
    id: 'apple.iphone-17-pro-max',
    name: 'iPhone 17 Pro Max',
    diagonal: 6.9,
    year: 2025,
    screens: [_iphone(const Size(440, 956), top: 62)],
  ),
  _phone(
    id: 'apple.iphone-17-pro',
    name: 'iPhone 17 Pro',
    diagonal: 6.3,
    year: 2025,
    screens: [_iphone(const Size(402, 874), top: 62)],
  ),
  _phone(
    id: 'apple.iphone-17',
    name: 'iPhone 17',
    diagonal: 6.3,
    year: 2025,
    screens: [_iphone(const Size(402, 874), top: 62)],
  ),
  _phone(
    id: 'apple.iphone-17e',
    name: 'iPhone 17e',
    diagonal: 6.1,
    year: 2026,
    screens: [_iphone(const Size(390, 844), top: 47, cutout: _notch)],
  ),
  _phone(
    id: 'apple.iphone-16-pro-max',
    name: 'iPhone 16 Pro Max',
    diagonal: 6.9,
    year: 2024,
    screens: [_iphone(const Size(440, 956), top: 62)],
  ),
  _phone(
    id: 'apple.iphone-16-pro',
    name: 'iPhone 16 Pro',
    diagonal: 6.3,
    year: 2024,
    screens: [_iphone(const Size(402, 874), top: 62)],
  ),
  _phone(
    id: 'apple.iphone-16-plus',
    name: 'iPhone 16 Plus',
    diagonal: 6.7,
    year: 2024,
    screens: [_iphone(const Size(430, 932), top: 59)],
  ),
  _phone(
    id: 'apple.iphone-16',
    name: 'iPhone 16',
    diagonal: 6.1,
    year: 2024,
    screens: [_iphone(const Size(393, 852), top: 59)],
  ),
  _phone(
    id: 'apple.iphone-16e',
    name: 'iPhone 16e',
    diagonal: 6.1,
    year: 2025,
    screens: [_iphone(const Size(390, 844), top: 47, cutout: _notch)],
  ),
  _phone(
    id: 'apple.iphone-15-pro-max',
    name: 'iPhone 15 Pro Max',
    diagonal: 6.7,
    year: 2023,
    screens: [_iphone(const Size(430, 932), top: 59)],
  ),
  _phone(
    id: 'apple.iphone-15-pro',
    name: 'iPhone 15 Pro',
    diagonal: 6.1,
    year: 2023,
    screens: [_iphone(const Size(393, 852), top: 59)],
  ),
  _phone(
    id: 'apple.iphone-15-plus',
    name: 'iPhone 15 Plus',
    diagonal: 6.7,
    year: 2023,
    screens: [_iphone(const Size(430, 932), top: 59)],
  ),
  _phone(
    id: 'apple.iphone-15',
    name: 'iPhone 15',
    diagonal: 6.1,
    year: 2023,
    screens: [_iphone(const Size(393, 852), top: 59)],
  ),
  _phone(
    id: 'apple.iphone-14-pro-max',
    name: 'iPhone 14 Pro Max',
    diagonal: 6.7,
    year: 2022,
    screens: [_iphone(const Size(430, 932), top: 59)],
  ),
  _phone(
    id: 'apple.iphone-14-pro',
    name: 'iPhone 14 Pro',
    diagonal: 6.1,
    year: 2022,
    screens: [_iphone(const Size(393, 852), top: 59)],
  ),
  _phone(
    id: 'apple.iphone-14-plus',
    name: 'iPhone 14 Plus',
    diagonal: 6.7,
    year: 2022,
    screens: [_iphone(const Size(428, 926), top: 47, cutout: _notch)],
  ),
  _phone(
    id: 'apple.iphone-14',
    name: 'iPhone 14',
    diagonal: 6.1,
    year: 2022,
    screens: [_iphone(const Size(390, 844), top: 47, cutout: _notch)],
  ),
  _phone(
    id: 'apple.iphone-13-pro-max',
    name: 'iPhone 13 Pro Max',
    diagonal: 6.7,
    year: 2021,
    screens: [_iphone(const Size(428, 926), top: 47, cutout: _notch)],
  ),
  _phone(
    id: 'apple.iphone-13',
    name: 'iPhone 13',
    diagonal: 6.1,
    year: 2021,
    screens: [_iphone(const Size(390, 844), top: 47, cutout: _notch)],
  ),
  _phone(
    id: 'apple.iphone-13-mini',
    name: 'iPhone 13 mini',
    diagonal: 5.4,
    year: 2021,
    screens: [_iphone(const Size(360, 780), top: 50, cutout: _notch)],
  ),
  _phone(
    id: 'apple.iphone-12-pro-max',
    name: 'iPhone 12 Pro Max',
    diagonal: 6.7,
    year: 2020,
    screens: [_iphone(const Size(428, 926), top: 47, cutout: _notch)],
  ),
  _phone(
    id: 'apple.iphone-12',
    name: 'iPhone 12',
    diagonal: 6.1,
    year: 2020,
    screens: [_iphone(const Size(390, 844), top: 47, cutout: _notch)],
  ),
  _phone(
    id: 'apple.iphone-12-mini',
    name: 'iPhone 12 mini',
    diagonal: 5.4,
    year: 2020,
    screens: [_iphone(const Size(360, 780), top: 50, cutout: _notch)],
  ),
  _phone(
    id: 'apple.iphone-11-pro-max',
    name: 'iPhone 11 Pro Max',
    diagonal: 6.5,
    year: 2019,
    screens: [_iphone(const Size(414, 896), top: 48, cutout: _wideNotch)],
  ),
  _phone(
    id: 'apple.iphone-11',
    name: 'iPhone 11',
    diagonal: 6.1,
    year: 2019,
    screens: [
      _iphone(
        const Size(414, 896),
        top: 48,
        cutout: _wideNotch,
        pixelRatio: 2,
      ),
    ],
  ),
  _phone(
    id: 'apple.iphone-x',
    name: 'iPhone X / XS',
    diagonal: 5.8,
    year: 2017,
    screens: [_iphone(const Size(375, 812), top: 44, cutout: _wideNotch)],
  ),
  _phone(
    id: 'apple.iphone-se-3',
    name: 'iPhone SE (3rd gen)',
    diagonal: 4.7,
    year: 2022,
    frame: _homeButtonFrame,
    screens: [
      DeviceScreen(
        label: 'Main',
        logicalSize: const Size(375, 667),
        pixelRatio: 2,
        safeArea: const EdgeInsets.only(top: 20),
        safeAreaRotated: EdgeInsets.zero,
      ),
    ],
  ),
  _phone(
    id: 'apple.iphone-8-plus',
    name: 'iPhone 8 Plus',
    diagonal: 5.5,
    year: 2017,
    frame: _homeButtonFrame,
    screens: [
      DeviceScreen(
        label: 'Main',
        logicalSize: const Size(414, 736),
        pixelRatio: 3,
        safeArea: const EdgeInsets.only(top: 20),
        safeAreaRotated: EdgeInsets.zero,
      ),
    ],
  ),
  _phone(
    id: 'apple.iphone-se-1',
    name: 'iPhone SE (1st gen)',
    diagonal: 4.0,
    year: 2016,
    frame: _homeButtonFrame,
    screens: [
      DeviceScreen(
        label: 'Main',
        logicalSize: const Size(320, 568),
        pixelRatio: 2,
        safeArea: const EdgeInsets.only(top: 20),
        safeAreaRotated: EdgeInsets.zero,
      ),
    ],
  ),
  _tablet(
    id: 'apple.ipad-pro-13-m4',
    name: 'iPad Pro 13" (M4)',
    size: const Size(1032, 1376),
    diagonal: 13.0,
    year: 2024,
  ),
  _tablet(
    id: 'apple.ipad-pro-11-m4',
    name: 'iPad Pro 11" (M4)',
    size: const Size(834, 1210),
    diagonal: 11.0,
    year: 2024,
  ),
  _tablet(
    id: 'apple.ipad-air-13',
    name: 'iPad Air 13"',
    size: const Size(1024, 1366),
    diagonal: 12.9,
    year: 2024,
  ),
  _tablet(
    id: 'apple.ipad-air-11',
    name: 'iPad Air 11"',
    size: const Size(820, 1180),
    diagonal: 11.0,
    year: 2024,
  ),
  _tablet(
    id: 'apple.ipad-10',
    name: 'iPad (10th gen)',
    size: const Size(820, 1180),
    diagonal: 10.9,
    year: 2022,
  ),
  _tablet(
    id: 'apple.ipad-mini-7',
    name: 'iPad mini (A17 Pro)',
    size: const Size(744, 1133),
    diagonal: 8.3,
    year: 2024,
  ),
  _tablet(
    id: 'apple.ipad-9',
    name: 'iPad (9th gen)',
    size: const Size(810, 1080),
    diagonal: 10.2,
    year: 2021,
    radius: 6,
  ),
];
