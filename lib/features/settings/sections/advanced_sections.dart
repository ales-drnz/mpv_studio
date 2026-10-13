import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../setting_anchor.dart';
import '../settings_catalog.dart';
import '../../../studio/app_settings.dart';
import '../settings_scope.dart';
import 'anchored_rows.dart';

/// How much of the engine log reaches the Console.
class LoggingSection extends StatelessWidget {
  const LoggingSection({super.key});

  static const _levels = <(LogLevel, String)>[
    (LogLevel.off, 'Off'),
    (LogLevel.fatal, 'Fatal errors'),
    (LogLevel.error, 'Errors'),
    (LogLevel.warn, 'Warnings'),
    (LogLevel.info, 'Information'),
    (LogLevel.v, 'Verbose'),
    (LogLevel.debug, 'Debug'),
    (LogLevel.trace, 'Trace'),
  ];

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final settings = scope.settings;
    return ListenableBuilder(
      listenable: settings.changes,
      builder: (context, _) => SettingsGroup(
        label: SettingsSections.logging,
        children: [
          anchoredDropdown<LogLevel>(
            scope,
            SettingsCatalog.logLevel,
            value: settings.logLevel,
            items: [
              for (final (level, label) in _levels)
                DropdownMenuItem(value: level, child: Text(label)),
            ],
            set: (level) async {
              scope.player.setLogLevel(level);
              settings.recordLogLevel(level);
            },
          ),
        ],
      ),
    );
  }
}

/// Raw mpv options applied on every launch, one `name=value` per line.
class EngineOptionsSection extends StatefulWidget {
  const EngineOptionsSection({super.key});

  /// The options in [text]: one `name=value` per line, blank lines and
  /// lines starting with `#` skipped. Returns the bad lines in [errors].
  static List<(String, String)> parse(String text, List<String> errors) {
    final out = <(String, String)>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) {
        errors.add(line);
        continue;
      }
      out.add((line.substring(0, eq).trim(), line.substring(eq + 1).trim()));
    }
    return out;
  }

  static String format(List<(String, String)> options) =>
      [for (final (name, value) in options) '$name=$value'].join('\n');

  @override
  State<EngineOptionsSection> createState() => _EngineOptionsSectionState();
}

class _EngineOptionsSectionState extends State<EngineOptionsSection> {
  final _text = TextEditingController();
  AppSettings? _loadedFrom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A new scope brings its own settings: show their options.
    final settings = SettingsScope.of(context).settings;
    if (identical(settings, _loadedFrom)) return;
    _loadedFrom = settings;
    _text.text = EngineOptionsSection.format(settings.rawOptions);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final scope = SettingsScope.of(context);
    final errors = <String>[];
    final options = EngineOptionsSection.parse(_text.text, errors);
    if (errors.isNotEmpty) {
      showSettingsMessage(
        context,
        'Not a name=value line: ${errors.first}. Nothing was applied.',
      );
      return;
    }
    scope.settings.recordRawOptions(options);
    var refused = 0;
    for (final (name, value) in options) {
      final ok = await scope.guard(() async {
        await scope.player.setRawProperty(name, value);
        return true;
      });
      if (ok != true) refused++;
    }
    if (!mounted) return;
    showSettingsMessage(
      context,
      refused == 0
          ? 'Applied ${options.length} engine options. They apply on every '
                'launch.'
          : 'Saved; the engine refused $refused of ${options.length} '
                'options.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = SettingsCatalog.rawOptions;
    return SettingsGroup(
      label: SettingsSections.engineOptions,
      children: [
        SettingAnchor(
          entry: entry,
          child: SettingTile(
            title: entry.title,
            description: entry.description,
            below: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.s12,
                    vertical: Tokens.s8,
                  ),
                  decoration: ShapeDecoration(
                    color: Tokens.surface3,
                    shape: Tokens.shape(Tokens.rMd),
                  ),
                  child: TextField(
                    controller: _text,
                    minLines: 3,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    style: Tokens.body.copyWith(fontFamily: Tokens.mono),
                    cursorColor: Tokens.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'demuxer-lavf-probesize=1048576',
                      hintStyle: Tokens.caption,
                    ),
                  ),
                ),
                const SizedBox(height: Tokens.s8),
                TileButton(
                  label: 'Apply',
                  accent: true,
                  tooltip: 'Apply and keep the engine options',
                  onPressed: _apply,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Restarting the player, the welcome screen and resetting everything.
class PlayerSection extends StatelessWidget {
  const PlayerSection({super.key});

  static Future<void> _reset(BuildContext context, SettingsScope scope) async {
    final confirmed = await showStudioDialog<bool>(
      context,
      title: 'Reset all settings?',
      builder: (context) => Text(
        'Every engine, effect and network setting goes back to its default '
        'and the player restarts. The theme is kept.',
        style: Tokens.body,
      ),
      actions: (context) => [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Tokens.red),
          child: const Text('Reset'),
        ),
      ],
    );
    if (confirmed != true) return;
    await scope.settings.resetToDefaults();
    final restart = scope.restart;
    if (restart != null) {
      await restart();
    } else if (context.mounted) {
      showSettingsMessage(context, 'Settings reset. Restart the app.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final restart = scope.restart;
    final welcome = scope.showWelcome;
    return SettingsGroup(
      label: SettingsSections.player,
      children: [
        SettingAnchor(
          entry: SettingsCatalog.restartPlayer,
          child: SettingTile(
            title: SettingsCatalog.restartPlayer.title,
            description: SettingsCatalog.restartPlayer.description,
            enabled: restart != null,
            trailing: TileButton(
              label: 'Restart',
              tooltip: 'Restart the player',
              onPressed: restart == null ? null : () => unawaited(restart()),
            ),
          ),
        ),
        SettingAnchor(
          entry: SettingsCatalog.welcome,
          child: SettingTile(
            title: SettingsCatalog.welcome.title,
            description: SettingsCatalog.welcome.description,
            enabled: welcome != null,
            trailing: TileButton(
              label: 'Show',
              tooltip: 'Show the welcome screen',
              onPressed: welcome == null ? null : () => welcome(context),
            ),
          ),
        ),
        SettingAnchor(
          entry: SettingsCatalog.reset,
          child: SettingTile(
            title: SettingsCatalog.reset.title,
            description: SettingsCatalog.reset.description,
            trailing: TileButton(
              label: 'Reset',
              tooltip: 'Reset all settings',
              onPressed: () => _reset(context, scope),
            ),
          ),
        ),
      ],
    );
  }
}

/// The app and engine versions.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SettingsScope.of(context).player.state;
    String or(String v) => v.isEmpty ? '-' : v;
    return SettingsGroup(
      label: SettingsSections.about,
      children: [
        SettingAnchor(
          entry: SettingsCatalog.about,
          child: const InfoRow(label: 'App', value: 'MPV Studio'),
        ),
        InfoRow(label: 'Engine', value: or(state.mpvVersion)),
        InfoRow(label: 'FFmpeg', value: or(state.ffmpegVersion)),
      ],
    );
  }
}
