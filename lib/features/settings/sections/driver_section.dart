import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';
import '../setting_anchor.dart';
import '../settings_catalog.dart';
import '../settings_scope.dart';
import 'anchored_rows.dart';

/// The output driver (`ao`) and its fallbacks. The driver list is found
/// the mpv way: writing `ao=help` prints the available drivers to the log,
/// which is read once.
class DriverSection extends StatefulWidget {
  const DriverSection({super.key});

  @override
  State<DriverSection> createState() => _DriverSectionState();
}

class _DriverSectionState extends State<DriverSection> {
  /// The automatic choice, shown first; mpv takes it as an empty driver.
  static const _auto = 'auto';
  List<String> _drivers = const [_auto];
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    unawaited(_loadDrivers());
  }

  Future<void> _loadDrivers() async {
    final p = SettingsScope.of(context).player;
    final collected = <String>[];
    var collecting = false;
    final sub = p.stream.log.listen((entry) {
      final text = entry.text.trim();
      if (text.contains('Available audio outputs')) {
        collecting = true;
        return;
      }
      if (collecting && text.isNotEmpty) {
        final name = text.split(RegExp(r'\s+')).first;
        if (name.isNotEmpty) collected.add(name);
      }
    });
    // `ao=help` lists the drivers as a log side effect, then rejects the
    // write itself: the listing has arrived by then.
    try {
      await p.setRawProperty('ao', 'help');
    } on PlayerException {
      // Expected.
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();
    if (collected.isNotEmpty && mounted) {
      setState(() => _drivers = [_auto, ...collected]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    return SettingsGroup(
      label: SettingsSections.driver,
      children: [
        Live<String>(
          stream: p.stream.audioDriver,
          initial: p.state.audioDriver,
          builder: (context, raw) {
            final value = raw.isEmpty ? _auto : raw;
            return anchoredDropdown<String>(
              scope,
              SettingsCatalog.driver,
              value: value,
              items: [
                for (final d in {..._drivers, value})
                  DropdownMenuItem(
                    value: d,
                    child: Text(d == _auto ? 'Automatic' : d),
                  ),
              ],
              set: (d) => p.setAudioDriver(d == _auto ? '' : d),
            );
          },
        ),
        Live<bool>(
          stream: p.stream.audioNullUntimed,
          initial: p.state.audioNullUntimed,
          builder: (context, v) => anchoredSwitch(
            scope,
            SettingsCatalog.nullFallback,
            value: v,
            set: p.setAudioNullUntimed,
          ),
        ),
        Live<bool>(
          stream: p.stream.audioStreamSilence,
          initial: p.state.audioStreamSilence,
          builder: (context, v) => anchoredSwitch(
            scope,
            SettingsCatalog.streamSilence,
            value: v,
            set: p.setAudioStreamSilence,
          ),
        ),
        SettingAnchor(
          entry: SettingsCatalog.reloadOutput,
          child: SettingTile(
            title: SettingsCatalog.reloadOutput.title,
            description: SettingsCatalog.reloadOutput.description,
            trailing: TileButton(
              label: 'Reload',
              tooltip: 'Reload the audio output',
              onPressed: () => scope.run(p.reloadAudio),
            ),
          ),
        ),
      ],
    );
  }
}

/// S/PDIF passthrough and the name the OS mixer shows.
class PassthroughSection extends StatelessWidget {
  const PassthroughSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    return SettingsGroup(
      label: SettingsSections.passthrough,
      children: [
        Live<Set<Spdif>>(
          stream: p.stream.audioSpdif,
          initial: p.state.audioSpdif,
          builder: (context, selected) => SettingAnchor(
            entry: SettingsCatalog.spdif,
            child: SettingTile(
              title: SettingsCatalog.spdif.title,
              description: SettingsCatalog.spdif.description,
              // mpv treats the set as an allow list; an empty set turns
              // passthrough off.
              below: Wrap(
                spacing: Tokens.s8,
                runSpacing: Tokens.s8,
                children: [
                  for (final c in Spdif.values)
                    _CodecChip(
                      label: c.mpvValue,
                      active: selected.contains(c),
                      onTap: () => scope.run(
                        () => p.setAudioSpdif(
                          selected.contains(c)
                              ? ({...selected}..remove(c))
                              : {...selected, c},
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Live<String>(
          stream: p.stream.audioClientName,
          initial: p.state.audioClientName,
          builder: (context, v) => SettingAnchor(
            entry: SettingsCatalog.clientName,
            child: TextRow(
              label: SettingsCatalog.clientName.title,
              description:
                  '${SettingsCatalog.clientName.description}. '
                  'Press Enter to apply.',
              value: v,
              hint: 'mpv_studio',
              monospace: false,
              onSubmitted: (name) =>
                  scope.run(() => p.setAudioClientName(name)),
            ),
          ),
        ),
      ],
    );
  }
}

/// A toggle chip of the passthrough codec set.
class _CodecChip extends StatelessWidget {
  const _CodecChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.pill,
          child: Ink(
            height: context.layout.minTap,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
            decoration: ShapeDecoration(
              color: active ? Tokens.accentContainer : Tokens.surface3,
              shape: Tokens.pill,
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: Tokens.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: active ? Tokens.onAccentContainer : Tokens.fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
