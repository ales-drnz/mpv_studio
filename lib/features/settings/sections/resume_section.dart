import 'package:flutter/material.dart';

import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../setting_anchor.dart';
import '../settings_catalog.dart';
import '../settings_scope.dart';
import 'anchored_rows.dart';
import 'pickers.dart';

/// Resume playback: the policy and its folder (read when the player is
/// created, so a change shows the restart banner), and saving or clearing
/// the resume point of the current file.
class ResumeSection extends StatelessWidget {
  const ResumeSection({super.key});

  /// Runs a resume point [action] and says how it went.
  static Future<void> _act(
    BuildContext context,
    Future<void> Function() action,
    String done,
  ) async {
    final ok = await SettingsScope.of(context).guard(() async {
      await action();
      return true;
    });
    if (ok == true && context.mounted) showSettingsMessage(context, done);
  }

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final settings = scope.settings;
    final p = scope.player;
    return ListenableBuilder(
      listenable: settings.changes,
      builder: (context, _) => SettingsGroup(
        label: SettingsSections.resume,
        children: [
          SettingAnchor(
            entry: SettingsCatalog.resume,
            child: SwitchRow(
              label: SettingsCatalog.resume.title,
              subtitle: SettingsCatalog.resume.description,
              value: settings.resumePlayback,
              onChanged: settings.recordResumePlayback,
            ),
          ),
          anchoredPath(
            SettingsCatalog.resumeFolder,
            path: settings.watchLaterDir,
            unset: 'The engine default, often not writable on mobile.',
            pick: pickFolder,
            onChanged: settings.recordWatchLaterDir,
          ),
          SettingAnchor(
            entry: SettingsCatalog.saveResume,
            child: SettingTile(
              title: SettingsCatalog.saveResume.title,
              description: SettingsCatalog.saveResume.description,
              trailing: TileButton(
                label: 'Save',
                accent: true,
                tooltip: 'Save the resume point of the current file',
                onPressed: () =>
                    _act(context, p.writeResumeConfig, 'Resume point saved'),
              ),
            ),
          ),
          SettingAnchor(
            entry: SettingsCatalog.clearResume,
            child: SettingTile(
              title: SettingsCatalog.clearResume.title,
              description: SettingsCatalog.clearResume.description,
              trailing: TileButton(
                label: 'Clear',
                tooltip: 'Clear the resume point of the current file',
                onPressed: () =>
                    _act(context, p.deleteResumeConfig, 'Resume point cleared'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
