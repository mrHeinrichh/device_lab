import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../model/device_spec.dart';
import 'android_devices.dart';
import 'apple_devices.dart';
import 'desktop_devices.dart';
import 'generic_devices.dart';
import 'oem_devices.dart';

abstract final class DeviceCatalog {
  static final Map<String, DeviceSpec> _devices = {
    for (final d in [
      ...appleDevices,
      ...pixelDevices,
      ...samsungDevices,
      ...oemDevices,
      ...foldableDevices,
      ...flipDevices,
      ...desktopDevices,
      ...breakpointDevices,
      ...genericResolutions,
      ...wearableDevices,
    ])
      d.id: d,
  };

  static List<DeviceSpec> get all => _devices.values.toList(growable: false);

  static DeviceSpec? byId(String id) => _devices[id];

  static void register(DeviceSpec device) => _devices[device.id] = device;

  static void registerAll(Iterable<DeviceSpec> devices) {
    for (final d in devices) {
      register(d);
    }
  }

  static void remove(String id) => _devices.remove(id);

  static List<DeviceSpec> query({
    DevicePlatform? platform,
    DeviceCategory? category,
    String? vendor,
    int? releasedAfter,
  }) =>
      all
          .where((d) =>
              (platform == null || d.platform == platform) &&
              (category == null || d.category == category) &&
              (vendor == null || d.vendor == vendor) &&
              (releasedAfter == null ||
                  (d.releaseYear ?? 0) >= releasedAfter))
          .toList(growable: false);

  static List<DeviceSpec> search(String term) {
    final q = term.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            d.id.toLowerCase().contains(q) ||
            (d.vendor ?? '').toLowerCase().contains(q))
        .toList(growable: false);
  }

  static List<String> get vendors =>
      (all.map((d) => d.vendor).whereType<String>().toSet().toList()..sort());

  static int loadJson(String source) {
    final decoded = jsonDecode(source);
    final list = decoded is Map<String, dynamic>
        ? (decoded['devices'] as List<dynamic>)
        : decoded as List<dynamic>;
    final parsed = list
        .cast<Map<String, dynamic>>()
        .map(DeviceSpecCodec.fromJson)
        .toList();
    registerAll(parsed);
    return parsed.length;
  }

  static String exportJson() => const JsonEncoder.withIndent('  ')
      .convert({'devices': all.map(DeviceSpecCodec.toJson).toList()});
}

abstract final class DeviceSpecCodec {
  static DeviceSpec fromJson(Map<String, dynamic> json) => DeviceSpec(
        id: json['id'] as String,
        name: json['name'] as String,
        vendor: json['vendor'] as String?,
        platform: DevicePlatform.values.byName(json['platform'] as String),
        category: DeviceCategory.values.byName(json['category'] as String),
        diagonalInches: (json['diagonalInches'] as num?)?.toDouble(),
        releaseYear: json['releaseYear'] as int?,
        frame: _frameFromJson(json['frame'] as Map<String, dynamic>?),
        screens: (json['screens'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(_screenFromJson)
            .toList(),
      );

  static Map<String, dynamic> toJson(DeviceSpec d) => {
        'id': d.id,
        'name': d.name,
        if (d.vendor != null) 'vendor': d.vendor,
        'platform': d.platform.name,
        'category': d.category.name,
        if (d.diagonalInches != null) 'diagonalInches': d.diagonalInches,
        if (d.releaseYear != null) 'releaseYear': d.releaseYear,
        'frame': {
          'bezel': _insetsToJson(d.frame.bezel),
          'outerRadius': d.frame.outerRadius,
          'bodyColor': d.frame.bodyColor.toARGB32(),
          'edgeColor': d.frame.edgeColor.toARGB32(),
        },
        'screens': d.screens.map(_screenToJson).toList(),
      };

  static DeviceFrame _frameFromJson(Map<String, dynamic>? json) {
    if (json == null) return const DeviceFrame();
    return DeviceFrame(
      bezel: _insetsFromJson(json['bezel']),
      outerRadius: (json['outerRadius'] as num?)?.toDouble() ?? 48,
      bodyColor: Color(json['bodyColor'] as int? ?? 0xFF1C1C1E),
      edgeColor: Color(json['edgeColor'] as int? ?? 0xFF48484A),
    );
  }

  static DeviceScreen _screenFromJson(Map<String, dynamic> json) =>
      DeviceScreen(
        label: json['label'] as String? ?? 'Main',
        logicalSize: _sizeFromJson(json['logicalSize']),
        pixelRatio: (json['pixelRatio'] as num).toDouble(),
        safeArea: _insetsFromJson(json['safeArea']),
        safeAreaRotated: json['safeAreaRotated'] == null
            ? null
            : _insetsFromJson(json['safeAreaRotated']),
        naturalOrientation:
            (json['naturalOrientation'] as String?) == 'landscape'
                ? Orientation.landscape
                : Orientation.portrait,
        cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 0,
        rotatable: json['rotatable'] as bool? ?? true,
        cutouts: ((json['cutouts'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((c) => ScreenCutout(
                  shape: CutoutShape.values.byName(c['shape'] as String),
                  size: _sizeFromJson(c['size']),
                  offset: Offset(
                    (c['dx'] as num?)?.toDouble() ?? 0,
                    (c['dy'] as num?)?.toDouble() ?? 0,
                  ),
                ))
            .toList(),
        hinge: json['hinge'] == null
            ? null
            : HingeSpec(
                axis: (json['hinge']['axis'] as String) == 'vertical'
                    ? Axis.vertical
                    : Axis.horizontal,
                thickness:
                    ((json['hinge']['thickness'] as num?) ?? 0).toDouble(),
              ),
      );

  static Map<String, dynamic> _screenToJson(DeviceScreen s) => {
        'label': s.label,
        'logicalSize': _sizeToJson(s.logicalSize),
        'pixelRatio': s.pixelRatio,
        'safeArea': _insetsToJson(s.safeArea),
        'safeAreaRotated': _insetsToJson(s.safeAreaRotated),
        'naturalOrientation': s.naturalOrientation.name,
        'cornerRadius': s.cornerRadius,
        'rotatable': s.rotatable,
        if (s.cutouts.isNotEmpty)
          'cutouts': s.cutouts
              .map((c) => {
                    'shape': c.shape.name,
                    'size': _sizeToJson(c.size),
                    'dx': c.offset.dx,
                    'dy': c.offset.dy,
                  })
              .toList(),
        if (s.hinge != null)
          'hinge': {
            'axis': s.hinge!.axis.name,
            'thickness': s.hinge!.thickness,
          },
      };

  static Size _sizeFromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return Size((map['w'] as num).toDouble(), (map['h'] as num).toDouble());
  }

  static Map<String, dynamic> _sizeToJson(Size s) =>
      {'w': s.width, 'h': s.height};

  static EdgeInsets _insetsFromJson(dynamic json) {
    if (json == null) return EdgeInsets.zero;
    final map = json as Map<String, dynamic>;
    return EdgeInsets.only(
      left: (map['l'] as num?)?.toDouble() ?? 0,
      top: (map['t'] as num?)?.toDouble() ?? 0,
      right: (map['r'] as num?)?.toDouble() ?? 0,
      bottom: (map['b'] as num?)?.toDouble() ?? 0,
    );
  }

  static Map<String, dynamic> _insetsToJson(EdgeInsets e) =>
      {'l': e.left, 't': e.top, 'r': e.right, 'b': e.bottom};
}
