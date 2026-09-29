import 'package:device_lab/device_lab.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    DeviceLab(
      initialDeviceId: const String.fromEnvironment(
        'DEVICE',
        defaultValue: 'apple.iphone-duo',
      ),
      restoreButtonAlignment: Alignment.bottomLeft,
      availableLocales: const [Locale('en'), Locale('ja'), Locale('ar')],
      builder: (_) => const DemoApp(),
    ),
  );
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: DeviceLab.appBuilder,
      locale: DeviceLab.localeOf(context),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final fold = media.separatingFold;

    return Scaffold(
      appBar: AppBar(title: const Text('device_lab demo')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      body: fold == null
          ? _Panel(media: media)
          : media.isBookPosture
              ? Row(
                  children: [
                    SizedBox(
                      width: fold.bounds.center.dx - 0.5,
                      child: _Panel(media: media),
                    ),
                    const VerticalDivider(width: 1),
                    const Expanded(child: _DetailPane()),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(
                      height: fold.bounds.center.dy -
                          media.padding.top -
                          kToolbarHeight -
                          0.5,
                      child: _Panel(media: media),
                    ),
                    const Divider(height: 1),
                    const Expanded(child: _DetailPane()),
                  ],
                ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.media});

  final MediaQueryData media;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Viewport',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _Row(
                    'size',
                    '${media.size.width.toStringAsFixed(0)} × '
                        '${media.size.height.toStringAsFixed(0)} dp'),
                _Row('dpr', '${media.devicePixelRatio}'),
                _Row('padding', media.padding.toString()),
                _Row('textScale', media.textScaler.scale(1).toStringAsFixed(2)),
                _Row('platform', Theme.of(context).platform.name),
                _Row('features', '${media.displayFeatures.length}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 8; i++)
          ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text('Item ${i + 1}'),
            subtitle: const Text('Scroll physics follow the device platform'),
          ),
      ],
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Two-pane layout\nselected by the fold display feature',
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(label)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontFamilyFallback: ['monospace']),
              ),
            ),
          ],
        ),
      );
}
