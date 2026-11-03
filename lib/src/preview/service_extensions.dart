import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../catalog/device_catalog.dart';
import '../model/device_spec.dart';
import 'device_lab_controller.dart';

// Debug VM service extensions, so a coding agent or CI job can sweep a running
// app across a device category and collect layout errors and screenshots.
//
// Registered once per isolate by the first mounted DeviceLab. Handlers are plain
// async functions over a controller and a params map, so tests call them
// directly without a VM service.

const _defaultSettleMs = 600;
const _defaultPixelRatio = 0.5;
const _maxPixelRatio = 4.0;
const _packageTag = '[device_lab] ';

/// A bad request. [invalidParams] maps to the VM service's invalid-params code.
@visibleForTesting
class DeviceLabExtensionException implements Exception {
  const DeviceLabExtensionException(this.message, {this.invalidParams = false});

  final String message;
  final bool invalidParams;

  @override
  String toString() => message;
}

final List<_Mount> _mounts = [];
bool _registered = false;
bool _sweeping = false;

class _Mount {
  _Mount(this.controller, this.captureKey);

  final DeviceLabController controller;
  final GlobalKey captureKey;
}

/// Makes [controller] the target of the extensions until [detachExtensions].
///
/// The most recently attached controller that is enabled wins. [captureKey]
/// must sit on the `RepaintBoundary` around the previewed app.
void attachExtensions(DeviceLabController controller, GlobalKey captureKey) {
  _mounts.add(_Mount(controller, captureKey));
  _registerOnce();
}

/// Stops targeting [controller].
void detachExtensions(DeviceLabController controller) =>
    _mounts.removeWhere((m) => m.controller == controller);

/// The controller and capture key the extensions currently act on.
@visibleForTesting
({DeviceLabController controller, GlobalKey captureKey})?
    get currentExtensionTarget {
  final m = _current;
  return m == null
      ? null
      : (controller: m.controller, captureKey: m.captureKey);
}

_Mount? get _current {
  for (final m in _mounts.reversed) {
    if (m.controller.enabled) return m;
  }
  return null;
}

void _registerOnce() {
  if (_registered || kReleaseMode) return;
  _registered = true;
  _register('devices', (m, p) async => deviceLabDevices(p));
  _register('sweep', (m, p) => deviceLabSweep(m.controller, m.captureKey, p));
  _register('show', (m, p) => deviceLabShow(m.controller, p));
  _register('capture', (m, p) => deviceLabCapture(m.captureKey, p));
}

void _register(
  String name,
  Future<Map<String, Object?>> Function(_Mount, Map<String, String>) handler,
) {
  developer.registerExtension('ext.deviceLab.$name', (method, params) async {
    final mount = _current;
    if (mount == null && name != 'devices') {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        'No DeviceLab is mounted',
      );
    }
    try {
      final result =
          await handler(mount ?? _Mount(_noController, _noKey), params);
      return developer.ServiceExtensionResponse.result(jsonEncode(result));
    } on DeviceLabExtensionException catch (e) {
      return developer.ServiceExtensionResponse.error(
        e.invalidParams
            ? developer.ServiceExtensionResponse.invalidParams
            : developer.ServiceExtensionResponse.extensionError,
        e.message,
      );
    } catch (e) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        '$e',
      );
    }
  });
}

// `devices` needs no mounted lab; these stand in so the handler signature stays
// uniform. They are never read.
final DeviceLabController _noController = DeviceLabController(enabled: false);
final GlobalKey _noKey = GlobalKey();

Never _bad(String message) =>
    throw DeviceLabExtensionException(message, invalidParams: true);

/// The `devices` extension.
@visibleForTesting
Map<String, Object?> deviceLabDevices(Map<String, String> params) {
  final devices = _select(params);
  return {
    'count': devices.length,
    'devices': [
      for (final d in devices)
        {
          'id': d.id,
          'name': d.name,
          'category': d.category.name,
          'platform': d.targetPlatform.name,
          'size': _size(d.primaryScreen.sizeFor(
            d.primaryScreen.naturalOrientation,
          )),
          'rotatable': d.screens.any((s) => s.rotatable),
          'foldable': d.isFoldable,
        },
    ],
  };
}

