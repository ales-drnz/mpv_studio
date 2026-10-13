import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../favorites_controller.dart';
import '../media_server.dart';
import '../stream_actions.dart';
import 'track_rows.dart';
import '../../../ui/widgets/studio_snack.dart';

/// Plays a server's tracks with the picked [StreamOptions]: what the song
/// list and the album detail call when a row is tapped or its menu used.
class ServerPlayback {
  const ServerPlayback({
    required this.server,
    required this.actions,
    required this.favorites,
    required this.options,
    required this.onFailure,
  });

  final MediaServer server;
  final StreamActions actions;
  final FavoritesController favorites;
  final StreamOptions options;

  /// Gets what stopped the queue entries from being built (no session,
  /// most often); nothing reaches the player then.
  final ValueChanged<Object> onFailure;

  /// How many tracks a tap queues, from the tapped one on.
  static const queueWindow = 100;

  /// The queue entries for [tracks], or null (after [onFailure]) when the
  /// server cannot build them.
  List<Media>? _medias(Iterable<ServerTrack> tracks) {
    try {
      return [
        for (final t in tracks)
          serverMedia(
            server,
            t,
            options,
            isFavorite: favorites.resolved(server.kind, t.id, t.isFavorite),
          ),
      ];
    } catch (e) {
      onFailure(e);
      return null;
    }
  }

  /// Replaces the queue with up to [queueWindow] of [tracks] starting at
  /// [index], and plays the first.
  Future<void> playFrom(List<ServerTrack> tracks, int index) {
    if (index < 0 || index >= tracks.length) return Future.value();
    final end = math.min(index + queueWindow, tracks.length);
    final medias = _medias(tracks.sublist(index, end));
    return medias == null ? Future.value() : actions.playAll(medias);
  }

  /// Runs [action] on [tracks] from a row's menu or star. A favourite the
  /// server refuses is undone and reported under [context].
  Future<void> run(
    BuildContext context,
    RowAction action,
    List<ServerTrack> tracks,
  ) async {
    switch (action) {
      case RowAction.favorite || RowAction.unfavorite:
        final messenger = ScaffoldMessenger.maybeOf(context);
        final value = action == RowAction.favorite;
        for (final t in tracks) {
          final ok = await favorites.setFavorite(server.kind, t.id, value);
          if (!ok) {
            messenger?.showStudioSnack(
              '${server.name} did not save the favorite for "${t.title}".',
              replace: false,
            );
          }
        }
      default:
        final medias = _medias(tracks);
        if (medias != null) await actions.run(action, medias);
    }
  }
}
