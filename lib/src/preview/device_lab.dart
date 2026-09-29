import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device_lab_controller.dart';
import 'device_lab_storage.dart';
import 'device_stage.dart';
import 'tools_panel.dart';

/// Wraps your app in a device preview.
///
/// Place this at the root and point your `MaterialApp.builder` at
/// [appBuilder] so the simulated [MediaQuery] lands below the app and reaches
/// every route:
///
/// ```dart
/// void main() => runApp(
///       DeviceLab(
///         enabled: isDeviceLabAvailable,
///         builder: (_) => const MyApp(),
///       ),
///     );
///
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) => MaterialApp(
///         builder: DeviceLab.appBuilder,
///         locale: DeviceLab.localeOf(context),
///         home: const HomePage(),
///       );
/// }
/// ```
class DeviceLab extends StatefulWidget {
  const DeviceLab({
    super.key,
    required this.builder,
    this.enabled = !kReleaseMode,
    this.controller,
    this.initialDeviceId,
    this.availableLocales = const [Locale('en')],
    this.backgroundColor,
    this.showRestoreButton = true,
    this.restoreButtonAlignment,
    this.storage = const SessionDeviceLabStorage(),
  });

  /// Builds the app being previewed.
  final WidgetBuilder builder;

  /// Whether the preview is available at all.
  ///
  /// Defaults to every build except release, so the preview never ships to
  /// production. When false the app is returned untouched and [appBuilder] is
  /// a pass-through.
  final bool enabled;

  /// An externally owned controller. One is created when this is null.
  final DeviceLabController? controller;

  /// The [DeviceSpec.id] to start on when [storage] remembers nothing.
  ///
  /// This is a seed, not an override: once a device has been picked, the
  /// remembered one wins.
  final String? initialDeviceId;

  /// Locales offered in the tools panel.
  final List<Locale> availableLocales;

  /// Colour behind the device frame.
  final Color? backgroundColor;

  /// Whether to float a restore button over the app while the preview is
  /// hidden.
  final bool showRestoreButton;

  /// The corner to dock the restore button to.
  ///
  /// Takes precedence over the value already on [controller]. Dragging the
  /// button re-docks it to the nearest corner.
  final Alignment? restoreButtonAlignment;

  /// Where the selected device, orientation and posture are remembered.
  ///
  /// Defaults to [SessionDeviceLabStorage], which keeps the selection for the
  /// lifetime of the process, so rebuilding or hiding the preview no longer
  /// snaps back to [initialDeviceId]. Pass your own implementation to persist
  /// across restarts, or null to disable.
  final DeviceLabStorage? storage;

  /// The nearest controller, or null when there is no [DeviceLab] above.
  static DeviceLabController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DeviceLabScope>()?.notifier;

  /// The nearest controller. Asserts when there is no [DeviceLab] above.
  static DeviceLabController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No DeviceLab ancestor found.');
    return controller!;
  }

  /// Installs the simulated [MediaQuery] and [TargetPlatform] below your app.
  ///
  /// Assign this to `MaterialApp.builder`. It is a pass-through whenever the
  /// preview is disabled or hidden, so the app then sees the real window.
  static Widget appBuilder(BuildContext context, Widget? child) {
    final controller = maybeOf(context);
    final content = child ?? const SizedBox.shrink();
    if (controller == null || !controller.active) return content;

    final theme = Theme.of(context);
    return MediaQuery(
      data: controller.resolveMediaQuery(MediaQuery.of(context)),
      child: Theme(
        data: theme.copyWith(platform: controller.device.targetPlatform),
        child: content,
      ),
    );
  }

  /// The simulated locale. Assign to `MaterialApp.locale`.
  static Locale? localeOf(BuildContext context) => maybeOf(context)?.locale;

  /// Flips between the preview and the app's original screen.
  static void togglePreview(BuildContext context) =>
      maybeOf(context)?.togglePreview();

  /// Shows the preview, or the app's original screen.
  static void setPreviewing(BuildContext context, bool value) =>
      maybeOf(context)?.setPreviewing(value);

  /// Whether the simulated [MediaQuery] is currently applied.
  static bool isPreviewing(BuildContext context) =>
      maybeOf(context)?.active ?? false;

  @override
  State<DeviceLab> createState() => _DeviceLabState();
}

class _DeviceLabState extends State<DeviceLab> {
  late DeviceLabController _controller;

  late final Widget _app = KeyedSubtree(
    key: GlobalKey(debugLabel: 'device_lab.app'),
    child: Builder(builder: widget.builder),
  );

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        DeviceLabController(
          initialDeviceId: widget.initialDeviceId,
          enabled: widget.enabled,
          storage: widget.storage,
        );
    final alignment = widget.restoreButtonAlignment;
    if (alignment != null) _controller.setRestoreAlignment(alignment);
  }

  @override
  void didUpdateWidget(DeviceLab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _controller.setEnabled(widget.enabled);
    }
    final alignment = widget.restoreButtonAlignment;
    if (alignment != null && alignment != oldWidget.restoreButtonAlignment) {
      _controller.setRestoreAlignment(alignment);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DeviceLabScope(
        notifier: _controller,
        child: _PreviewShortcuts(
          controller: _controller,
          child: _DeviceLabHost(
            app: _app,
            availableLocales: widget.availableLocales,
            backgroundColor: widget.backgroundColor,
            showRestoreButton: widget.showRestoreButton,
          ),
        ),
      );
}

