## 0.3.3

- Fixed the app being laid out in whatever space was left in the window instead
  of at the simulated device size. `MediaQuery` reported the simulated size
  while layout used the smaller area, so any device larger than the stage got
  overflows and broken layouts. It showed up on phone-sized windows, where
  nearly every device is larger than the stage. The app is now always laid out
  at the exact simulated size and then scaled, and touches reach the whole
  scaled device.
- Fixed the lab's own `MaterialApp` sitting above your app. That made "the
  root navigator" the lab's, so `Navigator.of(context, rootNavigator: true)`,
  `showDialog`, date pickers and `Get.bottomSheet(useRootNavigator: true)` all
  landed on the lab's navigator. Dismissing through the root navigator removed
  your whole app, and anything opened that way appeared outside your provider
  scope, theme and the device frame, which surfaced as errors such as "No
  ProviderScope found". Nothing the lab owns is an ancestor of your app any
  more: the tools panel and the compact bar run in their own isolated
  `MaterialApp`s beside it, so dialogs, sheets and pickers open inside the
  device screen.
- No API changes.

## 0.3.2

- Corrected several flip cover screens, which were wrong. The cover sizes and
  therefore the dp your layouts see change:
  - Galaxy Z Flip 7: 948x1048 px (was 1101x1047). 316 x 349 dp, was 367 x 349.
  - Galaxy Z Flip 4: a wide 512x260 strip (was a 519x519 square).
  - Motorola Razr 50 Ultra: 1080x1272 px (was 1239x1119).
  - Motorola Razr (2023), the razr 40: 368x194 px (was 582x582).
  Layout tests pinned to the old cover sizes will need updating.
- Added the Galaxy Z Flip8.
- Flip phones are redrawn like the iPhone Duo: a body for each posture sized
  from the vendor's millimetres, a metal rim, side keys, a hinge strip along
  the bottom of the closed body, and lenses either set in the body beside a
  small cover screen or cut into a full-face one. Rotating turns the whole body.
- Open bodies are derived from the vendors' body sizes and reproduce their
  published screen-to-body ratios to within about a point.
- Added `FrameLens` and `DeviceFrame.lenses`, carried through the JSON codec.
- The custom resolution fields now follow the selected device and posture
  instead of keeping the value they started with, and leave a field alone while
  you are typing in it.
- The example app splits along the fold it is given, stacking for a flip and
  side by side for a book fold, and takes its starting device from
  `--dart-define=DEVICE=`.

## 0.3.1

- Rotating now turns the whole device. The camera cutout, side buttons, hinge
  spine and corner rounding move with the body, and cutouts are reported
  through `MediaQuery.displayFeatures` in every orientation instead of
  vanishing once the device was turned.
- Side buttons are now drawn. They were declared on the frame but never
  painted. Frames also gain a metal rim.
- The iPhone Duo is redrawn from Apple's published dimensions: titanium rim,
  spine, a square spine side against a round outer side, a round camera on the
  cover, and buttons where Apple shows them. The open display no longer draws a
  camera cutout. Pixel densities (430 and 460 ppi) are now shown.
- The bezel rotation no longer keys off landscape, which was wrong for
  landscape-natural devices such as the Duo.
- Zoom control in the compact bar and the panel: step down or up, drag a
  slider, or fit to the space available. It reports the scale the stage is
  drawing at and is remembered with the rest of the selection.
- Added `DeviceScreen.corners`, `frame` and `ppi`, `DeviceFrame.corners`,
  `rimWidth` and `spine`, `FrameSpine`, `DeviceSpec.frameFor`, and
  `DeviceLabController.frame`, `zoom`, `setZoom`, `zoomIn`, `zoomOut` and
  `stageMetrics`. All are additive.
- The JSON codec now round-trips frames, buttons, spine, corners, ppi and
  cutout alignment. Cutout alignment and the obstructing flag were previously
  lost.

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
