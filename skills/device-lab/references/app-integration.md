# Driving an app's own device facts from the preview

`DeviceLab.appBuilder` changes what the app reads from the widget tree: `MediaQuery` (size, padding,
orientation, the hinge in `displayFeatures`) and `Theme.platform`. Some apps decide layout from facts that
do not come from the tree:

- a "foldable" flag or an "open / closed" state read from a hinge sensor or a native check at startup;
- `defaultTargetPlatform` (directly, or through a helper) to pick platform styling;
- screen metrics cached by a widget mounted **above** `MaterialApp.builder`.

The preview cannot change those on its own. This page shows how to drive them from the preview, so the
app behaves as the picked device would. Everything stays behind the same compile-time constant.

## Contents

1. [Own the controller](#1-own-the-controller)
2. [Sync on every change](#2-sync-on-every-change)
3. [Provide preview state below `MaterialApp.builder`](#3-provide-preview-state-below-materialappbuilder)
4. [Pitfalls](#4-pitfalls)

## 1. Own the controller

Create the `DeviceLabController` yourself and hand it to `DeviceLab`, so a listener can react to every
change of device, orientation and posture. A top-level `final` is lazy: it is never created unless the
preview is on.

```dart
/// Opt-in device preview: add `--dart-define=DEVICE_LAB=true` to a debug run. Const, so everything gated
/// on it is dead code in any build without it, and it can never ship in release.
const bool _kDeviceLab = bool.fromEnvironment('DEVICE_LAB') && !kReleaseMode;

final DeviceLabController _deviceLab = _createDeviceLab();

DeviceLabController _createDeviceLab() {
  final DeviceLabController lab = DeviceLabController(storage: const SessionDeviceLabStorage())..addListener(_syncPreview);
  // First sync after the frame that creates it: this initializer runs during build, where reassembling isn't allowed.
  WidgetsBinding.instance.addPostFrameCallback((_) => _syncPreview());
  return lab;
}

void main() => runApp(_kDeviceLab ? DeviceLab(controller: _deviceLab, builder: (_) => const MyApp()) : const MyApp());
```

## 2. Sync on every change

```dart
bool? _lastFoldable;
TargetPlatform? _lastPlatform;

/// The picked device's fold flag while previewing; null means "use the app's own detection".
bool? previewFoldable() => _kDeviceLab && _deviceLab.active ? _deviceLab.device.isFoldable : null;

void _syncPreview() {
  final bool? foldable = previewFoldable();
  // Flutter's widgets, and any code that reads defaultTargetPlatform, follow the picked device (debug runs only).
  final TargetPlatform? platform = _deviceLab.active ? _deviceLab.device.targetPlatform : null;
  debugDefaultTargetPlatformOverride = platform;

  // If the app derives "open" from a hinge angle, map the posture to one.
  final double angle = switch (_deviceLab.posture) {
    FoldPosture.folded => 0,
    FoldPosture.halfOpened => 90,
    FoldPosture.flat => 180,
  };
  previewFoldState.value = (foldable: foldable ?? false, angle: angle); // your app's fold state holder

  if (foldable == _lastFoldable && platform == _lastPlatform) return;
  _lastFoldable = foldable;
  _lastPlatform = platform;
  // Plain reads (a static flag, defaultTargetPlatform) have no rebuild dependency, so rebuild everything —
  // hot-reload semantics, state kept. Deferred: this listener fires inside the panel's tap, and reassembling
  // there locks pointer events mid-dispatch.
  Future<void>.microtask(WidgetsBinding.instance.reassembleApplication);
}
```

Wire `previewFoldable()` (and the fold state) into the place the app already asks for them: an override
hook in your detection code, a notifier the layout listens to, a provider. Keep the app's real detection as
the fallback when it returns `null` — that is the preview hidden, or no preview at all.

`debugDefaultTargetPlatformOverride` is honoured by Flutter in **debug** runs only. `dart:io`
`Platform.isIOS` / `Platform.isAndroid` never follow it.

## 3. Provide preview state below `MaterialApp.builder`

`MaterialApp.builder` runs below the navigator, so every route, sheet and dialog sits under what it
returns. Compose there:

```dart
Widget previewBuilder(BuildContext context, Widget? child) {
  if (!_kDeviceLab || child == null) return child ?? const SizedBox.shrink();
  final Widget content = DeviceLab.isPreviewing(context)
      ? PreviewFoldScope(state: previewFoldState, child: child) // whatever your app reads fold state from
      : child;
  return DeviceLab.appBuilder(context, content);
}

// In MyApp.build:
MaterialApp(builder: previewBuilder, /* ... */);
```

If the app builds its `MaterialApp` inside a wrapper widget, pass `previewBuilder` through the wrapper's
`builder` hook. If the wrapper already takes a builder, compose:
`builder: (context, child) => previewBuilder(context, existing(context, child))`.

**Metrics cached above the builder.** A widget mounted above `MaterialApp.builder` that caches screen
size for scaling helpers sees the real window. Mount a second instance of it inside `previewBuilder`, below
`DeviceLab.appBuilder`, so the helpers scale for the simulated screen.

## 4. Pitfalls

- **Overriding root-level decisions.** Keep anything that decides the shape of the root widget tree (which
  providers exist at the root, for example) on the real detection. Changing it at runtime remounts the app.
- **Providers that exist only on real hardware.** If some state is provided only when the real device is a
  foldable, previewing a foldable on another host finds nothing: provide a preview instance in
  `previewBuilder` (section 3).
- **Reading under a pinned `MediaQuery`.** A widget that renders its child at a fixed phone size makes the
  child read as a phone. Read device facts on the outer context and pass them in.
- **Synchronous reassemble.** Calling `reassembleApplication()` directly from the listener throws
  `'!locked': is not true` in `GestureBinding.handlePointerEvent`; defer it.
