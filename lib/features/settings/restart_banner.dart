import 'package:flutter/material.dart';

import '../../studio/app_settings.dart';
import '../../ui/tokens.dart';
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
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Material(
              color: Tokens.amber.withValues(alpha: 0.16),
              shape: Tokens.shape(Tokens.rMd),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.s16,
                  Tokens.s12,
                  Tokens.s12,
                  Tokens.s12,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Tokens.s12,
                  runSpacing: Tokens.s8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restart_alt_rounded,
                          size: 20,
                          color: Tokens.amber,
                        ),
                        const SizedBox(width: Tokens.s12),
                        Flexible(
                          child: Text(
                            'Applies after a player restart: $names.',
                            style: Tokens.body,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: restart,
                      child: const Text('Restart player'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
