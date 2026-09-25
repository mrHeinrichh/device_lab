import 'package:flutter/widgets.dart';

import '../model/device_spec.dart';

DeviceSpec _desktop({
  required String id,
  required String name,
  required DevicePlatform platform,
  required Size size,
  double pixelRatio = 2,
  String? vendor,
  double? diagonalInches,
}) =>
    DeviceSpec(
      id: id,
      name: name,
      vendor: vendor,
      platform: platform,
      category: DeviceCategory.desktop,
      diagonalInches: diagonalInches,
      frame: const DeviceFrame(
        bezel: EdgeInsets.fromLTRB(14, 14, 14, 14),
        outerRadius: 14,
        bodyColor: Color(0xFF3A3A3D),
        edgeColor: Color(0xFF7A7A80),
      ),
      screens: [
        DeviceScreen(
          label: 'Display',
          logicalSize: size,
          pixelRatio: pixelRatio,
          safeArea: EdgeInsets.zero,
          safeAreaRotated: EdgeInsets.zero,
          cornerRadius: 6,
          rotatable: false,
        ),
      ],
    );

final List<DeviceSpec> desktopDevices = [
  _desktop(
    id: 'apple.macbook-pro-16',
    name: 'MacBook Pro 16"',
    vendor: 'Apple',
    platform: DevicePlatform.macos,
    size: const Size(1728, 1117),
    diagonalInches: 16.2,
  ),
  _desktop(
    id: 'apple.macbook-pro-14',
    name: 'MacBook Pro 14"',
    vendor: 'Apple',
    platform: DevicePlatform.macos,
    size: const Size(1512, 982),
    diagonalInches: 14.2,
  ),
  _desktop(
    id: 'apple.macbook-air-13',
    name: 'MacBook Air 13"',
    vendor: 'Apple',
    platform: DevicePlatform.macos,
    size: const Size(1280, 832),
    diagonalInches: 13.6,
  ),
  _desktop(
    id: 'apple.studio-display',
    name: 'Studio Display 27"',
    vendor: 'Apple',
    platform: DevicePlatform.macos,
    size: const Size(2560, 1440),
    diagonalInches: 27,
  ),
  _desktop(
    id: 'microsoft.surface-laptop-7',
    name: 'Surface Laptop 7',
    vendor: 'Microsoft',
    platform: DevicePlatform.windows,
    size: const Size(1500, 1000),
    pixelRatio: 1.5,
    diagonalInches: 13.8,
  ),
  _desktop(
    id: 'generic.windows-1080p',
    name: 'Windows 1080p',
    platform: DevicePlatform.windows,
    size: const Size(1920, 1080),
    pixelRatio: 1,
  ),
  _desktop(
    id: 'generic.windows-1440p',
    name: 'Windows 1440p',
    platform: DevicePlatform.windows,
    size: const Size(2560, 1440),
    pixelRatio: 1,
  ),
  _desktop(
    id: 'generic.linux-1080p',
    name: 'Linux 1080p',
    platform: DevicePlatform.linux,
    size: const Size(1920, 1080),
    pixelRatio: 1,
  ),
];

DeviceSpec _breakpoint(String id, String name, Size size) => DeviceSpec(
      id: id,
      name: name,
      platform: DevicePlatform.web,
      category: DeviceCategory.desktop,
      frame: DeviceFrame.none,
      screens: [
        DeviceScreen(
          label: 'Viewport',
          logicalSize: size,
          pixelRatio: 1,
          safeArea: EdgeInsets.zero,
          safeAreaRotated: EdgeInsets.zero,
          rotatable: false,
        ),
      ],
    );

final List<DeviceSpec> breakpointDevices = [
  _breakpoint('web.xs', 'Breakpoint XS (360)', const Size(360, 800)),
  _breakpoint('web.sm', 'Breakpoint SM (600)', const Size(600, 900)),
  _breakpoint('web.md', 'Breakpoint MD (840)', const Size(840, 1000)),
  _breakpoint('web.lg', 'Breakpoint LG (1280)', const Size(1280, 900)),
  _breakpoint('web.xl', 'Breakpoint XL (1600)', const Size(1600, 1000)),
];
