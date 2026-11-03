# Device preview guide

This guide adds an opt-in **device preview** to a Flutter app with this fork of
[`device_lab`](https://github.com/mrHeinrichh/device_lab). One debug run on a tablet or a large emulator
can then be shown as any phone, tablet or foldable from the catalog: its screen size, safe areas,
orientation, fold posture and hinge, and its platform styling. It also covers sweeping a whole device
category automatically (every tablet, every phone). The preview is compiled out of every build that does
not ask for it, and out of every release build.

## Contents

1. [What the preview can and cannot simulate](#what-the-preview-can-and-cannot-simulate)
2. [Add it to an app](#add-it-to-an-app)
3. [Run it and use the panel](#run-it-and-use-the-panel)
4. [Sweep a whole device category](#sweep-a-whole-device-category)
5. [Writing code that previews correctly](#writing-code-that-previews-correctly)
6. [Troubleshooting](#troubleshooting)
7. [Release safety](#release-safety)

## What the preview can and cannot simulate

`DeviceLab.appBuilder` swaps the `MediaQuery` and `Theme.platform` the app sees, and the stage lays the app
out at the simulated size. Anything that asks the **real** device or window keeps the real answer, unless
the app drives it from the preview itself (see
[Driving an app's own device facts](../skills/device-lab/references/app-integration.md)).

| Signal | Follows the picked device? | Notes |
| --- | --- | --- |
| `MediaQuery` size, padding, orientation, `displayFeatures` (hinge), text scale, brightness | Yes | Below `MaterialApp.builder` — the routes, sheets and dialogs. |
| Layout constraints (`LayoutBuilder`, `Expanded`) | Yes | pub.dev's 0.3.2 laid large devices out squashed; this fork does not. |
| `Theme.platform` | Yes | Set by `DeviceLab.appBuilder`. |
| `defaultTargetPlatform` | Only if the app sets the override | `debugDefaultTargetPlatformOverride`, honoured by Flutter in debug runs only. |
| A fold flag or open state the app reads from a sensor or native check | Only if the app drives it from the controller | The controller exposes the picked device's `isFoldable` and `posture`. |
| Screen metrics cached by a widget above `MaterialApp.builder` | Only if re-cached below the builder | Mount a second instance below `DeviceLab.appBuilder`. |
| `dart:io` `Platform.isIOS` / `Platform.isAndroid` | **No** | Always the real device. |
| `View.of(context)`, `PlatformDispatcher.instance.views`, `MediaQueryData.fromView` | **No** | The real window. |
| Platform channels, plugins, sensors, `SystemChrome`, notifications | **No** | Native code runs on the real device. |
| Widgets above `MaterialApp.builder` | **No** | They see the real window. |
| Values captured once (route config, singletons, `static final`s, `initState`) | Whatever was true when captured | Re-open the screen or hot restart after switching. |

## Add it to an app

### Dependency

`lib/` imports the package, so it is a regular dependency. Pin a commit of this fork's `master` so every
machine resolves the same code, even when `pubspec.lock` is not committed:

```yaml
dependencies:
  # Opt-in device preview (--dart-define=DEVICE_LAB=true).
  device_lab:
    git:
      url: https://github.com/AnasQasem/device_lab.git
      ref: <commit of the fork's master>
```

`device_lab` depends on `flutter_test`. That only widens the dependency graph: nothing from it is compiled
into the app unless you import `package:device_lab/device_lab_testing.dart`.

### Wiring

```dart
/// Opt-in device preview: add `--dart-define=DEVICE_LAB=true` to a debug run. Const, so the package is
/// tree-shaken out of every build without it, and it can never ship in release.
const bool _kDeviceLab = bool.fromEnvironment('DEVICE_LAB') && !kReleaseMode;

void main() => runApp(_kDeviceLab ? DeviceLab(builder: (_) => const MyApp()) : const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        builder: DeviceLab.appBuilder, // a pass-through when no DeviceLab is above
        locale: DeviceLab.localeOf(context),
        home: const HomePage(),
      );
}
```

Branch on the constant rather than passing `DeviceLab(enabled:)`: its default, `!kReleaseMode`, wraps
every debug **and profile** run in a frame and keeps the package in release builds.

If the app builds its `MaterialApp` inside a wrapper widget, pass `DeviceLab.appBuilder` through the
wrapper's `builder` hook, composed with any builder it already has. Leave `DeviceLab.localeOf` out when the
app drives its locale from its own state.

### Apps that detect device facts themselves

If the app decides layout from a foldable flag read from a hinge sensor, styles by
`defaultTargetPlatform`, or caches screen metrics above `MaterialApp.builder`, those facts keep the real
device until the app drives them from the preview. Own the `DeviceLabController`, sync on every change, and
provide preview state below `MaterialApp.builder`:
[Driving an app's own device facts](../skills/device-lab/references/app-integration.md).

## Run it and use the panel

Run the app's usual debug command plus `--dart-define=DEVICE_LAB=true`, on a host with room (an iPad, a
tablet emulator, a large phone; the frame is scaled to fit). Add a launch configuration for it. A
dependency or root wiring change needs a full restart, not a hot reload.

The panel (a sidebar on wide windows, below the device on narrow ones):

- **Pinned at the top**: search, the current device, Portrait / Landscape, the fold posture for a foldable
  (cover screen, half open, open; a new device starts open) and **Show original screen**
  (⌘/Ctrl+Shift+D toggles it back).
- **Devices tab**: the catalog, with category chips (Phones, Foldables, Tablets, Desktop & breakpoints,
  Watches, TV) and sub-category chips (iPhone / Android, iPad / Android tablet, Book / Flip, …). Picking
  a device stays on this tab and keeps the chips.
- **Display tab**: zoom, custom resolution, dark mode, text scale and the accessibility toggles.
- The pick survives hot reload; a hot restart or relaunch goes back to the default device, because
  `SessionDeviceLabStorage` is in memory. Implement `DeviceLabStorage` over your own storage to keep it.

## Sweep a whole device category

To show that a screen works on **every** tablet or **every** phone, `DeviceLab` registers four debug VM
service extensions as soon as it is enabled — no app wiring. A coding agent calls them through the Dart
MCP server (`vm_service` → `callMethod`); a person can call them from DevTools.

| Extension | Does |
| --- | --- |
| `ext.deviceLab.devices` | Lists the catalog devices matching `category`, `platform` or `ids` |
| `ext.deviceLab.sweep` | Shows each matching device in both orientations (and, for foldables, folded and flat), records every Flutter error raised — overflows included, with the widget's source location — and optionally screenshots; restores the previous device afterwards |
| `ext.deviceLab.show` | Switches to one device, orientation and posture and stays there |
| `ext.deviceLab.capture` | Screenshots the simulated screen only, without frame or panel |

Selectors: tablets → `category=tablet` (15 devices), iPads → `tablet` + `platform=iOS`, phones → `phone`
(78), iPhones → `phone` + `iOS`, foldables → `foldable` (17). Batch phones with `limit=20` and `offset`
(78 × 2 orientations = 156 cases). Every parameter and response field is in
[the sweep reference](../skills/device-lab/references/sweep.md).

A sweep checks **the screen that is showing**: open each screen that matters and sweep it. It does not
see a layout that is wrong without raising an error (look at the screenshots), code reached only by
interaction, or what the preview cannot simulate (the table above). Errors from device_lab's own panel are
prefixed `[device_lab]` and are not counted as failures.

The agent skill in [`skills/device-lab`](../skills/device-lab/SKILL.md) turns "make sure the app is
responsive on tablets" into exactly this: every tablet, every screen named, a report of each distinct
error with the devices that hit it, then fix and re-sweep.

## Writing code that previews correctly

The preview only changes what code reads through the widget tree. These rules keep a screen honest under
the preview, and on real devices too.

1. **Size from the tree.** Use `MediaQuery.sizeOf(context)` or a `LayoutBuilder`, not `View.of(context)`
   or `PlatformDispatcher.instance.views`. Read the `View` only when you need the physical window on
   purpose, and accept that the preview cannot simulate it.
2. **Read device facts on the outer context.** A widget that pins a phone-sized `MediaQuery` (to render
   something at phone size) makes everything inside it read as a phone. Capture fold state or orientation
   before the pin and pass the value in.
3. **Platform: UI versus native.** For a purely visual choice (padding, title alignment, sheet style),
   use `Theme.of(context).platform`, which follows the preview. Keep `dart:io` `Platform` for native
   capabilities — channels, plugins, file formats — which must follow the real device.
4. **Don't cache device facts** in `initState` or statics if the screen should react to a device switch;
   read them in `build`.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| A large device renders small, squashed or overflowing, though `MediaQuery` reports its full size | pub.dev 0.3.2 lays devices larger than the stage out at the stage size | Use this fork |
| A dialog or root sheet opens outside the device frame | pub.dev 0.3.2's own `MaterialApp` sits above the app | Use this fork |
| `ext.deviceLab.*` not found | Release build, no `DeviceLab` mounted, or the app was started before device_lab was added | Debug run with the define; hot restart |
| A foldable is picked but the fold layout or side panel never appears | The app reads its fold flag from a sensor or native check | [Driving an app's own device facts](../skills/device-lab/references/app-integration.md) |
| Previewing an Android device, platform styling stays the host's | The app styles by `defaultTargetPlatform`, or a profile run | Set the platform override (same page); run in debug |
| `'!locked': is not true` in `GestureBinding.handlePointerEvent` after a device change | `reassembleApplication()` called synchronously inside the panel's tap | Defer it with `Future<void>.microtask` |
| Scaled sizes match the host, not the picked device | Metrics cached by a widget above `MaterialApp.builder` | Mount a second instance below `DeviceLab.appBuilder` |
| A value is wrong only inside a phone-sized preview widget | Read under a pinned `MediaQuery` | Read it on the outer context (rule 2) |
| A tablet side panel opens full width in portrait | Usually the app's own rule | Rotate, or change the app's rule |
| Nothing changes with the define | The define is missing, or it is a release build | Check the run command |

## Release safety

With the constant false — no define, or any release build — the root returns the app unchanged and every
preview branch is dead code, so the package is tree-shaken out. The service extensions are registered by
`DeviceLab` itself and `dart:developer` extensions are no-ops in release anyway. To confirm, build with
`--analyze-size` and search the size report for `device_lab`.
