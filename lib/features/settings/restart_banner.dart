import 'package:flutter/material.dart';

import '../../studio/app_settings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/inline_notice.dart';
import 'settings_scope.dart';

/// Shown while a setting the player reads only when it is created
/// ([RestartSetting]) differs from the running player: names them and
/// offers to restart the player now. Nothing otherwise.
class RestartBanner extends StatelessWidget {
  const RestartBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    return ListenableBuilder(
      listenable: scope.settings.changes,
      builder: (context, _) {
        final pending = RestartSetting.pending(
          scope.settings,
          scope.player.configuration,
        );
        if (pending.isEmpty) return const SizedBox.shrink();
        final names = [for (final s in pending) s.label].join(', ');
        final restart = scope.restart;
        return Padding(
          padding: const EdgeInsets.only(bottom: Tokens.s12),
          child: InlineNotice(
            tone: NoticeTone.warning,
            icon: Icons.restart_alt_rounded,
            text: 'Applies after a player restart: $names.',
            action: TextButton(
              onPressed: restart,
              child: const Text('Restart player'),
            ),
          ),
        );
      },
    );
  }
}
