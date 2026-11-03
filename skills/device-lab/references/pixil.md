# device_lab in a `flutter_pixil_framework` app (copy-ready)

A Pixil app builds its `MaterialApp` inside `PixilApp`, detects foldables from the hinge sensor
(`PixilFrameWork().isFoldable`, `FoldablePhoneCubit`) and decides platform styling through
`CurrentPlatform` (`defaultTargetPlatform`). The wiring below makes all three follow the previewed device.
It needs **flutter_pixil_framework 1.5.0 or newer** (`PixilApp.foldableOverride`,
`FoldablePhoneCubit(listenToHingeSensor:)`); on an older framework, sizes and platform still follow the
preview but every fold check reads the real hinge sensor.

## Contents

1. [Dependency](#1-dependency)
2. [The part file](#2-the-part-file)
3. [Hook it into the app file](#3-hook-it-into-the-app-file)
4. [Run configuration](#4-run-configuration)
5. [What each piece is for](#5-what-each-piece-is-for)

## 1. Dependency

A regular dependency (`lib/` imports it). Pin a commit of this fork so every machine resolves the same
code, even when `pubspec.lock` is not committed:

```yaml
dependencies:
  # Opt-in device preview (--dart-define=DEVICE_LAB=true).
  device_lab:
    git:
      url: https://github.com/AnasQasem/device_lab.git
      ref: <commit of the fork's master>
```

## 2. The part file

Create `lib/app/app_device_lab.dart` next to the file whose widget returns `PixilApp` (adjust the
`part of` and the class name in the header). Nothing else in the app changes.

```dart
// Opt-in device preview wiring (package:device_lab) for [MyApp].
// Everything here is behind [_kDeviceLab]: dead code without `--dart-define=DEVICE_LAB=true`, and in every release build.
part of 'app.dart';

/// Opt-in device preview (package:device_lab): add `--dart-define=DEVICE_LAB=true`
/// to a debug or profile run. Const, so everything gated on it is dead code in any
/// build without it — and it can never ship in release.
const bool _kDeviceLab = bool.fromEnvironment('DEVICE_LAB') && !kReleaseMode;

/// Owned here, not by [DeviceLab], so the previewed device can drive the framework's fold flag
/// ([PixilApp.foldableOverride]), [_previewFoldCubit] and the platform. Top-level finals are lazy: neither exists unless the preview is on.
final DeviceLabController _deviceLab = _createDeviceLab();

DeviceLabController _createDeviceLab() {
  final DeviceLabController lab = DeviceLabController(storage: const SessionDeviceLabStorage())..addListener(_syncPreview);
  // First sync after the frame that creates it: this initializer runs during build, where reassembling isn't allowed.
  WidgetsBinding.instance.addPostFrameCallback((_) => _syncPreview());
  return lab;
}

/// Stands in for the hinge-sensor cubit while previewing, driven from the panel's posture.
final FoldablePhoneCubit _previewFoldCubit = FoldablePhoneCubit(listenToHingeSensor: false);

bool? _lastPreviewFoldable;
TargetPlatform? _lastPreviewPlatform;

/// The framework's fold flag while previewing; null hands back to the device's own hinge-sensor detection.
bool? _previewFoldable() => _kDeviceLab && _deviceLab.active ? _deviceLab.device.isFoldable : null;

void _syncPreview() {
  final bool? foldable = _previewFoldable();
  // `defaultTargetPlatform` — and with it Flutter's widgets and every framework `CurrentPlatform` check, e.g. how sheets open —
  // follows the previewed device. Debug builds only (Flutter ignores the override otherwise); the app's own dart:io
  // `Platform.isX` branches still read the host.
  final TargetPlatform? platform = _deviceLab.active ? _deviceLab.device.targetPlatform : null;
  debugDefaultTargetPlatformOverride = platform;
  final double angle = switch (_deviceLab.posture) {
    .folded => 0,
    .halfOpened => 90,
    .flat => 180,
  };
  // Same threshold as the framework's hinge listener (angle > 30 → open).
  _previewFoldCubit
    ..setHingeAngle(angle)
    ..setIsFoldOpen((foldable ?? false) && angle > 30);
  if (foldable == _lastPreviewFoldable && platform == _lastPreviewPlatform) return;
  _lastPreviewFoldable = foldable;
  _lastPreviewPlatform = platform;
  // Neither is a rebuild dependency (plain reads): rebuild everything (hot-reload semantics, state kept). Deferred to a
  // microtask: this listener fires inside the panel's tap, and reassembling there locks pointer events mid-dispatch
  // ("'!locked': is not true" in GestureBinding.handlePointerEvent).
  Future<void>.microtask(WidgetsBinding.instance.reassembleApplication);
}

/// device_lab's simulated MediaQuery, plus [_previewFoldCubit] while previewing. It sits below the navigator, so every
/// route, sheet and framework fold widget finds the preview cubit (shadowing the real one on a fold host). A pass-through otherwise.
/// The second [ResponsiveBootstrap] re-caches the `16.w` / `14.sp` metrics from the simulated MediaQuery: PixilApp's own
/// sits above this builder and sees the real window.
Widget _previewBuilder(BuildContext context, Widget? child) {
  if (!_kDeviceLab || child == null) return child ?? const SizedBox.shrink();
  final Widget content = DeviceLab.isPreviewing(context)
      ? BlocProvider<FoldablePhoneCubit>.value(
          value: _previewFoldCubit,
          child: ResponsiveBootstrap(child: child),
        )
      : child;
  return DeviceLab.appBuilder(context, content);
}
```

## 3. Hook it into the app file

Parts cannot import, so the app file gets the imports it lacks, the `part` directive and three changes in
`build`:

```dart
import 'package:device_lab/device_lab.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// ...the file's existing imports (material_ui or flutter/material, flutter_pixil_framework, ...)

part 'app_device_lab.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Widget app = PixilApp(
      // ...every existing PixilApp argument stays...
      builder: _previewBuilder,
      foldableOverride: _previewFoldable,
    );
    return _kDeviceLab ? DeviceLab(controller: _deviceLab, builder: (_) => app) : app;
  }
}
```

- If the app already passes `PixilApp(builder: x)`, compose it inside the preview:
  `builder: (context, child) => _previewBuilder(context, x(context, child))`.
- Follow the app's lints: drop the dot-shorthand (`.folded`) on SDKs without it; passing the functions
  themselves avoids `_kDeviceLab ? … : null` arguments, which `avoid_redundant_argument_values` flags
  once the constant folds to `null`.
- Leave `DeviceLab.localeOf` out: `PixilApp` drives `MaterialApp.locale` from `AppState`.

## 4. Run configuration

The app's usual debug command plus the define; keep its flavor, `--dart-define-from-file` and engine flags.

```jsonc
{
  "name": "develop-debug (device lab)",
  "request": "launch",
  "type": "dart",
  "flutterMode": "debug",
  "program": "lib/main/main_development.dart",
  "args": ["--flavor", "development", "--dart-define=DEVICE_LAB=true"]
}
```

Run it in **debug**: Flutter honours `debugDefaultTargetPlatformOverride` only in debug. A dependency or
wiring change needs a full restart, not a hot reload.

## 5. What each piece is for

| Piece | Why |
| --- | --- |
| `_kDeviceLab` | Compile-time opt-in. `!kReleaseMode` keeps it out of release even with the define; every branch behind it is tree-shaken. Never use `DeviceLab(enabled:)`'s `!kReleaseMode` default: it wraps every debug **and profile** run. |
| `_deviceLab` | The app owns the controller so its listener can drive the framework. |
| `_previewFoldCubit` | The framework provides the real hinge cubit only on a detected foldable; this one is driven by the panel's posture. |
| `_previewFoldable` → `PixilApp.foldableOverride` | Every `PixilFrameWork().isFoldable` read, fold layout, fold route and sheet follows the picked device. The root cubit provider, `DualScreenScope` and `forcePortrait` stay on the hinge sensor by design. |
| `debugDefaultTargetPlatformOverride` | Every framework platform check is `CurrentPlatform` → `defaultTargetPlatform`, so sheets, transitions and scaffolds follow. The app's `dart:io` `Platform.isX` branches do not. |
| `reassembleApplication` (deferred) | The fold flag and platform are plain reads; a flip must rebuild everything, outside the panel's tap. |
| `_previewBuilder` → `PixilApp.builder` | Below the navigator, so every route and sheet gets the simulated `MediaQuery`, the preview cubit, and a `ResponsiveBootstrap` that scales `16.w` / `14.sp` for the simulated screen. |