List<DeviceSpec> _select(Map<String, String> params) {
  final idsParam = params['ids'];
  if (idsParam != null && idsParam.trim().isNotEmpty) {
    final ids = idsParam
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final unknown = ids.where((id) => DeviceCatalog.byId(id) == null).toList();
    if (unknown.isNotEmpty) _bad('Unknown device ids: ${unknown.join(', ')}');
    return [for (final id in ids) DeviceCatalog.byId(id)!];
  }

  DeviceCategory? category;
  final categoryParam = params['category'];
  if (categoryParam != null && categoryParam.isNotEmpty) {
    category = _enumByName(DeviceCategory.values, categoryParam);
    if (category == null) {
      _bad(
        'Unknown category "$categoryParam". '
        'Expected one of ${DeviceCategory.values.map((e) => e.name).join(', ')}.',
      );
    }
  }
  TargetPlatform? platform;
  final platformParam = params['platform'];
  if (platformParam != null && platformParam.isNotEmpty) {
    platform = _enumByName(TargetPlatform.values, platformParam);
    if (platform == null) {
      _bad(
        'Unknown platform "$platformParam". '
        'Expected one of ${TargetPlatform.values.map((e) => e.name).join(', ')}.',
      );
    }
  }
  return DeviceCatalog.all
      .where((d) =>
          (category == null || d.category == category) &&
          (platform == null || d.targetPlatform == platform))
      .toList(growable: false);
}

T? _enumByName<T extends Enum>(List<T> values, String name) {
  final wanted = name.toLowerCase();
  for (final v in values) {
    if (v.name.toLowerCase() == wanted) return v;
  }
  return null;
}

int _intParam(Map<String, String> params, String key, int fallback,
    {int min = 0}) {
  final raw = params[key];
  if (raw == null || raw.isEmpty) return fallback;
  final value = int.tryParse(raw);
  if (value == null || value < min) {
    _bad('"$key" must be an integer >= $min, got "$raw".');
  }
  return value;
}

double _pixelRatioParam(Map<String, String> params) {
  final raw = params['pixelRatio'];
  if (raw == null || raw.isEmpty) return _defaultPixelRatio;
  final value = double.tryParse(raw);
  if (value == null || value <= 0 || value > _maxPixelRatio) {
    _bad('"pixelRatio" must be a number in (0, $_maxPixelRatio], got "$raw".');
  }
  return value;
}

String _choice(Map<String, String> params, String key, List<String> allowed) {
  final raw = params[key];
  if (raw == null || raw.isEmpty) return allowed.first;
  if (!allowed.contains(raw)) {
    _bad('"$key" must be one of ${allowed.join(' | ')}, got "$raw".');
  }
  return raw;
}

List<double> _size(Size s) => [s.width, s.height];

