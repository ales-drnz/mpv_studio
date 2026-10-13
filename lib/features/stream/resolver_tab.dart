import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/custom_url_bar.dart';
import '../../ui/widgets/section_header.dart';
import '../../util/media_labels.dart';
import '../../util/redact.dart';
import 'signed_url_resolver.dart';
import 'stream_actions.dart';
import 'stream_catalog.dart';
import 'widgets/reference_list.dart';
import 'widgets/stream_row.dart';

/// Reference streams played through the demo resolver.
const _signedExamples = [
  StreamCategory(
    name: 'Signed links',
    items: [
      StreamItem(
        label: 'MP3 128k Stereo, signed',
        url: 'https://streams.radiomast.io/ref-128k-mp3-stereo',
      ),
      StreamItem(
        label: 'Ogg Opus 64k Stereo, signed',
        url: 'https://streams.radiomast.io/ref-64k-ogg-opus-stereo',
      ),
      StreamItem(
        label: 'Auphonic chapters demo, signed',
        url: 'https://auphonic.com/media/blog/auphonic_chapters_demo.mp3',
      ),
    ],
  ),
];

/// [url] as an entry the demo resolver signs.
Media signedMedia(String url, {String? title}) => Media(
  SignedUrlResolver.wrap(url),
  extras: {'title': title ?? nameFromUri(url)},
);

/// The Resolver tab: shows `Player.setSourceResolver` at work on links that
/// expire. Entries play through [resolver] (the app installs the shared one
/// at launch, after Plex's), the switch makes the first link it hands out
/// an expired one, and the log lists every call: the URL mpv was about to
/// open, whether it was the retry, what the resolver returned and how long
/// it took.
class ResolverTab extends StatelessWidget {
  const ResolverTab({super.key, required this.actions, required this.resolver});

  final StreamActions actions;
  final SignedUrlResolver resolver;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final split = WidthClass.of(c.maxWidth).atLeast(WidthClass.expanded);
        final controls = _ResolverControls(
          actions: actions,
          resolver: resolver,
        );
        final log = ResolverLog(resolver: resolver);
        if (!split) {
          return StreamTabBody(
            children: [
              controls,
              const SizedBox(height: Tokens.s16),
              log,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: StreamTabBody(children: [controls])),
            SizedBox(width: context.layout.gap),
            Expanded(child: StreamTabBody(children: [log])),
          ],
        );
      },
    );
  }
}

/// Why [url] cannot be signed, or null when it can: the resolver only
/// handles full http and https URLs.
String? signableUrlProblem(String url) {
  final uri = Uri.tryParse(url);
  final ok =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      SignedUrlResolver.unwrap(SignedUrlResolver.wrap(url)) != null;
  return ok
      ? null
      : 'Enter a full http or https URL, e.g. http://localhost:8000/a.flac.';
}

class _ResolverControls extends StatefulWidget {
  const _ResolverControls({required this.actions, required this.resolver});

  final StreamActions actions;
  final SignedUrlResolver resolver;

  @override
  State<_ResolverControls> createState() => _ResolverControlsState();
}

class _ResolverControlsState extends State<_ResolverControls> {
  String? _problem;

  StreamActions get actions => widget.actions;
  SignedUrlResolver get resolver => widget.resolver;

  /// Sends [url] signed, or says why it cannot be.
  void _send(String url, Future<void> Function(Media media) send) {
    final problem = signableUrlProblem(url);
    setState(() => _problem = problem);
    if (problem == null) send(signedMedia(url));
  }

