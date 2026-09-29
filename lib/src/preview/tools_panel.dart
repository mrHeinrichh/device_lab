import 'package:flutter/material.dart';

import '../catalog/device_catalog.dart';
import '../model/device_spec.dart';
import 'device_lab_controller.dart';

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

class _ToolsPanelState extends State<ToolsPanel> {
  String _query = '';

  DeviceLabController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final results = DeviceCatalog.search(_query);
    final grouped = <DeviceCategory, List<DeviceSpec>>{};
    for (final d in results) {
      grouped.putIfAbsent(d.category, () => []).add(d);
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Device Lab',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              IconButton(
                tooltip: 'Hide options',
                icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                onPressed: () => c.setToolsVisible(false),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Search devices',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          _ViewportSummary(controller: c),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.fullscreen, size: 18),
              label: const Text('Show original screen'),
              onPressed: () => c.setPreviewing(false),
            ),
          ),
          _Section(
            title: 'Layout',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                  ],
                ),
                if (c.canFold) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
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
                    ],
                  ),
                ],
              ],
            ),
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
          if (widget.availableLocales.length > 1)
            _Section(
              title: 'Locale',
              child: DropdownButton<Locale>(
                isExpanded: true,
                value: c.locale ?? widget.availableLocales.first,
                items: [
                  for (final l in widget.availableLocales)
                    DropdownMenuItem(value: l, child: Text(l.toLanguageTag())),
                ],
                onChanged: c.setLocale,
              ),
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
                      device: d,
                      selected: c.device.id == d.id && !c.isFreeform,
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

class _ViewportSummary extends StatelessWidget {
  const _ViewportSummary({required this.controller});

  final DeviceLabController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.logicalSize;
    final screen = controller.screen;
    final px = Size(
      size.width * screen.pixelRatio,
      size.height * screen.pixelRatio,
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.isFreeform ? 'Custom viewport' : controller.device.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${size.width.toStringAsFixed(0)} × ${size.height.toStringAsFixed(0)} dp'
            '   ·   @${screen.pixelRatio}x',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '${px.width.toStringAsFixed(0)} × ${px.height.toStringAsFixed(0)} px',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ],
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

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    super.dispose();
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
