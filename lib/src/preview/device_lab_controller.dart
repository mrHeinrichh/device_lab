import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../catalog/device_catalog.dart';
import '../model/device_spec.dart';
import 'device_lab_storage.dart';

/// Holds every piece of preview state and notifies when any of it changes.
///
/// Pass one to [DeviceLab] to drive the preview from your own code, or let
/// the widget create its own.
class DeviceLabController extends ChangeNotifier {
  DeviceLabController({
    String? initialDeviceId,
    this.enabled = !kReleaseMode,
    Locale? locale,
    Alignment restoreAlignment = Alignment.bottomRight,
    this.storage,
  })  : _restoreAlignment = restoreAlignment,
        _device = _resolveDevice(initialDeviceId, storage),
        _locale = locale {
    final storedPosture = storage?.read(storageKeyPosture);
    if (storedPosture != null && _device.isFoldable) {
      _posture = FoldPosture.values.asNameMap()[storedPosture] ?? _posture;
    }
    _orientation = _device.screenFor(_posture).naturalOrientation;
    final storedOrientation = storage?.read(storageKeyOrientation);
    if (storedOrientation != null) {
      _orientation =
          Orientation.values.asNameMap()[storedOrientation] ?? _orientation;
    }
  }

  /// The device selected when nothing else is remembered or requested.
  static const defaultDeviceId = 'apple.iphone-17-pro';

  /// Storage key holding the selected [DeviceSpec.id].
  static const storageKeyDevice = 'device_lab.device';

  /// Storage key holding the selected [Orientation].
  static const storageKeyOrientation = 'device_lab.orientation';

  /// Storage key holding the selected [FoldPosture].
  static const storageKeyPosture = 'device_lab.posture';

  static DeviceSpec _resolveDevice(String? requested, DeviceLabStorage? s) {
    final id = s?.read(storageKeyDevice) ?? requested ?? defaultDeviceId;
    return DeviceCatalog.byId(id) ??
        DeviceCatalog.byId(defaultDeviceId) ??
        DeviceCatalog.all.first;
  }

  /// Where the selection is remembered, or null to forget it on rebuild.
  final DeviceLabStorage? storage;

  /// Whether device_lab is available at all.
  ///
  /// This is the release-mode gate. [previewing] is the runtime toggle; see
  /// [active] for the combination.
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

  /// The selected device.
  DeviceSpec get device => _device;

  /// The orientation the device is being held in.
  Orientation get orientation => _orientation;

  /// How far the selected foldable is opened.
  FoldPosture get posture => _posture;

  /// The custom viewport size, or null when a catalog device is selected.
  Size? get freeformSize => _freeformSize;

  /// Whether a custom size is overriding the selected device.
  bool get isFreeform => _freeformSize != null;

  /// Simulated text scale factor.
  double get textScale => _textScale;

  /// Simulated platform brightness.
  Brightness get brightness => _brightness;

  /// Simulated locale, or null to use the app's default.
  Locale? get locale => _locale;

  /// Simulated bold-text accessibility setting.
  bool get boldText => _boldText;

  /// Simulated high-contrast accessibility setting.
  bool get highContrast => _highContrast;

  /// Simulated inverted-colours accessibility setting.
  bool get invertColors => _invertColors;

  /// Simulated reduce-motion accessibility setting.
  bool get disableAnimations => _disableAnimations;

  /// Simulated screen-reader navigation setting.
  bool get accessibleNavigation => _accessibleNavigation;

  /// Whether the device bezel is drawn. Always false in free-form mode.
  bool get showFrame => _showFrame && !isFreeform;

  /// Whether the safe-area overlay is drawn.
  bool get showSafeAreas => _showSafeAreas;

  /// Whether rulers are drawn.
  bool get showRulers => _showRulers;

  /// Whether the tools panel is expanded.
  bool get toolsVisible => _toolsVisible;

  /// Whether the preview is shown rather than the app's original screen.
  bool get previewing => _previewing;

  /// Whether the simulated [MediaQuery] is being applied.
  ///
  /// False when either the release gate [enabled] or the runtime toggle
  /// [previewing] is off, in which case the app sees the real window.
  bool get active => enabled && _previewing;

  /// The corner the restore button is docked to while the preview is hidden.
  Alignment get restoreAlignment => _restoreAlignment;

  /// The screen currently being simulated, honouring [posture] and any
  /// free-form size.
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

