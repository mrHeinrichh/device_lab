import 'package:flutter/widgets.dart';

import '../catalog/device_catalog.dart';
import '../model/device_spec.dart';

class DeviceLabController extends ChangeNotifier {
  DeviceLabController({
    String? initialDeviceId,
    this.enabled = true,
    Locale? locale,
    Alignment restoreAlignment = Alignment.bottomRight,
  })  : _restoreAlignment = restoreAlignment,
        _device = DeviceCatalog.byId(
              initialDeviceId ?? 'apple.iphone-17-pro',
            ) ??
            DeviceCatalog.all.first,
        _locale = locale {
    _orientation = _device.screenFor(_posture).naturalOrientation;
  }

  bool enabled;

  DeviceSpec _device;
  late Orientation _orientation;
  FoldPosture _posture = FoldPosture.flat;
  Size? _freeformSize;
  double _textScale = 1;
  Brightness _brightness = Brightness.light;
  Locale? _locale;
  bool _boldText = false;
  bool _highContrast = false;
  bool _invertColors = false;
  bool _disableAnimations = false;
  bool _accessibleNavigation = false;
  bool _showFrame = true;
  bool _showSafeAreas = false;
  bool _showRulers = false;
  bool _toolsVisible = true;
  bool _previewing = true;
  Alignment _restoreAlignment;

  DeviceSpec get device => _device;
  Orientation get orientation => _orientation;
  FoldPosture get posture => _posture;
  Size? get freeformSize => _freeformSize;
  bool get isFreeform => _freeformSize != null;
  double get textScale => _textScale;
  Brightness get brightness => _brightness;
  Locale? get locale => _locale;
  bool get boldText => _boldText;
  bool get highContrast => _highContrast;
  bool get invertColors => _invertColors;
  bool get disableAnimations => _disableAnimations;
  bool get accessibleNavigation => _accessibleNavigation;
  bool get showFrame => _showFrame && !isFreeform;
  bool get showSafeAreas => _showSafeAreas;
  bool get showRulers => _showRulers;
  bool get toolsVisible => _toolsVisible;

  bool get previewing => _previewing;

  bool get active => enabled && _previewing;

  Alignment get restoreAlignment => _restoreAlignment;

  DeviceScreen get screen {
    final base = _device.screenFor(_posture);
    final size = _freeformSize;
    if (size == null) return base;
    return base.copyWith(
      logicalSize: size,
      cutouts: const [],
      cornerRadius: 0,
    );
  }

  Size get logicalSize =>
      isFreeform ? _freeformSize! : screen.sizeFor(_orientation);

  bool get canRotate => screen.rotatable && !isFreeform;

  bool get canFold => _device.isFoldable;

  void selectDevice(DeviceSpec value) {
    if (_device.id == value.id && !isFreeform) return;
    _device = value;
    _freeformSize = null;
    _posture = FoldPosture.flat;
    _orientation = value.screenFor(_posture).naturalOrientation;
    notifyListeners();
  }

  void selectDeviceId(String id) {
    final found = DeviceCatalog.byId(id);
    if (found != null) selectDevice(found);
  }

  void setOrientation(Orientation value) {
    if (_orientation == value) return;
    _orientation = value;
    notifyListeners();
  }

  void toggleOrientation() => setOrientation(
        _orientation == Orientation.portrait
            ? Orientation.landscape
            : Orientation.portrait,
      );

  void setPosture(FoldPosture value) {
    if (_posture == value) return;
    final previous = _device.screenFor(_posture);
    _posture = value;
    final next = _device.screenFor(value);
    if (next.naturalOrientation != previous.naturalOrientation) {
      _orientation = next.naturalOrientation;
    }
    notifyListeners();
  }

  void setFreeformSize(Size? value) {
    _freeformSize = value == null
        ? null
        : Size(value.width.clamp(200, 8192), value.height.clamp(200, 8192));
    notifyListeners();
  }

  void setTextScale(double value) {
    _textScale = value.clamp(0.5, 3.5);
    notifyListeners();
  }

  void setBrightness(Brightness value) {
    _brightness = value;
    notifyListeners();
  }

  void setLocale(Locale? value) {
    _locale = value;
    notifyListeners();
  }

  void setEnabled(bool value) {
    enabled = value;
    notifyListeners();
  }

  void setBoldText(bool value) => _set(() => _boldText = value);
  void setHighContrast(bool value) => _set(() => _highContrast = value);
  void setInvertColors(bool value) => _set(() => _invertColors = value);
  void setDisableAnimations(bool value) =>
      _set(() => _disableAnimations = value);
  void setAccessibleNavigation(bool value) =>
      _set(() => _accessibleNavigation = value);
  void setShowFrame(bool value) => _set(() => _showFrame = value);
  void setShowSafeAreas(bool value) => _set(() => _showSafeAreas = value);
  void setShowRulers(bool value) => _set(() => _showRulers = value);
  void setToolsVisible(bool value) => _set(() => _toolsVisible = value);

  void setPreviewing(bool value) => _set(() => _previewing = value);

  void togglePreview() => setPreviewing(!_previewing);

  void setRestoreAlignment(Alignment value) =>
      _set(() => _restoreAlignment = value);

  void _set(VoidCallback mutate) {
    mutate();
    notifyListeners();
  }

  MediaQueryData resolveMediaQuery(MediaQueryData base) {
    final active = screen;
    final size = logicalSize;
    final padding =
        isFreeform ? EdgeInsets.zero : active.paddingFor(_orientation);
    return base.copyWith(
      size: size,
      devicePixelRatio: active.pixelRatio,
      padding: padding,
      viewPadding: padding,
      viewInsets: EdgeInsets.zero,
      systemGestureInsets: padding,
      textScaler: TextScaler.linear(_textScale),
      platformBrightness: _brightness,
      displayFeatures: isFreeform
          ? const []
          : active.displayFeaturesFor(_orientation, _posture),
      boldText: _boldText,
      highContrast: _highContrast,
      invertColors: _invertColors,
      disableAnimations: _disableAnimations,
      accessibleNavigation: _accessibleNavigation,
    );
  }
}
