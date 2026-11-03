---
name: device-lab
description: Previews and tests a Flutter app on any phone, tablet or foldable with the device_lab package, and sweeps every catalog device of a class through its debug VM service extensions. Use when asked to make sure an app is responsive on a device class (all tablets, all phones, foldables, iPads, Android tablets), to test on different devices or screen sizes, to add device_lab, a device preview or a device frame, or to preview a foldable or iPad layout without the hardware. Covers plain Flutter apps and apps on flutter_pixil_framework, where fold detection and platform styling need extra wiring. Also use when a preview shows the wrong thing - a squashed page, a fold layout or side drawer that never appears, sheets in the wrong platform style, a '!locked' gesture assertion, or ProviderNotFoundException for FoldablePhoneCubit.
---

# device_lab: preview and sweep an app across devices

`device_lab` lays the app out at a simulated device's size inside a device frame and swaps the
`MediaQuery` it sees. Its catalog has about 150 devices (78 phones, 17 foldables, 15 tablets, desktops,
watches, TV). When enabled it also registers debug VM service extensions, `ext.deviceLab.*`, which let an
agent switch devices and collect layout errors and screenshots across a whole category.

## Rules

1. **Opt in with a constant.** `const bool _kDeviceLab = bool.fromEnvironment('DEVICE_LAB') && !kReleaseMode;`
   and branch on it (`_kDeviceLab ? DeviceLab(...) : app`). `DeviceLab(enabled:)` defaults to
   `!kReleaseMode`, which wraps every debug and profile run in a frame and keeps the package reachable in
   release.
2. **Use this fork.** Depend on `https://github.com/AnasQasem/device_lab.git` pinned to a commit of its
   `master`. pub.dev's 0.3.2 lays any device larger than the free stage area out squashed (while its
   `MediaQuery` reports the full size) and puts its own `MaterialApp` above the app; the fork has the
   fixes, the Devices/Display panel and the sweep extensions.
3. **`MaterialApp.builder` gets `DeviceLab.appBuilder`.** It installs the simulated `MediaQuery` and
   `Theme.platform` below the app's navigator, so routes, sheets and dialogs see the device. Widgets
   above that builder see the real window.
4. **Know what cannot follow.** `dart:io` `Platform.isIOS`/`isAndroid`, `View.of(context)`,
   `PlatformDispatcher.instance.views`, `MediaQueryData.fromView`, platform channels, plugins and sensors
   keep the real device. Say so whenever a result depends on one of them.
5. **flutter_pixil_framework apps need the Pixil wiring** in [references/pixil.md](references/pixil.md)
   (framework 1.5.0 or newer): `PixilApp.builder`, `PixilApp.foldableOverride`, a sensor-less
   `FoldablePhoneCubit` driven by the posture, `debugDefaultTargetPlatformOverride` and a second
   `ResponsiveBootstrap`. Without it, sizes follow the preview but folds and platform do not.
6. **A sweep means every device of the class**, not a sample, in both orientations and, for foldables,
   folded and flat.
7. **Debug runs only** for platform simulation: Flutter ignores `debugDefaultTargetPlatformOverride` in
   profile and release.

## Workflow A — add device_lab to an app

1. Add the dependency (Rule 2) as a regular `dependencies:` entry — `lib/` imports it.
2. **Plain Flutter app:** wrap the root and set the builder.

   ```dart
   const bool _kDeviceLab = bool.fromEnvironment('DEVICE_LAB') && !kReleaseMode;

   void main() => runApp(_kDeviceLab ? DeviceLab(builder: (_) => const MyApp()) : const MyApp());

   // In MyApp.build:
   MaterialApp(
     builder: DeviceLab.appBuilder, // pass-through when no DeviceLab is above
     locale: DeviceLab.localeOf(context),
     // ...
   );
   ```

   **flutter_pixil_framework app:** follow [references/pixil.md](references/pixil.md) instead (a part
   file next to the widget that returns `PixilApp`, plus three lines in it).
