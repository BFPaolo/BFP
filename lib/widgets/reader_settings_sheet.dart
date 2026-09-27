import 'package:flutter/material.dart';

import '../models/reader_settings.dart';

/// Pannello impostazioni di lettura. Chiama [onChanged] ad ogni modifica.
class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({super.key, required this.settings, required this.onChanged, this.showTextOptions = true});

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  /// `false` per i PDF (solo tema).
  final bool showTextOptions;

  static Future<void> show(
    BuildContext context, {
    required ReaderSettings settings,
    required ValueChanged<ReaderSettings> onChanged,
    bool showTextOptions = true,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ReaderSettingsSheet(settings: settings, onChanged: onChanged, showTextOptions: showTextOptions),
  );

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late ReaderSettings _s = widget.settings;

  void _set(ReaderSettings s) {
    setState(() => _s = s);
    widget.onChanged(s);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tema', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final t in ReaderThemeMode.values)
                  _ThemeSwatch(
                    mode: t,
                    selected: _s.theme == t,
                    onTap: () => _set(_s.copyWith(theme: t)),
                  ),
              ],
            ),
            if (widget.showTextOptions) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Dimensione testo', style: text.titleSmall),
                  const Spacer(),
                  IconButton.outlined(
                    tooltip: 'Riduci',
                    icon: const Icon(Icons.text_decrease),
                    onPressed: _s.fontSize > 10 ? () => _set(_s.copyWith(fontSize: _s.fontSize - 1)) : null,
                  ),
                  SizedBox(
                    width: 44,
                    child: Center(child: Text('${_s.fontSize}', style: text.titleMedium)),
                  ),
                  IconButton.outlined(
                    tooltip: 'Aumenta',
                    icon: const Icon(Icons.text_increase),
                    onPressed: _s.fontSize < 40 ? () => _set(_s.copyWith(fontSize: _s.fontSize + 1)) : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Interlinea', style: text.titleSmall),
              Slider(
                value: _s.lineHeight,
                min: 1.0,
                max: 2.2,
                divisions: 12,
                label: _s.lineHeight.toStringAsFixed(1),
                onChanged: (v) => setState(() => _s = _s.copyWith(lineHeight: v)),
                onChangeEnd: (v) => _set(_s.copyWith(lineHeight: v)),
              ),
              Text('Carattere', style: text.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<ReaderFontFamily>(
                showSelectedIcon: false,
                segments: [for (final f in ReaderFontFamily.values) ButtonSegment(value: f, label: Text(f.label))],
                selected: {_s.fontFamily},
                onSelectionChanged: (v) => _set(_s.copyWith(fontFamily: v.first)),
              ),
              const SizedBox(height: 20),
              Text('Modalità di lettura', style: text.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.auto_stories_outlined), label: Text('Pagine')),
                  ButtonSegment(value: true, icon: Icon(Icons.swap_vert), label: Text('Scorrimento')),
                ],
                selected: {_s.scrolled},
                onSelectionChanged: (v) => _set(_s.copyWith(scrolled: v.first)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.mode, required this.selected, required this.onTap});

  final ReaderThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: mode.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? primary : Colors.grey.shade400, width: selected ? 2.5 : 1),
        ),
        child: Column(
          children: [
            Text(
              'Aa',
              style: TextStyle(color: mode.foreground, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Text(
              mode.label,
              style: TextStyle(color: mode.foreground, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
