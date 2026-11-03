import 'package:flutter/material.dart';

import '../catalog/device_catalog.dart';
import '../model/device_spec.dart';
import 'device_lab_controller.dart';
import 'zoom_controls.dart';

/// Below this width the header stacks its rows; at or above it the title and
/// search share a row. The 320 dp sidebar and a phone-sized window are narrow.
const double _wideHeader = 560;

class ToolsPanel extends StatefulWidget {
  const ToolsPanel({
    super.key,
    required this.controller,
    required this.availableLocales,
  });

  final DeviceLabController controller;
  final List<Locale> availableLocales;

  @override
  State<ToolsPanel> createState() => _ToolsPanelState();
}

class _ToolsPanelState extends State<ToolsPanel>
    with SingleTickerProviderStateMixin {
  static const int _devicesTab = 0;

  late final TabController _tabs = TabController(length: 2, vsync: this);
  String _query = '';

  DeviceLabController get c => widget.controller;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() => _query = value);
    if (value.isNotEmpty && _tabs.index != _devicesTab) {
      _tabs.animateTo(_devicesTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideHeader;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Capped so the list always keeps room; only a very short panel
              // makes the header scroll.
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: constraints.maxHeight * 0.75),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _Header(
                    controller: c,
                    wide: wide,
                    onSearch: _search,
                  ),
                ),
              ),
              TabBar(
                controller: _tabs,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Devices', height: 36),
                  Tab(text: 'Display', height: 36),
                ],
              ),
              Expanded(
                // Both tabs stay mounted so the device list keeps its scroll
                // position while the user adjusts a setting and comes back.
                child: ListenableBuilder(
                  listenable: _tabs.animation!,
                  builder: (context, _) => IndexedStack(
                    index: _tabs.index,
                    children: [
                      _DeviceList(controller: c, query: _query),
                      _DisplayTab(
                        controller: c,
                        availableLocales: widget.availableLocales,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The part of the panel that never scrolls: what is selected and the controls
/// that are wanted after every switch, so changing device and then rotating or
/// folding it needs no trip back through the list.
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.wide,
    required this.onSearch,
  });

  final DeviceLabController controller;
  final bool wide;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final title = const Text(
      'Device Lab',
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    );
    final search = TextField(
      decoration: const InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.search, size: 18),
        hintText: 'Search devices',
        border: OutlineInputBorder(),
      ),
      onChanged: onSearch,
    );
    final hide = IconButton(
      tooltip: 'Hide options',
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.keyboard_arrow_down, size: 22),
      onPressed: () => c.setToolsVisible(false),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Row(
            children: [
              title,
              const SizedBox(width: 16),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: search,
                ),
              ),
              const Spacer(),
              hide,
            ],
          )
        else ...[
          Row(children: [Expanded(child: title), hide]),
          const SizedBox(height: 4),
          search,
        ],
        const SizedBox(height: 8),
        _ViewportSummary(controller: c, wide: wide),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Chip(
              label: 'Portrait',
              icon: Icons.stay_current_portrait,
              selected: c.orientation == Orientation.portrait,
              onTap: c.canRotate
                  ? () => c.setOrientation(Orientation.portrait)
                  : null,
            ),
            _Chip(
              label: 'Landscape',
              icon: Icons.stay_current_landscape,
              selected: c.orientation == Orientation.landscape,
              onTap: c.canRotate
                  ? () => c.setOrientation(Orientation.landscape)
                  : null,
            ),
            if (c.canFold)
              for (final p in FoldPosture.values)
                _Chip(
                  label: switch (p) {
                    FoldPosture.folded => 'Cover',
                    FoldPosture.halfOpened => 'Half-open',
                    FoldPosture.flat => 'Unfolded',
                  },
                  selected: c.posture == p,
                  onTap: () => c.setPosture(p),
                ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.fullscreen, size: 18),
              label: const Text('Show original screen'),
              onPressed: () => c.setPreviewing(false),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// The device catalog, grouped by category and filtered by [query]. Reveals the