  @override
  Widget build(BuildContext context) {
    return PlaylistBuilder(
      player: actions.player,
      builder: (context, pl) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A source resolver runs right before each stream opens, and once '
            'more after a failed open with isRetry set, so an expired link '
            'can be renewed. Any resolver plugs into setSourceResolver the '
            'same way, a YouTube one included. This one signs links on the '
            'device; the app chains it after the Plex resolver.',
            style: Tokens.label,
          ),
          const SizedBox(height: Tokens.s12),
          ListenableBuilder(
            listenable: resolver,
            builder: (context, _) => _ExpirySwitch(
              value: resolver.simulateExpiry,
              onChanged: (v) => resolver.simulateExpiry = v,
            ),
          ),
          const SizedBox(height: Tokens.s12),
          CustomUrlBar(
            hint: 'URL to sign, e.g. http://localhost:8000/a.flac',
            onPlay: (url) => _send(url, actions.play),
            onQueue: (url) => _send(url, (m) => actions.enqueue([m])),
          ),
          if (_problem != null) ...[
            const SizedBox(height: Tokens.s8),
            Semantics(
              liveRegion: true,
              child: Text(
                _problem!,
                style: Tokens.label.copyWith(color: Tokens.red),
              ),
            ),
          ],
          const SizedBox(height: Tokens.s16),
          ...referenceRows(
            categories: _signedExamples,
            actions: actions,
            origin: playingOrigin(pl),
            mediaFor: (item) => signedMedia(item.url, title: item.label),
          ),
        ],
      ),
    );
  }
}

class _ExpirySwitch extends StatelessWidget {
  const _ExpirySwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.surface,
      shape: Tokens.squircle(Tokens.rMd),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text('Simulate expiry', style: Tokens.body),
        subtitle: Text(
          'The first link handed out is already expired, so the open fails '
          'and the retry gets a fresh one.',
          style: Tokens.caption.copyWith(color: Tokens.fgDim),
        ),
      ),
    );
  }
}

/// The live log of [resolver]'s calls, newest first.
class ResolverLog extends StatelessWidget {
  const ResolverLog({super.key, required this.resolver});

  final SignedUrlResolver resolver;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: resolver,
      builder: (context, _) {
        final log = resolver.log;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: SectionHeader('Resolver calls')),
                RowButton(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: 'Clear the log',
                  onPressed: log.isEmpty ? null : resolver.clearLog,
                ),
              ],
            ),
            if (log.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Tokens.s16),
                child: Text(
                  'No calls yet. Play a signed link to see the resolver run.',
                  style: Tokens.label,
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final entry in log) ResolverLogTile(entry: entry),
          ],
        );
      },
    );
  }
}

/// One [ResolveLogEntry]: when, whether it was the retry, what happened,
/// the URL mpv was about to open and what the resolver returned.
class ResolverLogTile extends StatelessWidget {
  const ResolverLogTile({super.key, required this.entry});

  final ResolveLogEntry entry;

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  static String _elapsed(Duration d) =>
      d.inMilliseconds < 1 ? 'under 1 ms' : '${d.inMilliseconds} ms';

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (entry.outcome) {
      ResolveOutcome.signed => ('Fresh link', Tokens.green),
      ResolveOutcome.expired => ('Expired link', Tokens.amber),
      ResolveOutcome.kept => ('Kept', Tokens.fgDim),
    };
    final mono = Tokens.caption.copyWith(
      fontFamily: Tokens.mono,
      color: Tokens.fgDim,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.s6),
      padding: const EdgeInsets.all(Tokens.s12),
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.squircle(Tokens.rSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Tokens.s8,
            runSpacing: Tokens.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_time(entry.at), style: Tokens.numeric),
              _Badge(
                entry.isRetry ? 'Retry' : 'Before open',
                entry.isRetry ? Tokens.accent : Tokens.fgDim,
              ),
              _Badge(label, color),
              Text(_elapsed(entry.elapsed), style: Tokens.numeric),
            ],
          ),
          const SizedBox(height: Tokens.s6),
          Text(
            'uri  ${withoutCredentials(entry.uri)}',
            style: mono,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            entry.returned == null
                ? 'kept as is'
                : 'gave ${withoutCredentials(entry.returned!)}',
            style: mono.copyWith(color: Tokens.fg),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s6, vertical: 1),
      decoration: ShapeDecoration(
        shape: Tokens.squircle(Tokens.rSm, side: BorderSide(color: color)),
      ),
      child: Text(text, style: Tokens.caption.copyWith(color: color)),
    );
  }
}
