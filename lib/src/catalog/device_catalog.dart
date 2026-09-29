import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../model/device_spec.dart';
import 'android_devices.dart';
import 'apple_devices.dart';
import 'desktop_devices.dart';
import 'generic_devices.dart';
import 'oem_devices.dart';

/// The registry of devices available to the preview and to golden tests.
///
/// Ships with phones, foldables, tablets, desktops, wearables and generic
/// resolution presets. Extend it at runtime with [register] or [loadJson] so
/// new hardware does not require a new release of this package.
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

  /// Every registered device.
  static List<DeviceSpec> get all => _devices.values.toList(growable: false);

  /// The device with the given [DeviceSpec.id], or null.
  static DeviceSpec? byId(String id) => _devices[id];

  /// Adds [device], replacing any existing entry with the same id.
  static void register(DeviceSpec device) => _devices[device.id] = device;

  /// Adds each of [devices], replacing entries with matching ids.
  static void registerAll(Iterable<DeviceSpec> devices) {
    for (final d in devices) {
      register(d);
    }
  }

  /// Removes the device with the given id.
  static void remove(String id) => _devices.remove(id);

  /// Devices matching every non-null filter.
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
              (releasedAfter == null || (d.releaseYear ?? 0) >= releasedAfter))
          .toList(growable: false);

  /// Devices whose name, id or vendor contains [term], ignoring case.
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

  /// Every known vendor name, sorted.
  static List<String> get vendors =>
      (all.map((d) => d.vendor).whereType<String>().toSet().toList()..sort());

  /// Registers devices from a JSON document and returns how many were added.
  ///
  /// Accepts either a bare list or an object with a `devices` key. Use this to
  /// ship new hardware as an asset instead of waiting on a package release.
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

  /// The whole catalog as indented JSON, suitable for [loadJson].
  static String exportJson() => const JsonEncoder.withIndent('  ')
      .convert({'devices': all.map(DeviceSpecCodec.toJson).toList()});
}

/// Converts [DeviceSpec] to and from the JSON shape [DeviceCatalog] accepts.
abstract final class DeviceSpecCodec {
  /// Reads a device from its JSON representation.
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

  /// Writes [d] to the JSON representation [fromJson] accepts.
  static Map<String, dynamic> toJson(DeviceSpec d) => {
        'id': d.id,
        'name': d.name,
        if (d.vendor != null) 'vendor': d.vendor,
        'platform': d.platform.name,
        'category': d.category.name,
        if (d.diagonalInches != null) 'diagonalInches': d.diagonalInches,
        if (d.releaseYear != null) 'releaseYear': d.releaseYear,
        'frame': _frameToJson(d.frame),
        'screens': d.screens.map(_screenToJson).toList(),
      };

