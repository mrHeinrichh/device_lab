## 0.1.1

- Document the public API so the reference on pub.dev is usable.
- Add screenshots of the preview, a flip-phone cover screen and the hidden
  state.

## 0.1.0

- Initial release.
- 149 devices across 16 vendors: iPhone (including iPhone Duo and the 18 Pro
  line), Pixel, Galaxy S/A, book-folds, flip phones, iPads, Android tablets,
  laptops and monitors, watches, TV, plus generic resolution presets from
  320x568 to 4K.
- `naturalOrientation` on `DeviceScreen`, so landscape-natural screens such as
  the iPhone Duo's inner display resolve size, safe area and hinge axis
  correctly; `safeArea` / `safeAreaRotated` are relative to it.
- Hinge axis rotates with the device, so a book fold becomes a horizontal
  separator when held in the other orientation.
- Real `DisplayFeature` simulation: folds, hinges, notches, Dynamic Island and
  punch holes are injected into `MediaQuery`, so `DisplayFeatureSubScreen`,
  dialog placement and two-pane layouts behave as they do on the device.
- Fold postures (cover / half-open / unfolded) with per-posture screens.
- Free-form resolutions for any viewport not in the catalog.
- Runtime catalog extension via `DeviceCatalog.register` and
  `DeviceCatalog.loadJson`, so new hardware does not require a package release.
- Runtime "show original screen" toggle: hides the frame, tools and
  `MediaQuery` override so the app fills the window. Driven by the tools-panel
  button, Ctrl/Cmd+Shift+D, a draggable restore pill, or
  `DeviceLab.togglePreview(context)`. App state survives the toggle.
- The restore pill docks to the nearest corner when dragged, Flutter
  Inspector style, and its corner is configurable via
  `restoreButtonAlignment` and persists across toggles.
- `TargetPlatform` follows the selected device, so scroll physics and page
  transitions match.
- Accessibility simulation: text scale, bold text, high contrast, invert
  colors, disabled animations, screen-reader navigation.
- `package:device_lab/device_lab_testing.dart` reuses the same specs in
  `flutter_test` via `pumpOnDevice` and `goldenNameFor`.
