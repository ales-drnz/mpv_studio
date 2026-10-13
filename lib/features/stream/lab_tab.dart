import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/custom_url_bar.dart';
import 'http_options.dart';
import 'stream_actions.dart';
import 'stream_catalog.dart';
import 'widgets/http_options_panel.dart';
import 'widgets/reference_list.dart';

/// The Lab tab: a URL entry with per-media HTTP options over the curated
/// reference streams. No chunking by default: these are fast, trusted
/// servers where one open-ended request buffers fastest.
class LabTab extends StatelessWidget {
  const LabTab({
    super.key,
    required this.actions,
    this.hasGlobalUserAgent = _none,
  });

  final StreamActions actions;

  /// Whether Settings, Network sets a user agent for every stream.
  final bool Function() hasGlobalUserAgent;

  static bool _none() => false;

  @override
  Widget build(BuildContext context) {
    return PlaylistBuilder(
      player: actions.player,
      builder: (context, pl) => StreamTabBody(
        children: [
          UrlEntry(actions: actions, hasGlobalUserAgent: hasGlobalUserAgent),
          const SizedBox(height: Tokens.s16),
          ...referenceRows(
            categories: labStreams,
            actions: actions,
            origin: playingOrigin(pl),
          ),
        ],
      ),
    );
  }
}

/// The custom URL entry of the Lab tab: the URL bar, a toggle for the HTTP
/// options and, open, their panel. Plays the URL as a [Media] carrying the
/// options, and remembers them for the session ([HttpOptions.lastUsed]).
class UrlEntry extends StatefulWidget {
  const UrlEntry({
    super.key,
    required this.actions,
    this.hasGlobalUserAgent = LabTab._none,
  });

  final StreamActions actions;

  /// Whether Settings, Network sets a user agent for every stream.
  final bool Function() hasGlobalUserAgent;

  @override
  State<UrlEntry> createState() => _UrlEntryState();
}

class _UrlEntryState extends State<UrlEntry> {
  HttpOptions _options = HttpOptions.lastUsed;
  bool _open = false;
  String? _problem;

  void _play(String url) => _send(url, widget.actions.play);
  void _queue(String url) => _send(url, (m) => widget.actions.enqueue([m]));

  void _send(String url, Future<void> Function(Media media) send) {
    final problem = _options.problem;
    setState(() {
      _problem = problem;
      if (problem != null) _open = true;
    });
    if (problem != null) return;
    HttpOptions.lastUsed = _options;
    send(_options.media(url));
  }

  @override
  Widget build(BuildContext context) {
    final count = _options.count;
    final tap = context.layout.minTap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomUrlBar(
          onPlay: _play,
          onQueue: _queue,
          trailing: [
            IconButton(
              onPressed: () => setState(() => _open = !_open),
              isSelected: _open,
              tooltip: _open ? 'Hide HTTP options' : 'HTTP options',
              color: _open ? Tokens.onAccentContainer : Tokens.fgDim,
              style: IconButton.styleFrom(
                backgroundColor: _open
                    ? Tokens.accentContainer
                    : Colors.transparent,
              ),
              constraints: BoxConstraints.tightFor(width: tap, height: tap),
              padding: EdgeInsets.zero,
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                backgroundColor: Tokens.accent,
                textColor: Tokens.onAccent,
                child: const Icon(Icons.tune_rounded, size: 20),
              ),
            ),
          ],
        ),
        if (_problem != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.s16,
              Tokens.s8,
              Tokens.s16,
              0,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _problem!,
                style: Tokens.label.copyWith(color: Tokens.red),
              ),
            ),
          ),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: Tokens.s16),
                  child: HttpOptionsPanel(
                    initial: _options,
                    globalUserAgent: widget.hasGlobalUserAgent(),
                    onChanged: (o) => setState(() {
                      _options = o;
                      if (_problem != null) _problem = o.problem;
                    }),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
