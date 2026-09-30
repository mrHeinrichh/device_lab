import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/device_spec.dart';
import 'device_lab_controller.dart';
import 'device_lab_storage.dart';
import 'device_stage.dart';
import 'tools_panel.dart';
import 'zoom_controls.dart';

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
  Widget build(BuildContext context) {
    final app = Builder(builder: widget.builder);
    return DeviceLabScope(
      notifier: _controller,
      child: _PreviewShortcuts(
        controller: _controller,
        child: _DeviceLabHost(
          app: app,
          availableLocales: widget.availableLocales,
          backgroundColor: widget.backgroundColor,
          showRestoreButton: widget.showRestoreButton,
        ),
      ),
    );
  }
}

/// Exposes the [DeviceLabController] to the subtree, including across the
/// boundary into your own `MaterialApp`.
class DeviceLabScope extends InheritedNotifier<DeviceLabController> {
  /// Creates a scope around [child].
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

    return MediaQuery.fromView(
      view: View.of(context),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: _HostShell(
          controller: controller,
          availableLocales: availableLocales,
          backgroundColor: backgroundColor,
          showRestoreButton: showRestoreButton,
          child: app,
        ),
      ),
    );
  }
}

class _LabApp extends StatelessWidget {
  const _LabApp({required this.child});

  final Widget child;

  static final ThemeData _theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3D5AFE),
      brightness: Brightness.dark,
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme,
        home: child,
      );
}

class _HostShell extends StatelessWidget {
  const _HostShell({
    required this.controller,
    required this.availableLocales,
    required this.showRestoreButton,
    required this.child,
    this.backgroundColor,
  });

  final DeviceLabController controller;
  final List<Locale> availableLocales;
  final bool showRestoreButton;
  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final expanded = controller.previewing && controller.toolsVisible;
    final collapsed = controller.previewing && !controller.toolsVisible;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebar = expanded && constraints.maxWidth >= 900;
        final barHeight =
            _CompactBar.heightFor(constraints.maxWidth, bottomInset);
        return Stack(
          children: [
            Positioned.fill(
              child: Flex(
                direction: sidebar ? Axis.horizontal : Axis.vertical,
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: controller.previewing
                          ? (backgroundColor ?? const Color(0xFF15151A))
                          : const Color(0x00000000),
                      child: DeviceStage(
                        controller: controller,
                        child: child,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: sidebar ? 320 : null,
                    height: sidebar
                        ? null
                        : expanded
                            ? 300
                            : collapsed
                                ? barHeight
                                : 0,
                    child: expanded
                        ? _LabApp(
                            child: ToolsPanel(
                              controller: controller,
                              availableLocales: availableLocales,
                            ),
                          )
                        : collapsed
                            ? _LabApp(
                                child: _CompactBar(controller: controller))
                            : null,
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: _Chrome(
                controller: controller,
                showRestoreButton: showRestoreButton,
              ),
            ),
          ],
        );
      },
    );
  }
}

IconData _categoryIcon(DeviceCategory category) => switch (category) {
      DeviceCategory.phone => Icons.smartphone,
      DeviceCategory.foldable => Icons.book_outlined,
      DeviceCategory.tablet => Icons.tablet_mac,
      DeviceCategory.desktop => Icons.desktop_windows,
      DeviceCategory.watch => Icons.watch,
      DeviceCategory.tv => Icons.tv,
    };

class _CompactBar extends StatelessWidget {
  const _CompactBar({required this.controller});

  static const double wideBreakpoint = 680;

  static double heightFor(double width, double bottomInset) =>
      1 + (width >= wideBreakpoint ? 56 : 92) + bottomInset;

  final DeviceLabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _CompactBar.wideBreakpoint;
                final info = Expanded(child: _DeviceInfo(controller));
                final actions = [
                  IconButton(
                    tooltip: 'Rotate',
                    iconSize: 20,
                    onPressed: controller.canRotate
                        ? controller.toggleOrientation
                        : null,
                    icon: const Icon(Icons.screen_rotation),
                  ),
                  IconButton(
                    tooltip: 'Show original screen',
                    iconSize: 20,
                    onPressed: () => controller.setPreviewing(false),
                    icon: const Icon(Icons.fullscreen),
                  ),
                  IconButton(
                    tooltip: 'Show options',
                    iconSize: 22,
                    onPressed: () => controller.setToolsVisible(true),
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  const SizedBox(width: 4),
                ];

                if (wide) {
                  return SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        _DeviceIcon(controller),
                        const SizedBox(width: 10),
                        info,
                        SizedBox(
                          width: 300,
                          child: ZoomControls(controller: controller),
                        ),
                        ...actions,
                      ],
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          _DeviceIcon(controller),
                          const SizedBox(width: 10),
                          info,
                          ...actions,
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ZoomControls(controller: controller),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon(this.controller);

  final DeviceLabController controller;

  @override
  Widget build(BuildContext context) => Icon(
        _categoryIcon(
          controller.isFreeform
              ? DeviceCategory.desktop
              : controller.device.category,
        ),
        size: 18,
      );
}

class _DeviceInfo extends StatelessWidget {
  const _DeviceInfo(this.controller);

  final DeviceLabController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.logicalSize;
    final screen = controller.screen;
    final ppi = screen.ppi;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          controller.isFreeform ? 'Custom viewport' : controller.device.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          '${size.width.toStringAsFixed(0)} × ${size.height.toStringAsFixed(0)} dp'
          '  ·  @${screen.pixelRatio}x'
          '${ppi == null ? '' : '  ·  ${ppi.round()} ppi'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: muted),
        ),
      ],
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({required this.controller, required this.showRestoreButton});

  final DeviceLabController controller;
  final bool showRestoreButton;

  @override
  Widget build(BuildContext context) {
    if (!controller.previewing) {
      if (!showRestoreButton) return const SizedBox.shrink();
      return _RestoreLayer(controller: controller);
    }
    return const SizedBox.shrink();
  }
}

class _RestoreLayer extends StatefulWidget {
  const _RestoreLayer({required this.controller});

  final DeviceLabController controller;

  @override
  State<_RestoreLayer> createState() => _RestoreLayerState();
}

class _RestoreLayerState extends State<_RestoreLayer> {
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
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedAlign(
            alignment: _alignment,
            duration:
                _dragging ? Duration.zero : const Duration(milliseconds: 220),
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
      );
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

bool get isDeviceLabAvailable => !kReleaseMode;