3. Add a run configuration: the app's usual debug command plus `--dart-define=DEVICE_LAB=true`.
4. Validate: analyze clean; a run **without** the define is unchanged; with it, the frame and panel
   appear. Tell the user to stop and relaunch — a dependency or root change is not hot-reloadable.

## Workflow B — "make sure the app is responsive on <device class>"

1. **Map the request to selectors** ([references/sweep.md](references/sweep.md) → Selectors) and state
   the device count you will cover (for example 15 tablets, 78 phones).
2. **Get a preview run.** Load the Dart MCP tools. `dtd` `listDtdUris` → `connect` to the project's
   instance → `listConnectedApps`. If no app is running with `--dart-define=DEVICE_LAB=true`, launch the
   app's device-lab configuration (Workflow A first if the app has no device_lab yet) on a tablet or other
   large host.
3. **Find the main isolate**: `vm_service` `callMethod` `getVM`. If `ext.deviceLab.devices` is missing,
   the app was started before device_lab was added: hot restart.
4. **Confirm the scope**: `ext.deviceLab.devices` with the selectors.
5. **Pick the screens**: the ones the user named; otherwise the screen that is showing, and list the main
   screens not covered. Move between screens with the app's router (`vm_service` `evaluate` in the
   library that owns it) or ask the user to open the next one.
6. **Sweep each screen**: `ext.deviceLab.sweep` with the selectors and `screenshots=failures`. Batch long
   classes (`limit=20`, `offset=0, 20, …`); lower `limit` if a call times out. Parse saved responses with a
   script (references/sweep.md → Reading large responses) and look at the failing screenshots.
7. **Report** per screen: cases run, cases failed, and each distinct error with its widget location and
   the devices, orientations and postures that hit it. `[device_lab]` errors are the panel's, not the
   app's.
8. **Fix and re-check**: size from `MediaQuery` and constraints, not fixed widths; hot reload; re-run
   with `ids=` the failed devices; finish with one full sweep. Capture a few passing cases too
   (`ext.deviceLab.capture`): a sweep only catches layouts that raise errors.

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| Large device (iPad portrait) renders small or squashed; `MediaQuery` reports the full size | pub.dev 0.3.2 | Rule 2 |
| Dialog or root sheet outside the device frame | pub.dev 0.3.2 | Rule 2 |
| `ext.deviceLab.*` not found | Not a debug/profile run, no `DeviceLab` mounted, or started before device_lab was added | Run with the define in debug; hot restart |
| Fold picked, phone or tablet layout shows; fold route opens full screen | Pixil app without `foldableOverride`, framework < 1.5.0, or code reading the bootstrap detection | references/pixil.md; read `PixilFrameWork().isFoldable` |
| `ProviderNotFoundException` for `FoldablePhoneCubit` | Preview cubit not provided below the navigator | references/pixil.md (`_previewBuilder`) |
| Android device picked, sheets still iOS-style | No platform override, or a profile run | references/pixil.md; run in debug |
| `'!locked': is not true` after a device change | `reassembleApplication` called synchronously inside the panel tap | Defer with `Future<void>.microtask` |
| `16.w` sizes match the host | Pixil's `ResponsiveBootstrap` sits above `PixilApp.builder` | The second `ResponsiveBootstrap` in references/pixil.md |
| A value is wrong only inside a phone-sized preview widget | Read under a pinned `MediaQuery` | Read it on the outer context and pass it in |
| Pick lost after hot restart | `SessionDeviceLabStorage` is in memory | Expected; implement `DeviceLabStorage` to persist |

## Go deeper

- [references/sweep.md](references/sweep.md) — every extension, parameter and response field.
- [references/pixil.md](references/pixil.md) — the complete flutter_pixil_framework wiring.
- `doc/guide.md` in this repository — the full guide for people, including how to write code that
  previews correctly.
