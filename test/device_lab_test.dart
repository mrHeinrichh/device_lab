import 'package:device_lab/device_lab.dart';
import 'package:device_lab/device_lab_testing.dart';
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
