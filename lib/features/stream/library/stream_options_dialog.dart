import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../media_server.dart';
import '../widgets/choice_row.dart';

/// The transcode bitrate ladder (kbps), matching the server transcoders'
/// useful range for music.
const transcodeBitrates = [64, 96, 128, 160, 192, 256];

/// A one-line summary of [options], for the button that opens the dialog.
String describeStreamOptions(StreamOptions options) {
  if (!options.transcodes) return 'Direct play';
  return '${options.codec.label} ${options.bitrateKbps} kbps, '
      '${options.protocol.label} ${options.effectiveTransport.label}';
}

/// Opens the playback options of [server]: direct play or a transcode, and
/// for a transcode its codec, bitrate, protocol and container. Every change
/// goes to [onChanged] at once; the new options apply to the next track
/// played.
Future<void> showStreamOptions(
  BuildContext context, {
  required MediaServer server,
  required StreamOptions options,
  required ValueChanged<StreamOptions> onChanged,
}) {
  return showStudioDialog<void>(
    context,
    title: '${server.name} playback',
    builder: (context) => _StreamOptionsForm(
      server: server,
      initial: options,
      onChanged: onChanged,
    ),
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  );
}

class _StreamOptionsForm extends StatefulWidget {
  const _StreamOptionsForm({
    required this.server,
    required this.initial,
    required this.onChanged,
  });

  final MediaServer server;
  final StreamOptions initial;
  final ValueChanged<StreamOptions> onChanged;

  @override
  State<_StreamOptionsForm> createState() => _StreamOptionsFormState();
}

class _StreamOptionsFormState extends State<_StreamOptionsForm> {
  late StreamOptions _o = widget.initial;

  void _set(StreamOptions next) {
    setState(() => _o = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final protocols = widget.server.protocols;
    final dash = _o.protocol == StreamProtocol.dash;
    const gap = SizedBox(height: Tokens.s16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Labelled(
          label: 'Mode',
          child: SegmentedControl<PlaybackMode>(
            options: [
              for (final m in PlaybackMode.values) SegmentOption(m, m.label),
            ],
            selected: _o.mode,
            onSelect: (m) => _set(_o.copyWith(mode: m)),
          ),
        ),
        const SizedBox(height: Tokens.s4),
        Text(
          _o.transcodes
              ? 'The server re-encodes each track as it plays.'
              : 'The original file, untouched.',
          style: Tokens.caption,
        ),
        if (_o.transcodes) ...[
          gap,
          _Labelled(
            label: 'Codec',
            child: SegmentedControl<TranscodeCodec>(
              options: [
                for (final c in TranscodeCodec.values)
                  SegmentOption(c, c.label),
              ],
              selected: _o.codec,
              onSelect: (c) => _set(_o.copyWith(codec: c)),
            ),
          ),
          gap,
          // Six short values in one pill: they no longer wrap and leave
          // one alone on a second line.
          _Labelled(
            label: 'Bitrate, kbps',
            child: SegmentedControl<int>(
              options: [
                for (final b in transcodeBitrates)
                  SegmentOption(b, '$b', tooltip: '$b kbps'),
              ],
              selected: _o.bitrateKbps,
              onSelect: (b) => _set(_o.copyWith(bitrateKbps: b)),
            ),
          ),
          gap,
          ChoiceRow<StreamProtocol>(
            label: 'Protocol',
            selected: _o.protocol,
            choices: [
              for (final p in StreamProtocol.values)
                Choice(
                  p,
                  p.label,
                  disabledReason: protocols.contains(p)
                      ? null
                      : '${p.label} is not available on ${widget.server.name}',
                ),
            ],
            onSelected: (p) => _set(_o.copyWith(protocol: p)),
          ),
          gap,
          ChoiceRow<StreamTransport>(
            label: 'Container',
            selected: _o.effectiveTransport,
            choices: [
              const Choice(StreamTransport.fmp4, 'fMP4'),
              Choice(
                StreamTransport.mpegts,
                'MPEG-TS',
                disabledReason: dash
                    ? 'MPEG-TS is not available over DASH'
                    : !mpegtsAllowed(_o.codec)
                    ? 'MPEG-TS is available only with the MP3 codec'
                    : null,
              ),
            ],
            onSelected: (t) => _set(_o.copyWith(transport: t)),
          ),
        ],
      ],
    );
  }
}

/// A control under its label, as a [ChoiceRow] lays out its pills.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Tokens.body.copyWith(fontWeight: FontWeight.w500)),
      const SizedBox(height: Tokens.s8),
      child,
    ],
  );
}
