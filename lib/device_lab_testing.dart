/// Golden-test helpers that reuse the same device specs as the preview.
library;

export 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

export 'src/model/device_spec.dart';
export 'src/catalog/device_catalog.dart' show DeviceCatalog;
export 'src/testing/device_tester.dart' show DeviceLabTester, goldenNameFor;
