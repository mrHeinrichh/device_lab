## 0.3.0

- The tools panel is back below the stage in narrow layouts. It stays a left
  sidebar when there is room for one, and switching between the two no longer
  re-mounts the previewed app.
- Collapsing the panel now leaves a compact bar showing just the selected
  device and its resolution, with rotate, show-original and expand buttons,
  instead of hiding everything behind floating buttons.
- The stage now scales the device up as well as down to fill the space it has,
  between 0.2x and 1.6x, so small phones are no longer lost on a large canvas.

## 0.2.1

- Fixed the app being rebuilt from a stale `builder` closure, so hot reload
  now reaches the previewed app. Previously the closure was captured once and
  never refreshed, which left the app running old code and could throw from
  providers and other scopes the reload had replaced.
- Fixed the whole app subtree being torn down and re-mounted whenever the
  preview was shown, hidden or resized. The app now keeps an identical
  ancestor chain in both modes, so it is updated in place. Inherited widgets
  such as `ProviderScope` declared inside `builder` stay reachable throughout.
- The host no longer resizes for the software keyboard, leaving the previewed
  app's own inset handling untouched.
- In narrow layouts the tools panel now sits above the stage rather than
  below it, so switching between layouts does not re-mount the app either.

## 0.2.0

- `enabled` now defaults to `!kReleaseMode` instead of `true`, so the preview
  cannot ship to production by accident and there is nothing to remember to
  turn off.
- The selected device, orientation and fold posture are now remembered.
  `initialDeviceId` became a seed rather than an override, so hiding the
  preview or rebuilding the widget no longer snaps back to it.
- Added `DeviceLabStorage`, with `SessionDeviceLabStorage` as the default.
  Implement it over `SharedPreferences` or similar to persist across
  restarts, or pass `storage: null` to opt out.
- Exposed `DeviceLabController.defaultDeviceId` and the storage keys.

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
