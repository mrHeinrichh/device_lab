/// Device preview for Flutter: an up-to-date device catalog, real display
/// features for foldables and cutouts, free-form resolutions and a runtime
/// preview toggle.
library;

export 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

export 'src/catalog/android_devices.dart'
    show pixelDevices, samsungDevices, foldableDevices;
export 'src/catalog/flip_devices.dart' show flipDevices;
export 'src/catalog/generic_devices.dart'
    show genericResolutions, wearableDevices;
export 'src/catalog/oem_devices.dart' show oemDevices;
export 'src/catalog/apple_devices.dart' show appleDevices;
export 'src/catalog/desktop_devices.dart'
    show desktopDevices, breakpointDevices;
export 'src/catalog/device_catalog.dart' show DeviceCatalog, DeviceSpecCodec;
export 'src/model/device_spec.dart';
export 'src/model/fold_query.dart' show FoldQuery, FoldQueryContext;
export 'src/preview/device_lab.dart'
    show DeviceLab, DeviceLabScope, isDeviceLabAvailable;
export 'src/preview/device_lab_controller.dart' show DeviceLabController;
export 'src/preview/device_lab_storage.dart'
    show DeviceLabStorage, SessionDeviceLabStorage;