/// The `sweep` extension.
@visibleForTesting
Future<Map<String, Object?>> deviceLabSweep(
  DeviceLabController controller,
  GlobalKey captureKey,
  Map<String, String> params,
) async {
  // Validate everything before touching state.
  var devices = _select(params);
  final offset = _intParam(params, 'offset', 0);
  final limit = _intParam(params, 'limit', devices.length, min: 1);
  final orientations = _choice(params, 'orientations', ['both', 'natural']);
  final postures = _choice(params, 'postures', ['all', 'every', 'open']);
  final screenshots =
      _choice(params, 'screenshots', ['none', 'failures', 'all']);
  final settleMs = _intParam(params, 'settleMs', _defaultSettleMs);
  final pixelRatio = _pixelRatioParam(params);
  devices = devices.skip(offset).take(limit).toList();

  if (_sweeping) {
    throw const DeviceLabExtensionException('sweep already running');
  }
  _sweeping = true;

  final prevDevice = controller.device;
  final prevFreeform = controller.freeformSize;
  final prevOrientation = controller.orientation;
  final prevPosture = controller.posture;
  final prevPreviewing = controller.previewing;
  final prevOnError = FlutterError.onError;
  List<String>? sink;
  FlutterError.onError = (details) {
    sink?.add(_describe(details));
    if (prevOnError != null) {
      prevOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final results = <Map<String, Object?>>[];
  var failed = 0;
  try {
    if (!prevPreviewing) controller.setPreviewing(true);
    for (final device in devices) {
      controller.selectDevice(device);
      final deviceCases = <FoldPosture?>[
        if (!device.isFoldable)
          null
        else
          ...switch (postures) {
            'every' => FoldPosture.values,
            'open' => const [FoldPosture.flat],
            _ => const [FoldPosture.folded, FoldPosture.flat],
          },
      ];
      for (final posture in deviceCases) {
        if (posture != null) controller.setPosture(posture);
        final natural = controller.screen.naturalOrientation;
        final rotations = orientations == 'both' && controller.canRotate
            ? Orientation.values
            : [natural];
        for (final orientation in rotations) {
          final errors = <String>[];
          sink = errors;
          controller.setOrientation(orientation);
          await _settle(settleMs);
          sink = null;
          final hasFailure = errors.any((e) => !e.startsWith(_packageTag));
          if (hasFailure) failed++;
          final record = _record(controller, errors);
          if (screenshots == 'all' ||
              (screenshots == 'failures' && hasFailure)) {
            record['screenshot'] = await _png(captureKey, pixelRatio);
          }
          results.add(record);
        }
      }
    }
  } finally {
    sink = null;
    FlutterError.onError = prevOnError;
    try {
      controller.selectDevice(prevDevice);
      controller.setPosture(prevPosture);
      controller.setOrientation(prevOrientation);
      if (prevFreeform != null) controller.setFreeformSize(prevFreeform);
      controller.setPreviewing(prevPreviewing);
    } finally {
      _sweeping = false;
    }
  }
  return {'count': results.length, 'failed': failed, 'results': results};
}

/// The `show` extension.
@visibleForTesting
Future<Map<String, Object?>> deviceLabShow(
  DeviceLabController controller,
  Map<String, String> params,
) async {
  final id = params['id'];
  if (id == null || id.isEmpty) _bad('"id" is required.');
  final device = DeviceCatalog.byId(id);
  if (device == null) _bad('Unknown device id "$id".');
  final orientationParam = params['orientation'];
  Orientation? orientation;
  if (orientationParam != null && orientationParam.isNotEmpty) {
    orientation = _enumByName(Orientation.values, orientationParam);
    if (orientation == null) {
      _bad('"orientation" must be portrait | landscape.');
    }
  }
  final postureParam = params['posture'];
  FoldPosture? posture;
  if (postureParam != null && postureParam.isNotEmpty) {
    posture = _enumByName(FoldPosture.values, postureParam);
    if (posture == null) {
      _bad('"posture" must be one of '
          '${FoldPosture.values.map((e) => e.name).join(' | ')}.');
    }
    if (!device.isFoldable) _bad('"${device.id}" is not foldable.');
  }
  final settleMs = _intParam(params, 'settleMs', _defaultSettleMs);

  final prevOnError = FlutterError.onError;
  final errors = <String>[];
  FlutterError.onError = (details) {
    errors.add(_describe(details));
    if (prevOnError != null) {
      prevOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  try {
    controller.setPreviewing(true);
    controller.selectDevice(device);
    if (posture != null) controller.setPosture(posture);
    if (orientation != null) controller.setOrientation(orientation);
    await _settle(settleMs);
  } finally {
    FlutterError.onError = prevOnError;
  }
  return _record(controller, errors);
}

/// The `capture` extension.
@visibleForTesting
Future<Map<String, Object?>> deviceLabCapture(
  GlobalKey captureKey,
  Map<String, String> params, [
  DeviceLabController? controller,
]) async {
  final pixelRatio = _pixelRatioParam(params);
  final c = controller ?? _current?.controller;
  if (c == null) {
    throw const DeviceLabExtensionException('No DeviceLab is mounted');
  }
  final record = _record(c, const []);
  record
    ..remove('errors')
    ..['screenshot'] = await _png(captureKey, pixelRatio);
  return record;
}

Map<String, Object?> _record(DeviceLabController c, List<String> errors) => {
      'id': c.device.id,
      'name': c.device.name,
      'orientation': c.orientation.name,
      'posture': c.canFold ? c.posture.name : null,
      'size': _size(c.logicalSize),
      'errors': errors,
    };

// RenderFlex and friends report an overflow once per render object, so a tree
// that has already overflowed on an earlier device (or on the one selected
// before the sweep) would stay silent. Reassembling the render tree, like a hot
// reload does, re-arms those reports without rebuilding any widget or State.
void _rearmOverflowReports() {
  for (final view in RendererBinding.instance.renderViews) {
    view.reassemble();
  }
}

Future<void> _settle(int settleMs) async {
  _rearmOverflowReports();
  await Future<void>.delayed(Duration(milliseconds: settleMs));
  await WidgetsBinding.instance.endOfFrame;
}

Future<String> _png(GlobalKey key, double pixelRatio) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) {
    throw const DeviceLabExtensionException(
      'The preview is not mounted, nothing to capture.',
    );
  }
  if (boundary.debugNeedsPaint) await WidgetsBinding.instance.endOfFrame;
  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw const DeviceLabExtensionException(
          'Could not encode the screenshot.');
    }
    return base64Encode(bytes.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}

final RegExp _location =
    RegExp(r'(?:file:///|package:)\S+?\.dart(?::\d+){0,2}');
final RegExp _ownPackage =
    RegExp(r'package:device_lab/|/device_lab(?:-[\w.+-]+)?/lib/');

String _describe(FlutterErrorDetails details) {
  final summary = details.summary.toString();
  final full = details.toString();
  // Prefer the "relevant error-causing widget" line over any other location.
  final marker = full.indexOf('relevant error-causing widget');
  final match =
      (marker >= 0 ? _location.firstMatch(full.substring(marker)) : null) ??
          _location.firstMatch(full);
  final location = match?.group(0);
  final text = location == null ? summary : '$summary ($location)';
  return location != null && _ownPackage.hasMatch(location)
      ? '$_packageTag$text'
      : text;
}
