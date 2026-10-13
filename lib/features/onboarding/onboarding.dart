import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../shell/sections.dart';
import '../../studio/app_settings.dart';
import '../../studio/playback_issues.dart';
import '../../studio/player_scope.dart';
import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../util/media_import.dart';

/// The public stream the welcome screen offers as a demo: the Lab's MP3
/// reference stream, a stable HTTPS radio that plays on every platform.
const demoStream = Media(
  'https://streams.radiomast.io/ref-128k-mp3-stereo',
  extras: {'title': 'Demo stream', 'artist': 'Radiomast reference, MP3 128k'},
);

/// The Stream tab each server choice opens, passed as the `tab` query of
/// the Stream route (`/stream?tab=jellyfin`).
enum ServerChoice {
  jellyfin('Jellyfin'),
  plex('Plex'),
  samba('Samba');

  const ServerChoice(this.label);
  final String label;

  /// The Stream route that opens this choice's tab.
  String get location => '${Section.stream.path}?tab=$name';
}

/// What the welcome screen's choices act on: the player, the guard its
/// calls run through, and the file picker.
class OnboardingActions {
  const OnboardingActions({
    required this.player,
    required this.guard,
    this.pickFiles = pickAudioFiles,
  });

  /// The actions on the app's player ([PlayerScope]).
  factory OnboardingActions.of(BuildContext context) => OnboardingActions(
    player: PlayerScope.of(context),
    guard: PlayerScope.issuesOf(context).guard,
  );

  final PlayerApi player;
  final CallGuard guard;

  /// Asks for audio files, as the Queue's Add files does.
  final Future<List<String>> Function() pickFiles;

  /// Queues [paths] as the Queue does: they become the queue and play when
  /// it is empty, and are appended otherwise.
  Future<void> enqueue(List<String> paths) => guard(() async {
    final medias = [
      for (final p in paths) Media(p, extras: {'title': baseNameNoExt(p)}),
    ];
    if (player.state.playlist.items.isEmpty) {
      await player.openAll(medias, play: true);
    } else {
      for (final m in medias) {
        await player.add(m);
      }
    }
  });

  Future<void> playDemo() => guard(() => player.open(demoStream, play: true));
}

/// Opens the welcome screen on the app's player and records it as seen
/// in the settings. Settings uses it to show the screen again.
Future<void> showOnboarding(BuildContext context) {
  final settings = PlayerScope.settingsOf(context);
  return presentOnboarding(
    context,
    actions: OnboardingActions.of(context),
    onSeen: () => settings.recordOnboarded(true),
  );
}

/// Opens the welcome screen when [settings] says it was never seen.
Future<void> welcomeOnFirstLaunch(
  BuildContext context,
  AppSettings settings,
  OnboardingActions actions,
) async {
  if (settings.onboarded) return;
  await presentOnboarding(
    context,
    actions: actions,
    onSeen: () => settings.recordOnboarded(true),
  );
}