/// selected device when it first appears and when the selection changes from
/// elsewhere, so the list never opens scrolled away from what is selected.
class _DeviceList extends StatefulWidget {
  const _DeviceList({required this.controller, required this.query});

  final DeviceLabController controller;
  final String query;

  @override
  State<_DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends State<_DeviceList> {
  final GlobalKey _selectedKey = GlobalKey();

  String get _selectedId =>
      widget.controller.isFreeform ? '' : widget.controller.device.id;

  @override
  void initState() {
    super.initState();
    _reveal(centered: true);
  }

  @override
  void didUpdateWidget(_DeviceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _reveal(centered: true);
  }

  /// Called after every build in which the selection moved.
  void _reveal({required bool centered}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _selectedKey.currentContext;
      if (!mounted || context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        alignmentPolicy: centered
            ? ScrollPositionAlignmentPolicy.explicit
            : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  String? _lastSelected;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final selectedId = _selectedId;
    if (_lastSelected != null && _lastSelected != selectedId) {
      _reveal(centered: false);
    }
    _lastSelected = selectedId;

    final grouped = <DeviceCategory, List<DeviceSpec>>{};
    for (final d in DeviceCatalog.search(widget.query)) {
      grouped.putIfAbsent(d.category, () => []).add(d);
    }
    // A plain column rather than a lazy list: the selected tile has to exist
    // to be scrolled to, and the catalog is a few hundred rows at most.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (grouped.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('No matching devices', textAlign: TextAlign.center),
            ),
          for (final entry in grouped.entries)
            _Section(
              title: switch (entry.key) {
                DeviceCategory.phone => 'Phones',
                DeviceCategory.foldable => 'Foldables',
                DeviceCategory.tablet => 'Tablets',
                DeviceCategory.desktop => 'Desktop & breakpoints',
                DeviceCategory.watch => 'Watches',
                DeviceCategory.tv => 'TV',
              },
              child: Column(
                children: [
                  for (final d in entry.value)
                    _DeviceTile(
                      key: d.id == selectedId ? _selectedKey : null,
                      device: d,
                      selected: d.id == selectedId,
                      onTap: () => c.selectDevice(d),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Zoom, custom resolution, appearance, accessibility and locale: the
/// settings that are changed occasionally rather than after every switch.
class _DisplayTab extends StatelessWidget {
  const _DisplayTab({required this.controller, required this.availableLocales});

  final DeviceLabController controller;
  final List<Locale> availableLocales;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        _Section(
          title: 'Zoom',
          child: ZoomControls(controller: c),
        ),
        _Section(
          title: 'Custom resolution',
          child: _FreeformControls(controller: c),
        ),
        _Section(
          title: 'Appearance',
          child: Column(
            children: [
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark mode'),
                value: c.brightness == Brightness.dark,
                onChanged: (v) => c.setBrightness(
                  v ? Brightness.dark : Brightness.light,
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Device frame'),
                value: c.showFrame,
                onChanged: c.isFreeform ? null : c.setShowFrame,
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Safe area overlay'),
                value: c.showSafeAreas,
                onChanged: c.setShowSafeAreas,
              ),
            ],
          ),
        ),
        _Section(
          title: 'Accessibility',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Text scale  ×${c.textScale.toStringAsFixed(2)}'),
              Slider(
                min: 0.5,
                max: 3.5,
                divisions: 30,
                value: c.textScale,
                onChanged: c.setTextScale,
              ),
              _Toggle('Bold text', c.boldText, c.setBoldText),
              _Toggle('High contrast', c.highContrast, c.setHighContrast),
              _Toggle('Invert colors', c.invertColors, c.setInvertColors),
              _Toggle(
                'Disable animations',
                c.disableAnimations,
                c.setDisableAnimations,
              ),
              _Toggle(
                'Screen reader nav',
                c.accessibleNavigation,
                c.setAccessibleNavigation,
              ),
            ],
          ),
        ),
        if (availableLocales.length > 1)
          _Section(
            title: 'Locale',
            child: DropdownButton<Locale>(
              isExpanded: true,
              value: c.locale ?? availableLocales.first,
              items: [
                for (final l in availableLocales)
                  DropdownMenuItem(value: l, child: Text(l.toLanguageTag())),
              ],
              onChanged: c.setLocale,
            ),
          ),
      ],
    );
  }
}

class _ViewportSummary extends StatelessWidget {
  const _ViewportSummary({required this.controller, required this.wide});

  final DeviceLabController controller;

  /// Name and details share one line when there is room for it.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final size = controller.logicalSize;
    final screen = controller.screen;
    final px = Size(
      size.width * screen.pixelRatio,
      size.height * screen.pixelRatio,
    );
    final name = Text(
      controller.isFreeform ? 'Custom viewport' : controller.device.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    final details = Text(
      '${size.width.toStringAsFixed(0)} × ${size.height.toStringAsFixed(0)} dp'
      '  ·  @${screen.pixelRatio}x'
      '  ·  ${px.width.toStringAsFixed(0)} × ${px.height.toStringAsFixed(0)} px'
      '${screen.ppi == null ? '' : '  ·  ${screen.ppi!.round()} ppi'}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: wide
          ? Row(
              children: [
                name,
                const SizedBox(width: 12),
                Expanded(child: details),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [name, const SizedBox(height: 2), details],
            ),
    );
  }
}

class _FreeformControls extends StatefulWidget {
  const _FreeformControls({required this.controller});

  final DeviceLabController controller;

  @override
  State<_FreeformControls> createState() => _FreeformControlsState();
}

class _FreeformControlsState extends State<_FreeformControls> {
  late final TextEditingController _w = TextEditingController(
    text: widget.controller.logicalSize.width.toStringAsFixed(0),
  );
  late final TextEditingController _h = TextEditingController(
    text: widget.controller.logicalSize.height.toStringAsFixed(0),
  );
  final FocusNode _wFocus = FocusNode();
  final FocusNode _hFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_follow);
  }

  @override
  void didUpdateWidget(_FreeformControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_follow);
      widget.controller.addListener(_follow);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_follow);
    _w.dispose();
    _h.dispose();
    _wFocus.dispose();
    _hFocus.dispose();
    super.dispose();
  }

  void _follow() {
    if (_wFocus.hasFocus || _hFocus.hasFocus) return;
    final size = widget.controller.logicalSize;
    final width = size.width.toStringAsFixed(0);
    final height = size.height.toStringAsFixed(0);
    if (_w.text != width) _w.text = width;
    if (_h.text != height) _h.text = height;
  }

  void _apply() {
    final w = double.tryParse(_w.text);
    final h = double.tryParse(_h.text);
    if (w == null || h == null) return;
    widget.controller.setFreeformSize(Size(w, h));
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _w,
                  focusNode: _wFocus,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Width',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _h,
                  focusNode: _hFocus,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _apply,
                  child: const Text('Apply'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.controller.isFreeform
                      ? () => widget.controller.setFreeformSize(null)
                      : null,
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      );
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    super.key,
    required this.device,
    required this.selected,
    required this.onTap,
  });

  final DeviceSpec device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final screen = device.primaryScreen;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      selected: selected,
      leading: Icon(
        switch (device.category) {
          DeviceCategory.phone => Icons.smartphone,
          DeviceCategory.foldable => Icons.book_outlined,
          DeviceCategory.tablet => Icons.tablet_mac,
          DeviceCategory.desktop => Icons.desktop_windows,
          DeviceCategory.watch => Icons.watch,
          DeviceCategory.tv => Icons.tv,
        },
        size: 18,
      ),
      title: Text(device.name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        '${screen.logicalSize.width.toStringAsFixed(0)}×'
        '${screen.logicalSize.height.toStringAsFixed(0)} @${screen.pixelRatio}x',
        style: const TextStyle(fontSize: 11),
      ),
      onTap: onTap,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        avatar: icon == null ? null : Icon(icon, size: 16),
        selected: selected,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: onTap == null ? null : (_) => onTap!(),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: onChanged,
      );
}
