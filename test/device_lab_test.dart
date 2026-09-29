import 'package:device_lab/device_lab.dart';
import 'package:device_lab/device_lab_testing.dart';
import 'package:device_lab/src/model/quarter_turn.dart';
import 'package:device_lab/src/preview/device_body.dart';
import 'package:device_lab/src/preview/device_stage.dart';
import 'package:device_lab/src/preview/tools_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalog', () {
    test('device ids are unique', () {
      final ids = DeviceCatalog.all.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every device has at least one screen with a positive size', () {
      for (final d in DeviceCatalog.all) {
        expect(d.screens, isNotEmpty, reason: d.id);
        for (final s in d.screens) {
          expect(s.logicalSize.width, greaterThan(0), reason: d.id);
          expect(s.logicalSize.height, greaterThan(0), reason: d.id);
          expect(s.pixelRatio, greaterThan(0), reason: d.id);
        }
      }
    });

    test('foldables expose a main and a cover screen', () {
      final foldables = DeviceCatalog.query(category: DeviceCategory.foldable);
      expect(foldables, isNotEmpty);
      for (final d in foldables) {
        expect(d.screens.length, 2, reason: d.id);
        expect(d.screenFor(FoldPosture.folded).label, 'Cover', reason: d.id);
        expect(d.screenFor(FoldPosture.flat).hinge, isNotNull, reason: d.id);
      }
    });

    test('iPhone Duo matches Apple published specs', () {
      final duo = DeviceCatalog.byId('apple.iphone-duo')!;
      expect(duo.category, DeviceCategory.foldable);

      final inner = duo.screens.first;
      final cover = duo.screens.last;
      expect(inner.resolution, const Size(1878, 2670));
      expect(cover.resolution, const Size(1398, 2034));
      expect(inner.naturalOrientation, Orientation.landscape);
      expect(inner.sizeFor(Orientation.landscape), const Size(890, 626));
    });

    test('a book fold hinge rotates with the device', () {
      final inner = DeviceCatalog.byId('apple.iphone-duo')!.screens.first;
      expect(inner.hingeAxisFor(Orientation.landscape), Axis.vertical);
      expect(inner.hingeAxisFor(Orientation.portrait), Axis.horizontal);

      final fold = DeviceCatalog.byId('samsung.galaxy-z-fold-7')!.screens.first;
      expect(fold.hingeAxisFor(Orientation.portrait), Axis.vertical);
      expect(fold.hingeAxisFor(Orientation.landscape), Axis.horizontal);
    });

    test('safe area follows the natural orientation', () {
      final inner = DeviceCatalog.byId('apple.iphone-duo')!.screens.first;
      expect(inner.paddingFor(Orientation.landscape).top, 62);
      expect(inner.paddingFor(Orientation.portrait).top, 0);
    });

    test('flip phones fold on the horizontal axis', () {
      final flips = DeviceCatalog.all.where((d) =>
          d.isFoldable && d.screens.first.hinge?.axis == Axis.horizontal);
      expect(flips, isNotEmpty);
      for (final d in flips) {
        final cover = d.screenFor(FoldPosture.folded);
        expect(cover.label, 'Cover', reason: d.id);
        expect(
          cover.logicalSize.height,
          lessThan(d.screens.first.logicalSize.height),
          reason: d.id,
        );
      }
    });

    test('generic resolution presets cover phone to 4K', () {
      final ids = DeviceCatalog.all.map((d) => d.id).toSet();
      expect(ids, contains('res.phone-320x568'));
      expect(ids, contains('res.desktop-3840x2160'));
      expect(DeviceCatalog.all.length, greaterThan(120));
    });

    test('json round-trip preserves the spec', () {
      final source = DeviceCatalog.byId('samsung.galaxy-z-fold-7')!;
      final restored = DeviceSpecCodec.fromJson(DeviceSpecCodec.toJson(source));
      expect(restored.id, source.id);
      expect(restored.screens.length, source.screens.length);
      expect(
        restored.primaryScreen.logicalSize,
        source.primaryScreen.logicalSize,
      );
      expect(restored.primaryScreen.hinge?.axis, Axis.vertical);
    });

    test('json round-trip preserves natural orientation', () {
      final duo = DeviceCatalog.byId('apple.iphone-duo')!;
      final restored = DeviceSpecCodec.fromJson(DeviceSpecCodec.toJson(duo));
      expect(
        restored.screens.first.naturalOrientation,
        Orientation.landscape,
      );
      expect(restored.screens.first.resolution, const Size(1878, 2670));
    });

    test('loadJson registers a device that ships after the package', () {
      const json = '''
      {"devices":[{
        "id":"acme.future-phone","name":"Future Phone","platform":"android",
        "category":"phone","screens":[{
          "label":"Main","logicalSize":{"w":420,"h":960},"pixelRatio":3.0,
          "safeArea":{"t":54,"b":24}
        }]}]}
      ''';
      expect(DeviceCatalog.loadJson(json), 1);
      expect(DeviceCatalog.byId('acme.future-phone')?.name, 'Future Phone');
      DeviceCatalog.remove('acme.future-phone');
    });
  });

  group('media query resolution', () {
    test('a landscape-natural device opens in landscape from the start', () {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-duo');
      expect(c.orientation, Orientation.landscape);
      expect(c.logicalSize, const Size(890, 626));
    });

    test('selecting the Duo opens it in its natural landscape pose', () {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      expect(c.orientation, Orientation.portrait);
      c.selectDeviceId('apple.iphone-duo');
      expect(c.orientation, Orientation.landscape);
      expect(c.logicalSize, const Size(890, 626));

      final open = c.resolveMediaQuery(const MediaQueryData());
      expect(open.padding.top, 62);
      final fold = open.displayFeatures
          .firstWhere((f) => f.type == DisplayFeatureType.fold);
      expect(fold.bounds.width, 0);
      expect(fold.bounds.height, 626);

      c.setPosture(FoldPosture.folded);
      expect(c.orientation, Orientation.portrait);
      expect(c.logicalSize, const Size(466, 678));
    });

    test('portrait and landscape swap size and padding', () {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      final portrait = c.resolveMediaQuery(const MediaQueryData());
      expect(portrait.size, const Size(402, 874));
      expect(portrait.padding.top, 62);

      c.setOrientation(Orientation.landscape);
      final landscape = c.resolveMediaQuery(const MediaQueryData());
      expect(landscape.size, const Size(874, 402));
      expect(landscape.padding.top, 0);
      expect(landscape.padding.left, greaterThan(0));
    });

    test('dynamic island is exposed as a cutout display feature', () {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      final data = c.resolveMediaQuery(const MediaQueryData());
      final cutouts = data.displayFeatures
          .where((f) => f.type == DisplayFeatureType.cutout);
      expect(cutouts, hasLength(1));
      expect(cutouts.single.bounds.width, 126);
    });

    test('fold posture drives screen, hinge and posture state', () {
      final c = DeviceLabController(initialDeviceId: 'samsung.galaxy-z-fold-7');

      c.setPosture(FoldPosture.flat);
      final open = c.resolveMediaQuery(const MediaQueryData());
      expect(open.size, const Size(716, 794));
      final fold = open.displayFeatures
          .firstWhere((f) => f.type == DisplayFeatureType.fold);
      expect(fold.state, DisplayFeatureState.postureFlat);

      c.setPosture(FoldPosture.halfOpened);
      expect(
        c.resolveMediaQuery(const MediaQueryData()).displayFeatures.first.state,
        DisplayFeatureState.postureHalfOpened,
      );

      c.setPosture(FoldPosture.folded);
      final cover = c.resolveMediaQuery(const MediaQueryData());
      expect(cover.size, const Size(360, 840));
      expect(
        cover.displayFeatures.where((f) => f.type == DisplayFeatureType.fold),
        isEmpty,
      );
      expect(
        cover.displayFeatures.single.type,
        DisplayFeatureType.cutout,
      );
    });

    test('freeform size overrides the device and drops display features', () {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      c.setFreeformSize(const Size(1234, 567));
      expect(c.isFreeform, isTrue);
      final data = c.resolveMediaQuery(const MediaQueryData());
      expect(data.size, const Size(1234, 567));
      expect(data.displayFeatures, isEmpty);
      expect(data.padding, EdgeInsets.zero);

      c.setFreeformSize(null);
      expect(c.logicalSize, const Size(402, 874));
    });

    test('text scale and accessibility flags reach MediaQueryData', () {
      final c = DeviceLabController()
        ..setTextScale(2.0)
        ..setBoldText(true)
        ..setDisableAnimations(true);
      final data = c.resolveMediaQuery(const MediaQueryData());
      expect(data.textScaler.scale(10), 20);
      expect(data.boldText, isTrue);
      expect(data.disableAnimations, isTrue);
    });
  });

  group('preview widget', () {
    testWidgets('app below appBuilder sees the simulated device', (t) async {
      late MediaQueryData seen;
      late TargetPlatform platform;

      await t.pumpWidget(
        DeviceLab(
          initialDeviceId: 'apple.iphone-17-pro-max',
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: Builder(
              builder: (context) {
                seen = MediaQuery.of(context);
                platform = Theme.of(context).platform;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(seen.size, const Size(440, 956));
      expect(seen.devicePixelRatio, 3);
      expect(seen.padding.top, 62);
      expect(platform, TargetPlatform.iOS);
    });

    testWidgets('switching device rebuilds the app with the new size',
        (t) async {
      final controller =
          DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      final sizes = <Size>[];

      await t.pumpWidget(
        DeviceLab(
          controller: controller,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: Builder(
              builder: (context) {
                sizes.add(MediaQuery.sizeOf(context));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      controller.selectDeviceId('google.pixel-10-pro-xl');
      await t.pumpAndSettle();

      expect(sizes.first, const Size(402, 874));
      expect(sizes.last, const Size(448, 998));
    });

    testWidgets('disabled preview passes the app through untouched', (t) async {
      await t.pumpWidget(
        DeviceLab(
          enabled: false,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const Text('app', textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('app'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });
  });

  group('preview toggle', () {
    Widget harness(DeviceLabController controller) => DeviceLab(
          controller: controller,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const _Counter(),
          ),
        );

    testWidgets('hiding the lab shows the app at the real window size',
        (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      await t.pumpWidget(harness(c));
      await t.pumpAndSettle();

      expect(find.text('Show original screen'), findsOneWidget);
      final previewSize = t
          .widget<MediaQuery>(
            find
                .ancestor(
                  of: find.byType(_Counter),
                  matching: find.byType(MediaQuery),
                )
                .first,
          )
          .data
          .size;
      expect(previewSize, const Size(402, 874));

      c.setPreviewing(false);
      await t.pumpAndSettle();

      expect(find.text('Show original screen'), findsNothing);
      final realSize = t
          .widget<MediaQuery>(
            find
                .ancestor(
                  of: find.byType(_Counter),
                  matching: find.byType(MediaQuery),
                )
                .first,
          )
          .data
          .size;
      expect(realSize, t.view.physicalSize / t.view.devicePixelRatio);
    });

    testWidgets('app state survives toggling the lab off and on', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      await t.pumpWidget(harness(c));
      await t.pumpAndSettle();

      await t.tap(find.text('tap me'));
      await t.tap(find.text('tap me'));
      await t.pumpAndSettle();
      expect(find.text('count 2'), findsOneWidget);

      c.setPreviewing(false);
      await t.pumpAndSettle();
      expect(find.text('count 2'), findsOneWidget);

      c.setPreviewing(true);
      await t.pumpAndSettle();
      expect(find.text('count 2'), findsOneWidget);
    });

    testWidgets('the restore pill brings the lab back', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      await t.pumpWidget(harness(c));
      await t.pumpAndSettle();

      c.setPreviewing(false);
      await t.pumpAndSettle();
      expect(c.active, isFalse);

      await t.tap(find.text('Device Lab'));
      await t.pumpAndSettle();
      expect(c.active, isTrue);
      expect(find.text('Show original screen'), findsOneWidget);
    });

    testWidgets('no restore pill when showRestoreButton is false', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro')
        ..setPreviewing(false);
      await t.pumpWidget(
        DeviceLab(
          controller: c,
          showRestoreButton: false,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const _Counter(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Device Lab'), findsNothing);
      expect(find.text('count 0'), findsOneWidget);
    });

    testWidgets('the restore pill honours the configured corner', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro')
        ..setPreviewing(false);
      await t.pumpWidget(
        DeviceLab(
          controller: c,
          restoreButtonAlignment: Alignment.topLeft,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const _Counter(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(c.restoreAlignment, Alignment.topLeft);

      final pill = t.getCenter(find.text('Device Lab'));
      final screen = t.getSize(find.byType(MaterialApp).first);
      expect(pill.dx, lessThan(screen.width / 2));
      expect(pill.dy, lessThan(screen.height / 2));
    });

    testWidgets('dragging the pill docks it to the nearest corner', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro')
        ..setPreviewing(false);
      await t.pumpWidget(
        DeviceLab(
          controller: c,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const _Counter(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(c.restoreAlignment, Alignment.bottomRight);

      await t.drag(find.text('Device Lab'), const Offset(-600, -400));
      await t.pumpAndSettle();
      expect(c.restoreAlignment, Alignment.topLeft);

      await t.drag(find.text('Device Lab'), const Offset(700, 0));
      await t.pumpAndSettle();
      expect(c.restoreAlignment, Alignment.topRight);
    });

    testWidgets('the docked corner survives hiding and showing', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro')
        ..setPreviewing(false);
      await t.pumpWidget(
        DeviceLab(
          controller: c,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const _Counter(),
          ),
        ),
      );
      await t.pumpAndSettle();

      await t.drag(find.text('Device Lab'), const Offset(-600, -400));
      await t.pumpAndSettle();
      expect(c.restoreAlignment, Alignment.topLeft);

      c.setPreviewing(true);
      await t.pumpAndSettle();
      c.setPreviewing(false);
      await t.pumpAndSettle();
      expect(c.restoreAlignment, Alignment.topLeft);
    });

    test('active combines the release gate and the runtime toggle', () {
      final c = DeviceLabController();
      expect(c.active, isTrue);
      c.setPreviewing(false);
      expect(c.active, isFalse);
      c.togglePreview();
      expect(c.active, isTrue);
      c.setEnabled(false);
      expect(c.active, isFalse);
      c.setEnabled(true);
      expect(c.active, isTrue);
    });
  });

  group('persistence', () {
    setUp(SessionDeviceLabStorage.clear);
    tearDown(SessionDeviceLabStorage.clear);

    test('a remembered device beats initialDeviceId', () {
      const store = SessionDeviceLabStorage();
      final first = DeviceLabController(
        initialDeviceId: 'apple.iphone-17-pro',
        storage: store,
      );
      expect(first.device.id, 'apple.iphone-17-pro');

      first.selectDeviceId('samsung.galaxy-z-fold-7');
      first.setPosture(FoldPosture.folded);

      final rebuilt = DeviceLabController(
        initialDeviceId: 'apple.iphone-17-pro',
        storage: store,
      );
      expect(rebuilt.device.id, 'samsung.galaxy-z-fold-7');
      expect(rebuilt.posture, FoldPosture.folded);
    });

    test('orientation is remembered too', () {
      const store = SessionDeviceLabStorage();
      DeviceLabController(
              initialDeviceId: 'apple.iphone-17-pro', storage: store)
          .setOrientation(Orientation.landscape);

      final rebuilt = DeviceLabController(storage: store);
      expect(rebuilt.orientation, Orientation.landscape);
    });

    test('without storage the seed device is used every time', () {
      final a = DeviceLabController(initialDeviceId: 'google.pixel-10')
        ..selectDeviceId('samsung.galaxy-z-fold-7');
      expect(a.device.id, 'samsung.galaxy-z-fold-7');

      final b = DeviceLabController(initialDeviceId: 'google.pixel-10');
      expect(b.device.id, 'google.pixel-10');
    });

    test('an unknown remembered id falls back to the default', () {
      const store = SessionDeviceLabStorage();
      store.write(DeviceLabController.storageKeyDevice, 'acme.nope');
      expect(
        DeviceLabController(storage: store).device.id,
        DeviceLabController.defaultDeviceId,
      );
    });

    testWidgets('recreating the widget keeps the selected device', (t) async {
      Widget harness(Key key) => DeviceLab(
            key: key,
            initialDeviceId: 'apple.iphone-17-pro',
            builder: (_) => MaterialApp(
              builder: DeviceLab.appBuilder,
              home: const SizedBox(),
            ),
          );

      await t.pumpWidget(harness(const ValueKey('a')));
      await t.pumpAndSettle();
      DeviceLab.of(t.element(find.byType(MaterialApp).last))
          .selectDeviceId('google.pixel-10-pro-fold');
      await t.pumpAndSettle();

      await t.pumpWidget(harness(const ValueKey('b')));
      await t.pumpAndSettle();
      expect(
        DeviceLab.of(t.element(find.byType(MaterialApp).last)).device.id,
        'google.pixel-10-pro-fold',
      );
    });
  });

  group('release gate', () {
    test('enabled defaults to off in release builds', () {
      expect(DeviceLabController().enabled, !kReleaseMode);
      expect(isDeviceLabAvailable, !kReleaseMode);
    });

    test('an explicit false still wins', () {
      expect(DeviceLabController(enabled: false).enabled, isFalse);
      expect(DeviceLabController(enabled: false).active, isFalse);
    });
  });

  group('rebuild safety', () {
    testWidgets('the builder is re-read on hot reload', (t) async {
      Widget harness(String label) => DeviceLab(
            builder: (_) => MaterialApp(
              builder: DeviceLab.appBuilder,
              home: Text(label, textDirection: TextDirection.ltr),
            ),
          );

      await t.pumpWidget(harness('A'));
      await t.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);

      await t.pumpWidget(harness('B'));
      await t.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('toggling the preview never remounts the app', (t) async {
      _MountCounter.mounts = 0;
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');

      await t.pumpWidget(
        DeviceLab(
          controller: c,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const _MountCounter(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(_MountCounter.mounts, 1);

      c.setPreviewing(false);
      await t.pumpAndSettle();
      expect(_MountCounter.mounts, 1, reason: 'remounted on hide');

      c.setPreviewing(true);
      await t.pumpAndSettle();
      expect(_MountCounter.mounts, 1, reason: 'remounted on restore');

      c.setToolsVisible(false);
      await t.pumpAndSettle();
      c.setToolsVisible(true);
      await t.pumpAndSettle();
      expect(_MountCounter.mounts, 1, reason: 'remounted on tools toggle');

      c.selectDeviceId('samsung.galaxy-z-flip-7');
      c.setTextScale(2);
      c.setShowFrame(false);
      await t.pumpAndSettle();
      expect(_MountCounter.mounts, 1, reason: 'remounted on device change');
    });

    testWidgets('an InheritedWidget inside the app stays reachable', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      await t.pumpWidget(
        DeviceLab(
          controller: c,
          builder: (_) => _Scope(
            value: 42,
            child: MaterialApp(
              builder: DeviceLab.appBuilder,
              home: Builder(
                builder: (context) => Text(
                  '${_Scope.of(context)}',
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);

      c.setPreviewing(false);
      await t.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);

      c.setPreviewing(true);
      await t.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
    });
  });

  group('collapsed details', () {
    testWidgets('collapsing keeps the device and resolution visible',
        (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      await t.pumpWidget(
        DeviceLab(
          controller: c,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const SizedBox(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Show original screen'), findsOneWidget);
      expect(find.text('Device Lab'), findsOneWidget);

      c.setToolsVisible(false);
      await t.pumpAndSettle();

      expect(find.text('iPhone 17 Pro'), findsOneWidget);
      expect(find.textContaining('402 × 874 dp'), findsOneWidget);
      expect(find.text('Show original screen'), findsNothing);
      expect(find.text('Device Lab'), findsNothing);
      expect(find.byType(TextField), findsNothing);

      await t.tap(find.byTooltip('Show options'));
      await t.pumpAndSettle();
      expect(find.text('Show original screen'), findsOneWidget);
    });

    testWidgets('the panel sits below the stage in narrow layouts', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      await t.pumpWidget(
        DeviceLab(
          controller: c,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const SizedBox(),
          ),
        ),
      );
      await t.pumpAndSettle();

      final stage = t.getRect(find.byType(DeviceStage));
      final panel = t.getRect(find.byType(ToolsPanel));
      expect(panel.top, greaterThanOrEqualTo(stage.bottom - 1));

      c.setToolsVisible(false);
      await t.pumpAndSettle();
      final bar = t.getRect(find.text('iPhone 17 Pro'));
      expect(bar.top, greaterThan(t.getRect(find.byType(DeviceStage)).top));
    });

    testWidgets('the collapsed bar follows the selected device', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro')
        ..setToolsVisible(false);
      await t.pumpWidget(
        DeviceLab(
          controller: c,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const SizedBox(),
          ),
        ),
      );
      await t.pumpAndSettle();

      c.selectDeviceId('samsung.galaxy-z-flip-7');
      await t.pumpAndSettle();
      expect(find.text('Galaxy Z Flip 7'), findsOneWidget);
      expect(find.textContaining('360 × 840 dp'), findsOneWidget);

      c.setPosture(FoldPosture.folded);
      await t.pumpAndSettle();
      expect(find.textContaining('316 × 349 dp'), findsOneWidget);
    });
  });

  group('quarter turns', () {
    test('a rect moves with the device when it is turned', () {
      expect(
        rotateRectCcw(Rect.fromLTWH(10, 20, 30, 40), const Size(100, 200)),
        Rect.fromLTWH(20, 60, 40, 30),
      );
    });

    test('insets and corner radii turn the same way', () {
      expect(
        rotateInsetsCcw(const EdgeInsets.fromLTRB(1, 2, 3, 4)),
        const EdgeInsets.fromLTRB(2, 3, 4, 1),
      );
      final turned = rotateRadiiCcw(
        const BorderRadius.only(
          topLeft: Radius.circular(1),
          topRight: Radius.circular(2),
          bottomRight: Radius.circular(3),
          bottomLeft: Radius.circular(4),
        ),
      );
      expect(turned.topLeft.x, 2);
      expect(turned.topRight.x, 3);
      expect(turned.bottomRight.x, 4);
      expect(turned.bottomLeft.x, 1);
    });

    test('a phone turned to landscape carries its island to the left', () {
      final screen = DeviceCatalog.byId('apple.iphone-17-pro')!.primaryScreen;

      final portrait = screen.cutoutRectsFor(Orientation.portrait).single;
      expect(portrait, Rect.fromLTWH(138, 11, 126, 37));

      final landscape = screen.cutoutRectsFor(Orientation.landscape).single;
      expect(landscape, Rect.fromLTWH(11, 138, 37, 126));

      final feature = screen
          .displayFeaturesFor(Orientation.landscape, FoldPosture.flat)
          .single;
      expect(feature.type, DisplayFeatureType.cutout);
      expect(feature.bounds, landscape);
    });

    test('screen corners turn with the device', () {
      final cover = DeviceCatalog.byId('apple.iphone-duo')!.screens.last;
      final natural = cover.borderRadiusFor(Orientation.portrait);
      final turned = cover.borderRadiusFor(Orientation.landscape);
      expect(natural.topRight.x, 58);
      expect(turned.topLeft.x, 58);
      expect(turned.topRight.x, 58);
      expect(turned.bottomLeft.x, 8);
    });

    test('a button sits on the edge it was declared on', () {
      const body = Size(100, 200);
      expect(
        const DeviceButton(AxisDirection.right, 0.25, 0.1).rect(body),
        Rect.fromLTWH(99, 50, 4, 20),
      );
      expect(
        const DeviceButton(AxisDirection.left, 0.25, 0.1).rect(body),
        Rect.fromLTWH(-3, 50, 4, 20),
      );
      expect(
        const DeviceButton(AxisDirection.up, 0.5, 0.1).rect(body),
        Rect.fromLTWH(50, -3, 10, 4),
      );
      expect(
        const DeviceButton(AxisDirection.down, 0.5, 0.1).rect(body),
        Rect.fromLTWH(50, 199, 10, 4),
      );
    });

    DeviceBodyPainter bodyPainter(WidgetTester t) => t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<DeviceBodyPainter>()
        .single;

    Widget harness(DeviceLabController c) => DeviceLab(
          controller: c,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const SizedBox(),
          ),
        );

    testWidgets('the whole body turns, not just the screen', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      await t.pumpWidget(harness(c));
      await t.pumpAndSettle();
      expect(bodyPainter(t).turns, 0);

      c.setOrientation(Orientation.landscape);
      await t.pumpAndSettle();
      expect(bodyPainter(t).turns, 1);

      c.setOrientation(Orientation.portrait);
      await t.pumpAndSettle();
      expect(bodyPainter(t).turns, 0);
    });

    testWidgets('a landscape-natural foldable starts unturned', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-duo');
      await t.pumpWidget(harness(c));
      await t.pumpAndSettle();
      expect(c.orientation, Orientation.landscape);
      expect(bodyPainter(t).turns, 0);

      c.toggleOrientation();
      await t.pumpAndSettle();
      expect(bodyPainter(t).turns, 1);
    });

    testWidgets('hiding the preview draws no body', (t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro')
        ..setOrientation(Orientation.landscape)
        ..setPreviewing(false);
      await t.pumpWidget(harness(c));
      await t.pumpAndSettle();
      expect(bodyPainter(t).turns, 0);
      expect(bodyPainter(t).frame.bodyColor.a, 0);
    });
  });

  group('iPhone Duo style', () {
    final duo = DeviceCatalog.byId('apple.iphone-duo')!;
    final inner = duo.screens.first;
    final cover = duo.screens.last;

    test('the open display has no punched camera', () {
      expect(inner.cutouts, isEmpty);
      expect(inner.ppi, 430);
      expect(cover.ppi, 460);
    });

    test('the cover camera sits in the top right corner', () {
      final rect = cover.cutoutRectsFor(Orientation.portrait).single;
      expect(rect.size, const Size(38, 38));
      expect(cover.logicalSize.width - rect.right, closeTo(29, 0.01));
      expect(rect.top, closeTo(28, 0.01));
      expect(cover.cutouts.single.shape, CutoutShape.dynamicIsland);
    });

    test('the spine side is square and the outer side is round', () {
      final corners = cover.corners!;
      expect(corners.topLeft.x, lessThan(corners.topRight.x));
      expect(corners.bottomLeft.x, lessThan(corners.bottomRight.x));
      expect(cover.frame!.corners!.topLeft.x, lessThan(30));
      expect(cover.frame!.corners!.topRight.x, greaterThan(60));
    });

    test('bezels follow the published body size', () {
      final open = inner.frame!.bezel;
      expect(open.left, closeTo(19.4, 0.5));
      expect(open.horizontal, closeTo(open.vertical, 0.2));

      final closed = cover.frame!.bezel;
      expect(closed.left - closed.right, closeTo(7, 0.01));
      expect(closed.top, closeTo(closed.bottom, 0.01));
    });

    test('each posture is drawn in its own body', () {
      expect(duo.frameFor(inner), isNot(same(duo.frameFor(cover))));
      expect(duo.frameFor(cover).spine?.side, AxisDirection.left);
      expect(duo.frameFor(inner).spine, isNull);
      expect(duo.frameFor(inner).buttons, hasLength(3));
      expect(duo.frameFor(cover).buttons, hasLength(3));

      final c = DeviceLabController(initialDeviceId: 'apple.iphone-duo');
      expect(c.frame.spine, isNull);
      c.setPosture(FoldPosture.folded);
      expect(c.frame.spine, isNotNull);
    });

    test('only the closed body reports a camera to the app', () {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-duo');
      final open = c.resolveMediaQuery(const MediaQueryData());
      expect(open.displayFeatures.map((f) => f.type), [
        DisplayFeatureType.fold,
      ]);

      c.setPosture(FoldPosture.folded);
      final closed = c.resolveMediaQuery(const MediaQueryData());
      expect(closed.displayFeatures.map((f) => f.type), [
        DisplayFeatureType.cutout,
      ]);
    });

    test('json keeps the whole look through a round trip', () {
      final restored = DeviceSpecCodec.fromJson(DeviceSpecCodec.toJson(duo));
      final restoredCover = restored.screens.last;
      expect(restoredCover.cutouts.single.alignment, Alignment.topRight);
      expect(restoredCover.corners!.topRight.x, 58);
      expect(restoredCover.ppi, 460);
      expect(restoredCover.frame!.spine!.side, AxisDirection.left);
      expect(restoredCover.frame!.buttons, hasLength(3));
      expect(restored.screens.first.frame!.buttons, hasLength(3));
      expect(restored.screens.first.frame!.corners!.topLeft.x, 64);
    });
  });

  group('zoom', () {
    Widget harness(DeviceLabController c) => DeviceLab(
          controller: c,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const SizedBox(),
          ),
        );

    Future<DeviceLabController> pumpCollapsed(WidgetTester t) async {
      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro')
        ..setToolsVisible(false);
      await t.pumpWidget(harness(c));
      await t.pumpAndSettle();
      return c;
    }

    bool enabled(WidgetTester t, String tooltip) =>
        t
            .widget<IconButton>(
                find.widgetWithIcon(IconButton, _iconFor(tooltip)))
            .onPressed !=
        null;

    testWidgets('the stage reports the scale it actually drew at', (t) async {
      final c = await pumpCollapsed(t);
      final m = c.stageMetrics.value;
      expect(c.isFit, isTrue);
      expect(m.scale, greaterThan(0.2));
      expect(m.scale, lessThanOrEqualTo(m.fitLimit + 0.001));
      expect(find.text('${(m.scale * 100).round()}%'), findsOneWidget);
    });

    testWidgets('zooming out steps down and leaves fit mode', (t) async {
      final c = await pumpCollapsed(t);
      final before = c.stageMetrics.value.scale;

      await t.tap(find.byTooltip('Zoom out'));
      await t.pumpAndSettle();

      expect(c.isFit, isFalse);
      expect(c.zoom, lessThan(before));
      expect(c.stageMetrics.value.scale, closeTo(c.zoom!, 0.001));
      expect(DeviceLabController.zoomSteps, contains(c.zoom));
    });

    testWidgets('zoom in is unavailable when already at the largest fit',
        (t) async {
      final c = await pumpCollapsed(t);
      expect(c.canZoomIn, isFalse);
      expect(enabled(t, 'Zoom in'), isFalse);

      await t.tap(find.byTooltip('Zoom out'));
      await t.pumpAndSettle();
      expect(c.canZoomIn, isTrue);
      expect(enabled(t, 'Zoom in'), isTrue);

      await t.tap(find.byTooltip('Zoom in'));
      await t.pumpAndSettle();
      expect(c.stageMetrics.value.scale, greaterThan(c.zoom! - 0.001));
    });

    testWidgets('the fit button returns to automatic sizing', (t) async {
      final c = await pumpCollapsed(t);
      final fitScale = c.stageMetrics.value.scale;
      expect(enabled(t, 'Fit to screen'), isFalse);

      await t.tap(find.byTooltip('Zoom out'));
      await t.pumpAndSettle();
      expect(enabled(t, 'Fit to screen'), isTrue);

      await t.tap(find.byTooltip('Fit to screen'));
      await t.pumpAndSettle();
      expect(c.isFit, isTrue);
      expect(c.stageMetrics.value.scale, closeTo(fitScale, 0.001));
    });

    testWidgets('a zoom larger than the space allows is drawn at the limit',
        (t) async {
      final c = await pumpCollapsed(t);
      final limit = c.stageMetrics.value.fitLimit;

      c.setZoom(4);
      await t.pumpAndSettle();
      expect(c.zoom, 4);
      expect(c.stageMetrics.value.scale, closeTo(limit, 0.001));
    });

    testWidgets('the bar keeps zoom on a narrow phone', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final c = await pumpCollapsed(t);
      expect(find.byTooltip('Zoom out'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Rotate'), findsOneWidget);
      expect(find.text('iPhone 17 Pro'), findsOneWidget);

      await t.tap(find.byTooltip('Zoom out'));
      await t.pumpAndSettle();
      expect(c.isFit, isFalse);
    });

    test('zoom is clamped and remembered', () {
      SessionDeviceLabStorage.clear();
      const store = SessionDeviceLabStorage();
      final first = DeviceLabController(storage: store);
      expect(first.isFit, isTrue);

      first.setZoom(0.5);
      expect(DeviceLabController(storage: store).zoom, 0.5);

      first.setZoom(99);
      expect(first.zoom, 4);
      first.setZoom(0.001);
      expect(first.zoom, 0.1);

      first.setZoom(null);
      expect(DeviceLabController(storage: store).isFit, isTrue);
      SessionDeviceLabStorage.clear();
    });
  });

  group('flip phones', () {
    DeviceSpec flip(String id) => DeviceCatalog.byId(id)!;

    const vendor = {
      'samsung.galaxy-z-flip-8': (Size(1080, 2520), Size(948, 1048)),
      'samsung.galaxy-z-flip-7': (Size(1080, 2520), Size(948, 1048)),
      'samsung.galaxy-z-flip-6': (Size(1080, 2640), Size(720, 748)),
      'samsung.galaxy-z-flip-5': (Size(1080, 2640), Size(720, 748)),
      'samsung.galaxy-z-flip-4': (Size(1080, 2640), Size(512, 260)),
      'motorola.razr-50-ultra': (Size(1080, 2640), Size(1080, 1272)),
      'motorola.razr-2023': (Size(1080, 2640), Size(368, 194)),
    };

    test('every flip matches the vendor pixel resolutions', () {
      for (final entry in vendor.entries) {
        final d = flip(entry.key);
        expect(d.screens.first.resolution, entry.value.$1, reason: entry.key);
        expect(d.screens.last.resolution, entry.value.$2, reason: entry.key);
      }
      expect(flipDevices.map((d) => d.id).toSet(), vendor.keys.toSet());
    });

    test('the Flip 8 is in the catalog and is a flip', () {
      final d = flip('samsung.galaxy-z-flip-8');
      expect(d.category, DeviceCategory.foldable);
      expect(d.releaseYear, 2026);
      expect(d.primaryScreen.hinge?.axis, Axis.horizontal);
    });

    test('pixel densities agree with what the vendors publish', () {
      const ppi = {
        'motorola.razr-50-ultra': (413.0, 417.0),
        'motorola.razr-2023': (413.0, 282.0),
        'samsung.galaxy-z-flip-6': (426.0, 305.0),
        'samsung.galaxy-z-flip-5': (426.0, 305.0),
        'samsung.galaxy-z-flip-7': (397.0, 343.0),
      };
      for (final entry in ppi.entries) {
        final d = flip(entry.key);
        expect(d.screens.first.ppi, closeTo(entry.value.$1, 4),
            reason: entry.key);
        expect(d.screens.last.ppi, closeTo(entry.value.$2, 4),
            reason: entry.key);
      }
    });

    test('open bodies reproduce the vendors screen-to-body ratios', () {
      const quoted = {
        'samsung.galaxy-z-flip-8': 87.1,
        'samsung.galaxy-z-flip-7': 88.7,
        'samsung.galaxy-z-flip-6': 85.5,
        'samsung.galaxy-z-flip-5': 85.9,
        'samsung.galaxy-z-flip-4': 85.4,
        'motorola.razr-50-ultra': 85.33,
        'motorola.razr-2023': 85.5,
      };
      for (final entry in quoted.entries) {
        final s = flip(entry.key).primaryScreen;
        final bezel = s.frame!.bezel;
        final ratio = s.logicalSize.width *
            s.logicalSize.height /
            ((s.logicalSize.width + bezel.horizontal) *
                (s.logicalSize.height + bezel.vertical)) *
            100;
        expect(ratio, closeTo(entry.value, 1.3), reason: entry.key);
      }
    });

    test('no screen is larger than the body it sits in', () {
      for (final d in flipDevices) {
        for (final s in d.screens) {
          final b = s.frame!.bezel;
          expect(
            [b.left, b.top, b.right, b.bottom].every((v) => v >= 0),
            isTrue,
            reason: '${d.id} ${s.label}',
          );
        }
      }
    });

    test('the closed chin is deep enough to hold the hinge', () {
      for (final d in flipDevices) {
        final closed = d.screens.last.frame!;
        expect(
          closed.bezel.bottom,
          greaterThanOrEqualTo(closed.spine!.width),
          reason: d.id,
        );
      }
    });

    test('each posture has its own body, with the hinge only when closed', () {
      for (final d in flipDevices) {
        final open = d.frameFor(d.screens.first);
        final closed = d.frameFor(d.screens.last);
        expect(open, isNot(same(closed)), reason: d.id);
        expect(open.spine, isNull, reason: d.id);
        expect(closed.spine?.side, AxisDirection.down, reason: d.id);
        expect(open.buttons, hasLength(2), reason: d.id);
        expect(closed.buttons, hasLength(2), reason: d.id);
        expect(closed.buttons.first.side, AxisDirection.left, reason: d.id);
        expect(open.buttons.first.side, AxisDirection.right, reason: d.id);
      }
    });

    test('full-face covers carry their cameras in the screen', () {
      for (final id in [
        'samsung.galaxy-z-flip-8',
        'samsung.galaxy-z-flip-7',
        'motorola.razr-50-ultra',
      ]) {
        final cover = flip(id).screens.last;
        expect(cover.cutouts, hasLength(2), reason: id);
        expect(cover.frame!.lenses, isEmpty, reason: id);
        final rects = cover.cutoutRectsFor(Orientation.portrait);
        for (final r in rects) {
          expect(r.left, greaterThanOrEqualTo(0), reason: id);
          expect(r.top, greaterThanOrEqualTo(0), reason: id);
          expect(r.right, lessThan(cover.logicalSize.width / 2), reason: id);
        }
      }
    });

    test('small covers keep their cameras beside the screen', () {
      for (final id in [
        'samsung.galaxy-z-flip-6',
        'samsung.galaxy-z-flip-5',
        'samsung.galaxy-z-flip-4',
        'motorola.razr-2023',
      ]) {
        final cover = flip(id).screens.last;
        expect(cover.cutouts, isEmpty, reason: id);
        expect(cover.frame!.lenses, hasLength(2), reason: id);
      }
    });

    test('the Flip 4 cover is a wide strip, not a square', () {
      final cover = flip('samsung.galaxy-z-flip-4').screens.last;
      expect(cover.logicalSize.width, greaterThan(cover.logicalSize.height));
      expect(cover.resolution, const Size(512, 260));
    });

    test('lenses survive a json round trip', () {
      final d = flip('samsung.galaxy-z-flip-6');
      final restored = DeviceSpecCodec.fromJson(DeviceSpecCodec.toJson(d));
      final lenses = restored.screens.last.frame!.lenses;
      expect(lenses, hasLength(2));
      expect(lenses.first.center, d.screens.last.frame!.lenses.first.center);
      expect(lenses.first.radius, d.screens.last.frame!.lenses.first.radius);
    });

    testWidgets('a closed flip turns its whole body when rotated', (t) async {
      final c = DeviceLabController(initialDeviceId: 'samsung.galaxy-z-flip-7')
        ..setPosture(FoldPosture.folded);
      await t.pumpWidget(
        DeviceLab(
          controller: c,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const SizedBox(),
          ),
        ),
      );
      await t.pumpAndSettle();

      DeviceBodyPainter painter() => t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<DeviceBodyPainter>()
          .single;

      expect(painter().turns, 0);
      expect(painter().frame.spine?.side, AxisDirection.down);

      c.setOrientation(Orientation.landscape);
      await t.pumpAndSettle();
      expect(painter().turns, 1);
      expect(c.logicalSize, const Size(349.3333333333333, 316));
    });
  });

  group('custom resolution fields', () {
    Widget harness(DeviceLabController c) => DeviceLab(
          controller: c,
          builder: (_) => MaterialApp(
            builder: DeviceLab.appBuilder,
            home: const SizedBox(),
          ),
        );

    String text(WidgetTester t, int index) =>
        t.widget<TextField>(find.byType(TextField).at(index)).controller!.text;

    testWidgets('follow the selected device and posture', (t) async {
      t.view.physicalSize = const Size(1200, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      await t.pumpWidget(harness(c));
      await t.pumpAndSettle();
      expect(text(t, 1), '402');
      expect(text(t, 2), '874');

      c.selectDeviceId('samsung.galaxy-z-flip-6');
      c.setPosture(FoldPosture.folded);
      await t.pumpAndSettle();
      expect(text(t, 1), '240');
      expect(text(t, 2), '249');

      c.setOrientation(Orientation.landscape);
      await t.pumpAndSettle();
      expect(text(t, 1), '249');
      expect(text(t, 2), '240');
    });

    testWidgets('leave what is being typed alone', (t) async {
      t.view.physicalSize = const Size(1200, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final c = DeviceLabController(initialDeviceId: 'apple.iphone-17-pro');
      await t.pumpWidget(harness(c));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).at(1), '500');
      c.setBrightness(Brightness.dark);
      await t.pumpAndSettle();
      expect(text(t, 1), '500');
    });
  });

  group('golden helpers', () {
    testWidgets('applyDevice configures the test view', (t) async {
      final fold = DeviceCatalog.byId('google.pixel-10-pro-fold')!;
      await t.pumpOnDevice(
        const MaterialApp(home: SizedBox()),
        fold,
        posture: FoldPosture.flat,
      );
      expect(t.view.devicePixelRatio, 2.625);
      expect(t.view.physicalSize.width, closeTo(791 * 2.625, 0.01));
      expect(t.view.displayFeatures, hasLength(1));
    });

    test('golden names are stable and posture-aware', () {
      final fold = DeviceCatalog.byId('samsung.galaxy-z-fold-7')!;
      expect(
        goldenNameFor(fold, scenario: 'home', posture: FoldPosture.folded),
        'goldens/home_samsung-galaxy-z-fold-7_portrait_folded.png',
      );
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _n = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('count $_n'),
              TextButton(
                onPressed: () => setState(() => _n++),
                child: const Text('tap me'),
              ),
            ],
          ),
        ),
      );
}

class _MountCounter extends StatefulWidget {
  const _MountCounter();

  static int mounts = 0;

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    _MountCounter.mounts++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _Scope extends InheritedWidget {
  const _Scope({required this.value, required super.child});

  final int value;

  static int of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_Scope>();
    if (scope == null) throw StateError('No _Scope found');
    return scope.value;
  }

  @override
  bool updateShouldNotify(_Scope old) => old.value != value;
}

IconData _iconFor(String tooltip) => switch (tooltip) {
      'Zoom in' => Icons.add,
      'Zoom out' => Icons.remove,
      'Fit to screen' => Icons.fit_screen,
      _ => throw ArgumentError(tooltip),
    };