/// Exposes the [DeviceLabController] to the subtree, including across the
/// boundary into your own `MaterialApp`.
class DeviceLabScope extends InheritedNotifier<DeviceLabController> {
  const DeviceLabScope({
    super.key,
    required DeviceLabController super.notifier,
    required super.child,
  });
}

class _TogglePreviewIntent extends Intent {
  const _TogglePreviewIntent();
}

class _PreviewShortcuts extends StatelessWidget {
  const _PreviewShortcuts({required this.controller, required this.child});

  final DeviceLabController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!controller.enabled) return child;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true):
            _TogglePreviewIntent(),
        SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true):
            _TogglePreviewIntent(),
      },
      child: Actions(
        actions: {
          _TogglePreviewIntent: CallbackAction<_TogglePreviewIntent>(
            onInvoke: (_) {
              controller.togglePreview();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _DeviceLabHost extends StatelessWidget {
  const _DeviceLabHost({
    required this.app,
    required this.availableLocales,
    required this.showRestoreButton,
    this.backgroundColor,
  });

  final Widget app;
  final List<Locale> availableLocales;
  final bool showRestoreButton;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final controller = DeviceLab.of(context);
    if (!controller.enabled) return app;
    if (!controller.previewing) {
      return _OriginalScreen(
        controller: controller,
        showRestoreButton: showRestoreButton,
        child: app,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D5AFE),
          brightness: Brightness.dark,
        ),
      ),
      home: _HostShell(
        controller: controller,
        availableLocales: availableLocales,
        backgroundColor: backgroundColor,
        child: app,
      ),
    );
  }
}

class _OriginalScreen extends StatefulWidget {
  const _OriginalScreen({
    required this.controller,
    required this.showRestoreButton,
    required this.child,
  });

  final DeviceLabController controller;
  final bool showRestoreButton;
  final Widget child;

  @override
  State<_OriginalScreen> createState() => _OriginalScreenState();
}

class _OriginalScreenState extends State<_OriginalScreen> {
  bool _dragging = false;

  Alignment get _alignment => widget.controller.restoreAlignment;

  void _moveTo(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return;
    final local = box.globalToLocal(globalPosition);
    widget.controller.setRestoreAlignment(
      Alignment(
        (local.dx / box.size.width * 2 - 1).clamp(-1.0, 1.0),
        (local.dy / box.size.height * 2 - 1).clamp(-1.0, 1.0),
      ),
    );
  }

  static Alignment _dock(Alignment a) =>
      Alignment(a.x < 0 ? -1 : 1, a.y < 0 ? -1 : 1);

  @override
  Widget build(BuildContext context) {
    if (!widget.showRestoreButton) return widget.child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AnimatedAlign(
                  alignment: _alignment,
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    onPanStart: (d) {
                      setState(() => _dragging = true);
                      _moveTo(d.globalPosition);
                    },
                    onPanUpdate: (d) => _moveTo(d.globalPosition),
                    onPanEnd: (_) {
                      widget.controller.setRestoreAlignment(_dock(_alignment));
                      setState(() => _dragging = false);
                    },
                    child: _RestorePill(
                      onTap: () => widget.controller.setPreviewing(true),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestorePill extends StatelessWidget {
  const _RestorePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF3D5AFE),
        shape: const StadiumBorder(),
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phonelink, size: 17, color: Color(0xFFFFFFFF)),
                SizedBox(width: 8),
                DefaultTextStyle(
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                  child: Text('Device Lab'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HostShell extends StatelessWidget {
  const _HostShell({
    required this.controller,
    required this.availableLocales,
    required this.child,
    this.backgroundColor,
  });

  final DeviceLabController controller;
  final List<Locale> availableLocales;
  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final stage = ColoredBox(
      color: backgroundColor ?? const Color(0xFF15151A),
      child: DeviceStage(controller: controller, child: child),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (!controller.toolsVisible) {
            return Stack(
              children: [
                Positioned.fill(child: stage),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'device-lab-tools',
                        tooltip: 'Show tools',
                        onPressed: () => controller.setToolsVisible(true),
                        child: const Icon(Icons.tune),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'device-lab-exit',
                        tooltip: 'Show original screen',
                        onPressed: () => controller.setPreviewing(false),
                        child: const Icon(Icons.fullscreen),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          if (wide) {
            return Row(
              children: [
                SizedBox(
                  width: 320,
                  child: ToolsPanel(
                    controller: controller,
                    availableLocales: availableLocales,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: stage),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: stage),
              const Divider(height: 1),
              SizedBox(
                height: 280,
                child: ToolsPanel(
                  controller: controller,
                  availableLocales: availableLocales,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Whether device_lab should run, that is every build except release.
bool get isDeviceLabAvailable => !kReleaseMode;