  static DeviceFrame _frameFromJson(Map<String, dynamic>? json) {
    if (json == null) return const DeviceFrame();
    final spine = json['spine'] as Map<String, dynamic>?;
    return DeviceFrame(
      bezel: _insetsFromJson(json['bezel']),
      outerRadius: (json['outerRadius'] as num?)?.toDouble() ?? 48,
      corners: json['corners'] == null ? null : _radiiFromJson(json['corners']),
      bodyColor: Color(json['bodyColor'] as int? ?? 0xFF1C1C1E),
      edgeColor: Color(json['edgeColor'] as int? ?? 0xFF48484A),
      rimWidth: (json['rimWidth'] as num?)?.toDouble() ?? 3,
      buttons: ((json['buttons'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((b) => DeviceButton(
                AxisDirection.values.byName(b['side'] as String),
                (b['start'] as num).toDouble(),
                (b['length'] as num).toDouble(),
              ))
          .toList(),
      spine: spine == null
          ? null
          : FrameSpine(
              side: AxisDirection.values.byName(spine['side'] as String),
              width: (spine['width'] as num?)?.toDouble() ?? 9,
              color: Color(spine['color'] as int? ?? 0xFF8E8A80),
            ),
    );
  }

  static Map<String, dynamic> _frameToJson(DeviceFrame f) => {
        'bezel': _insetsToJson(f.bezel),
        'outerRadius': f.outerRadius,
        if (f.corners != null) 'corners': _radiiToJson(f.corners!),
        'bodyColor': f.bodyColor.toARGB32(),
        'edgeColor': f.edgeColor.toARGB32(),
        'rimWidth': f.rimWidth,
        if (f.buttons.isNotEmpty)
          'buttons': f.buttons
              .map((b) => {
                    'side': b.side.name,
                    'start': b.start,
                    'length': b.length,
                  })
              .toList(),
        if (f.spine != null)
          'spine': {
            'side': f.spine!.side.name,
            'width': f.spine!.width,
            'color': f.spine!.color.toARGB32(),
          },
      };

  static DeviceScreen _screenFromJson(Map<String, dynamic> json) =>
      DeviceScreen(
        label: json['label'] as String? ?? 'Main',
        logicalSize: _sizeFromJson(json['logicalSize']),
        pixelRatio: (json['pixelRatio'] as num).toDouble(),
        ppi: (json['ppi'] as num?)?.toDouble(),
        safeArea: _insetsFromJson(json['safeArea']),
        safeAreaRotated: json['safeAreaRotated'] == null
            ? null
            : _insetsFromJson(json['safeAreaRotated']),
        naturalOrientation:
            (json['naturalOrientation'] as String?) == 'landscape'
                ? Orientation.landscape
                : Orientation.portrait,
        cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 0,
        corners:
            json['corners'] == null ? null : _radiiFromJson(json['corners']),
        rotatable: json['rotatable'] as bool? ?? true,
        frame: json['frame'] == null
            ? null
            : _frameFromJson(json['frame'] as Map<String, dynamic>),
        cutouts: ((json['cutouts'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((c) => ScreenCutout(
                  shape: CutoutShape.values.byName(c['shape'] as String),
                  size: _sizeFromJson(c['size']),
                  alignment: Alignment(
                    (c['ax'] as num?)?.toDouble() ?? 0,
                    (c['ay'] as num?)?.toDouble() ?? -1,
                  ),
                  offset: Offset(
                    (c['dx'] as num?)?.toDouble() ?? 0,
                    (c['dy'] as num?)?.toDouble() ?? 0,
                  ),
                  obstructing: c['obstructing'] as bool? ?? true,
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
        if (s.ppi != null) 'ppi': s.ppi,
        'safeArea': _insetsToJson(s.safeArea),
        'safeAreaRotated': _insetsToJson(s.safeAreaRotated),
        'naturalOrientation': s.naturalOrientation.name,
        'cornerRadius': s.cornerRadius,
        if (s.corners != null) 'corners': _radiiToJson(s.corners!),
        'rotatable': s.rotatable,
        if (s.frame != null) 'frame': _frameToJson(s.frame!),
        if (s.cutouts.isNotEmpty)
          'cutouts': s.cutouts
              .map((c) => {
                    'shape': c.shape.name,
                    'size': _sizeToJson(c.size),
                    'ax': c.alignment.x,
                    'ay': c.alignment.y,
                    'dx': c.offset.dx,
                    'dy': c.offset.dy,
                    'obstructing': c.obstructing,
                  })
              .toList(),
        if (s.hinge != null)
          'hinge': {
            'axis': s.hinge!.axis.name,
            'thickness': s.hinge!.thickness,
          },
      };

  static BorderRadius _radiiFromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    Radius r(String key) => Radius.circular((map[key] as num? ?? 0).toDouble());
    return BorderRadius.only(
      topLeft: r('tl'),
      topRight: r('tr'),
      bottomRight: r('br'),
      bottomLeft: r('bl'),
    );
  }

  static Map<String, dynamic> _radiiToJson(BorderRadius r) => {
        'tl': r.topLeft.x,
        'tr': r.topRight.x,
        'br': r.bottomRight.x,
        'bl': r.bottomLeft.x,
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
