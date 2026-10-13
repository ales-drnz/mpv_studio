import 'package:flutter/material.dart';

/// Top-level navigable sections. The desktop sidebar lists them all; the
/// mobile tab bar shows the [tab] ones and keeps the rest in its More
/// menu. Only the shell chrome differs.
enum Section {
  nowPlaying('Playback', 'Play', Icons.play_circle_outline_rounded, '/',
      tab: true),
  queue('Queue', 'Queue', Icons.queue_music_rounded, '/queue', tab: true),
  stream('Stream', 'Stream', Icons.podcasts_rounded, '/stream', tab: true),
  effects('Effects', 'FX', Icons.graphic_eq_rounded, '/effects', tab: true),
  engine('Engine', 'Engine', Icons.monitor_heart_outlined, '/engine'),
  settings('Settings', 'Settings', Icons.tune_rounded, '/settings'),
  console('Console', 'Console', Icons.terminal_rounded, '/console');

  const Section(
    this.title,
    this.shortLabel,
    this.icon,
    this.path, {
    this.tab = false,
  });

  /// Full title used in the desktop sidebar and page headers.
  final String title;

  /// Compact label used under mobile tab-bar icons and in the More menu.
  final String shortLabel;

  final IconData icon;

  /// Route location for this section's branch in the app [GoRouter]. The
  /// enum's declaration order also fixes each branch's index, so it must
  /// match the router's branch order.
  final String path;

  /// Whether the section has its own tab on mobile; the others live in
  /// the More menu.
  final bool tab;

  /// The sections with a mobile tab, in order.
  static List<Section> get tabs => [
        for (final s in values)
          if (s.tab) s,
      ];

  /// The sections in the mobile More menu, in order.
  static List<Section> get more => [
        for (final s in values)
          if (!s.tab) s,
      ];
}