/// Opens the welcome screen over the whole app: full screen on a phone, a
/// centred card on larger windows. Whatever closes it (a choice, Skip,
/// Escape, Android back, a tap outside the card) calls [onSeen], so it
/// opens by itself only on the first launch.
Future<void> presentOnboarding(
  BuildContext context, {
  required OnboardingActions actions,
  required VoidCallback onSeen,
}) async {
  final layout = context.layout;
  final card = !layout.isCompact && !layout.isShort;
  final navigator = Navigator.of(context, rootNavigator: true);
  await navigator.push<void>(
    PageRouteBuilder<void>(
      opaque: !card,
      barrierDismissible: card,
      barrierColor: card ? Tokens.bg.withValues(alpha: 0.7) : null,
      barrierLabel: 'Close the welcome screen',
      settings: const RouteSettings(name: 'onboarding'),
      pageBuilder: (context, _, _) =>
          OnboardingView(card: card, actions: actions),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
  onSeen();
}

/// The welcome screen: three ways to start (open files, a demo stream, a
/// media server) and Skip. [card] lays it out as a centred card instead
/// of a full screen page.
class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key, required this.card, required this.actions});

  final bool card;
  final OnboardingActions actions;

  /// The widest the welcome content gets, as a card and as a page: the
  /// width of the app's dialogs (`showStudioDialog`).
  static const maxWidth = 520.0;

  /// Closes the welcome screen, then goes to [location] if given. False,
  /// doing nothing, when the screen is already closing (a second tap or
  /// key during its fade out), so the route below is never popped.
  static bool _finish(BuildContext context, [String? location]) {
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return false;
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).pop();
    if (location != null) router?.go(location);
    return true;
  }

  Future<void> _openFiles(BuildContext context) async {
    final paths = await actions.pickFiles();
    if (paths.isEmpty || !context.mounted) return;
    if (_finish(context, Section.queue.path)) await actions.enqueue(paths);
  }

  Future<void> _playDemo(BuildContext context) async {
    if (_finish(context, Section.nowPlaying.path)) await actions.playDemo();
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Welcome to MPV Studio', style: Tokens.title),
        ),
        const SizedBox(height: Tokens.s8),
        Text(
          'A player and a lab for the mpv engine. Pick a way to start; '
          'Settings can open this screen again.',
          style: Tokens.body.copyWith(color: Tokens.fgDim),
        ),
        const SizedBox(height: Tokens.s20),
        _Choice(
          icon: Icons.library_music_outlined,
          title: 'Open audio files',
          description: 'Pick files on this device to fill the queue.',
          autofocus: true,
          onTap: () => unawaited(_openFiles(context)),
        ),
        const SizedBox(height: Tokens.s12),
        _Choice(
          icon: Icons.radio_outlined,
          title: 'Try a demo stream',
          description: 'Play a public internet radio stream right away.',
          onTap: () => unawaited(_playDemo(context)),
        ),
        const SizedBox(height: Tokens.s12),
        _Choice(
          icon: Icons.dns_outlined,
          title: 'Connect a server',
          description: 'Browse a Jellyfin, Plex or Samba music library.',
          onTap: () => _finish(context, ServerChoice.jellyfin.location),
          footer: Wrap(
            spacing: Tokens.s8,
            runSpacing: Tokens.s8,
            children: [
              for (final s in ServerChoice.values)
                OutlinedButton(
                  onPressed: () => _finish(context, s.location),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(layout.minTap, layout.minTap),
                    foregroundColor: Tokens.fg,
                    side: BorderSide(color: Tokens.line2),
                    shape: Tokens.shape(Tokens.rSm) as OutlinedBorder,
                  ),
                  child: Text(s.label),
                ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.s20),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _finish(context),
            style: TextButton.styleFrom(
              minimumSize: Size(layout.minTap, layout.minTap),
              foregroundColor: Tokens.fgDim,
            ),
            child: const Text('Skip'),
          ),
        ),
      ],
    );

    final Widget body = card
        ? Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Tokens.s24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Material(
                  color: Tokens.surface,
                  shape: Tokens.shape(Tokens.rLg),
                  child: Padding(
                    padding: const EdgeInsets.all(Tokens.s24),
                    child: content,
                  ),
                ),
              ),
            ),
          )
        : Material(
            color: Tokens.bg,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: layout.pagePadding.copyWith(top: Tokens.s24),
                child: ReadableWidth(maxWidth: maxWidth, child: content),
              ),
            ),
          );

    // Escape closes it like Skip, on the card and on the full page.
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _finish(context);
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(child: body),
      ),
    );
  }
}

/// One way to start: a large tappable card with an icon, a title and a
/// line of text, and an optional [footer] of finer choices.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.footer,
    this.autofocus = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Widget? footer;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.surface2,
      shape: Tokens.shape(Tokens.rMd),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              autofocus: autofocus,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: context.layout.minTap),
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.s16),
                  child: Row(
                    children: [
                      Icon(icon, size: 26, color: Tokens.accent),
                      const SizedBox(width: Tokens.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: Tokens.heading),
                            const SizedBox(height: 2),
                            Text(
                              description,
                              style: Tokens.label.copyWith(color: Tokens.fgDim),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Tokens.fgFaint),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.s16 + 26 + Tokens.s16,
                0,
                Tokens.s16,
                Tokens.s16,
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}
