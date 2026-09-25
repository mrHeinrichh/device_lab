import 'package:flutter/widgets.dart';

import '../model/device_spec.dart';

DeviceSpec _viewport({
  required String id,
  required String name,
  required Size size,
  required DeviceCategory category,
  required DevicePlatform platform,
  double pixelRatio = 1,
  EdgeInsets safeArea = EdgeInsets.zero,
}) =>
    DeviceSpec(
      id: id,
      name: name,
      vendor: 'Generic',
      platform: platform,
      category: category,
      frame: DeviceFrame.none,
      screens: [
        DeviceScreen(
          label: 'Viewport',
          logicalSize: size,
          pixelRatio: pixelRatio,
          safeArea: safeArea,
          safeAreaRotated: safeArea,
        ),
      ],
    );

DeviceSpec _phoneRes(String label, Size size, double dpr) => _viewport(
      id: 'res.phone-${size.width.toInt()}x${size.height.toInt()}',
      name: label,
      size: size,
      pixelRatio: dpr,
      category: DeviceCategory.phone,
      platform: DevicePlatform.android,
      safeArea: const EdgeInsets.only(top: 24, bottom: 24),
    );

DeviceSpec _tabletRes(String label, Size size, double dpr) => _viewport(
      id: 'res.tablet-${size.width.toInt()}x${size.height.toInt()}',
      name: label,
      size: size,
      pixelRatio: dpr,
      category: DeviceCategory.tablet,
      platform: DevicePlatform.android,
      safeArea: const EdgeInsets.only(top: 24, bottom: 20),
    );

DeviceSpec _desktopRes(String label, Size size, double dpr) => _viewport(
      id: 'res.desktop-${size.width.toInt()}x${size.height.toInt()}',
      name: label,
      size: size,
      pixelRatio: dpr,
      category: DeviceCategory.desktop,
      platform: DevicePlatform.web,
    );

final List<DeviceSpec> genericResolutions = [
  _phoneRes('320 × 568  (small phone)', const Size(320, 568), 2),
  _phoneRes('360 × 640  (HD)', const Size(360, 640), 2),
  _phoneRes('360 × 800  (HD+)', const Size(360, 800), 3),
  _phoneRes('375 × 667  (compact)', const Size(375, 667), 2),
  _phoneRes('390 × 844  (standard)', const Size(390, 844), 3),
  _phoneRes('393 × 873  (FHD+)', const Size(393, 873), 2.75),
  _phoneRes('412 × 915  (large)', const Size(412, 915), 2.625),
  _phoneRes('428 × 926  (max)', const Size(428, 926), 3),
  _phoneRes('480 × 1040 (tall)', const Size(480, 1040), 2.5),
  _tabletRes('600 × 960  (small tablet)', const Size(600, 960), 2),
  _tabletRes('768 × 1024 (classic tablet)', const Size(768, 1024), 2),
  _tabletRes('800 × 1280 (Android tablet)', const Size(800, 1280), 2),
  _tabletRes('834 × 1112 (10")', const Size(834, 1112), 2),
  _tabletRes('1024 × 1366 (large tablet)', const Size(1024, 1366), 2),
  _desktopRes('1280 × 720  (HD)', const Size(1280, 720), 1),
  _desktopRes('1366 × 768  (laptop)', const Size(1366, 768), 1),
  _desktopRes('1440 × 900  (WXGA+)', const Size(1440, 900), 1),
  _desktopRes('1536 × 864  (scaled HD)', const Size(1536, 864), 1),
  _desktopRes('1920 × 1080 (FHD)', const Size(1920, 1080), 1),
  _desktopRes('2560 × 1440 (QHD)', const Size(2560, 1440), 1),
  _desktopRes('3440 × 1440 (ultrawide)', const Size(3440, 1440), 1),
  _desktopRes('3840 × 2160 (4K)', const Size(3840, 2160), 1),
];

final List<DeviceSpec> wearableDevices = [
  _viewport(
    id: 'watch.apple-ultra',
    name: 'Apple Watch Ultra (49mm)',
    size: const Size(205, 251),
    pixelRatio: 2,
    category: DeviceCategory.watch,
    platform: DevicePlatform.ios,
  ),
  _viewport(
    id: 'watch.apple-45',
    name: 'Apple Watch (45mm)',
    size: const Size(198, 242),
    pixelRatio: 2,
    category: DeviceCategory.watch,
    platform: DevicePlatform.ios,
  ),
  _viewport(
    id: 'watch.wear-os-round',
    name: 'Wear OS (round 454px)',
    size: const Size(227, 227),
    pixelRatio: 2,
    category: DeviceCategory.watch,
    platform: DevicePlatform.android,
  ),
  _viewport(
    id: 'tv.android-1080p',
    name: 'Android TV 1080p',
    size: const Size(960, 540),
    pixelRatio: 2,
    category: DeviceCategory.tv,
    platform: DevicePlatform.android,
  ),
  _viewport(
    id: 'tv.android-4k',
    name: 'Android TV 4K',
    size: const Size(960, 540),
    pixelRatio: 4,
    category: DeviceCategory.tv,
    platform: DevicePlatform.android,
  ),
];
