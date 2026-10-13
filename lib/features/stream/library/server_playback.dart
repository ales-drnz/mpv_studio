import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../favorites_controller.dart';
import '../media_server.dart';
import '../stream_actions.dart';
import 'track_rows.dart';

/// Plays a server's tracks with the picked [StreamOptions]: what the song
/// list and the album detail call when a row is tapped or its menu used.
class ServerPlayback {
  const ServerPlayback({
    required this.server,
    required this.actions,
    required this.favorites,
    required this.options,
  });

  final MediaServer server;
  final StreamActions actions;
  final FavoritesController favorites;
  final StreamOptions options;

  /// How many tracks a tap queues, from the tapped one on.
  static const queueWindow = 100;

  List<Media> _medias(Iterable<ServerTrack> tracks) => [
    for (final t in tracks)
      serverMedia(
        server,
        t,
        options,
        isFavorite: favorites.resolved(server.kind, t.id, t.isFavorite),
      ),
  ];

  /// Replaces the queue with up to [queueWindow] of [tracks] starting at
  /// [index], and plays the first.
  Future<void> playFrom(List<ServerTrack> tracks, int index) {
    if (index < 0 || index >= tracks.length) return Future.value();
    final end = math.min(index + queueWindow, tracks.length);
    return actions.playAll(_medias(tracks.sublist(index, end)));
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
            messenger?.showSnackBar(
              SnackBar(
                content: Text(
                  '${server.name} did not save the favorite for '
                  '"${t.title}".',
                ),
              ),
            );
          }
        }
      default:
        await actions.run(action, _medias(tracks));
    }
  }
}
