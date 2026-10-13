import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/app_settings.dart';
import '../../studio/loudness_normalizer.dart';
import '../../studio/playback_issues.dart';
import '../../studio/player_scope.dart';

/// What the Settings page works on: the player, the persisted settings, the
/// normalizer, the guard every player call runs through and the player
/// restart. The page installs one from [PlayerScope]; tests install one
/// with fakes above the page.
class SettingsScope extends InheritedWidget {
  const SettingsScope({
    super.key,
    required this.player,
    required this.settings,
    required this.normalizer,
    required this.guard,
    this.restart,
    this.showWelcome,
    required super.child,
  });

  final PlayerApi player;
  final AppSettings settings;
  final LoudnessNormalizer normalizer;

  /// Runs a player call so what it throws becomes a notice.
  final CallGuard guard;

  /// Restarts the player with the current settings; null when it can't.
  final Future<void> Function()? restart;

  /// Opens the welcome screen again; null when it can't.
  final void Function(BuildContext context)? showWelcome;

  /// Runs [call] through [guard] without waiting: for a control's
  /// callback, where the outcome shows through the player's streams.
  void run(FutureOr<void> Function() call) => unawaited(guard(call));

  static SettingsScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope above this context');
    return scope!;
  }

  static SettingsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>();

  /// Installs a scope over [child] made from the app's [PlayerScope],
  /// unless one is already above (a test's).
  static Widget fromApp({
    required BuildContext context,
    required void Function(BuildContext context) showWelcome,
    required Widget child,
  }) {
    if (maybeOf(context) != null) return child;
    return SettingsScope(
      player: PlayerScope.of(context),
      settings: PlayerScope.settingsOf(context),
      normalizer: PlayerScope.normalizerOf(context),
      guard: PlayerScope.issuesOf(context).guard,
      restart: PlayerScope.restartOf(context),
      showWelcome: showWelcome,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(SettingsScope old) =>
      old.player != player ||
      old.settings != settings ||
      old.normalizer != normalizer ||
      old.restart != restart;
}