  /// The simulated viewport size in logical pixels.
  Size get logicalSize =>
      isFreeform ? _freeformSize! : screen.sizeFor(_orientation);

  /// Whether the orientation toggle applies right now.
  bool get canRotate => screen.rotatable && !isFreeform;

  /// Whether posture controls apply right now.
  bool get canFold => _device.isFoldable;

  /// Selects [value], clearing any free-form size and adopting the device's
  /// natural orientation.
  void selectDevice(DeviceSpec value) {
    if (_device.id == value.id && !isFreeform) return;
    _device = value;
    _freeformSize = null;
    _posture = FoldPosture.flat;
    _orientation = value.screenFor(_posture).naturalOrientation;
    _persist();
    notifyListeners();
  }

  /// Selects the catalog device with the given id, if it exists.
  void selectDeviceId(String id) {
    final found = DeviceCatalog.byId(id);
    if (found != null) selectDevice(found);
  }

  /// Sets the orientation the device is held in.
  void setOrientation(Orientation value) {
    if (_orientation == value) return;
    _orientation = value;
    _persist();
    notifyListeners();
  }

  /// Switches between portrait and landscape.
  void toggleOrientation() => setOrientation(
        _orientation == Orientation.portrait
            ? Orientation.landscape
            : Orientation.portrait,
      );

  /// Sets the fold posture, switching screens and orientation to match.
  void setPosture(FoldPosture value) {
    if (_posture == value) return;
    final previous = _device.screenFor(_posture);
    _posture = value;
    final next = _device.screenFor(value);
    if (next.naturalOrientation != previous.naturalOrientation) {
      _orientation = next.naturalOrientation;
    }
    _persist();
    notifyListeners();
  }

  /// Overrides the viewport with an arbitrary size, or clears it with null.
  void setFreeformSize(Size? value) {
    _freeformSize = value == null
        ? null
        : Size(value.width.clamp(200, 8192), value.height.clamp(200, 8192));
    notifyListeners();
  }

  /// Sets the simulated text scale, clamped to between 0.5 and 3.5.
  void setTextScale(double value) {
    _textScale = value.clamp(0.5, 3.5);
    notifyListeners();
  }

  /// Sets the simulated platform brightness.
  void setBrightness(Brightness value) {
    _brightness = value;
    notifyListeners();
  }

  /// Sets the simulated locale.
  void setLocale(Locale? value) {
    _locale = value;
    notifyListeners();
  }

  /// Turns device_lab on or off entirely.
  void setEnabled(bool value) {
    enabled = value;
    notifyListeners();
  }

  /// Sets the simulated bold-text setting.
  void setBoldText(bool value) => _set(() => _boldText = value);

  /// Sets the simulated high-contrast setting.
  void setHighContrast(bool value) => _set(() => _highContrast = value);

  /// Sets the simulated inverted-colours setting.
  void setInvertColors(bool value) => _set(() => _invertColors = value);

  /// Sets the simulated reduce-motion setting.
  void setDisableAnimations(bool value) =>
      _set(() => _disableAnimations = value);

  /// Sets the simulated screen-reader navigation setting.
  void setAccessibleNavigation(bool value) =>
      _set(() => _accessibleNavigation = value);

  /// Shows or hides the device bezel.
  void setShowFrame(bool value) => _set(() => _showFrame = value);

  /// Shows or hides the safe-area overlay.
  void setShowSafeAreas(bool value) => _set(() => _showSafeAreas = value);

  /// Shows or hides the rulers.
  void setShowRulers(bool value) => _set(() => _showRulers = value);

  /// Expands or collapses the tools panel.
  void setToolsVisible(bool value) => _set(() => _toolsVisible = value);

  /// Shows the preview, or the app's original screen.
  void setPreviewing(bool value) => _set(() => _previewing = value);

  /// Flips between the preview and the original screen.
  void togglePreview() => setPreviewing(!_previewing);

  /// Docks the restore button to the given corner.
  void setRestoreAlignment(Alignment value) =>
      _set(() => _restoreAlignment = value);

  void _persist() {
    final store = storage;
    if (store == null) return;
    store.write(storageKeyDevice, _device.id);
    store.write(storageKeyOrientation, _orientation.name);
    store.write(storageKeyPosture, _posture.name);
  }

  void _set(VoidCallback mutate) {
    mutate();
    notifyListeners();
  }

  /// [base] with every simulated value applied.
  ///
  /// This is what [DeviceLab.appBuilder] installs below your `MaterialApp`,
  /// including display features for folds and cutouts.
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
