import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../shell/sections.dart';
import '../../studio/playback_issues.dart';
import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/resize_handle.dart';
import '../../util/media_import.dart';
import '../../util/reactive.dart';
import 'playback_scope.dart';
import 'track_identity.dart';
import 'transport_actions.dart';
import 'widgets/cover_art.dart';
import 'widgets/double_tap_seek.dart';
import 'widgets/playback_states.dart';
import 'widgets/position_bar.dart';
import 'widgets/spectrum_curve.dart';
import 'widgets/track_info.dart';
import 'widgets/transport_controls.dart';
import 'widgets/volume_control.dart';
import 'widgets/vu_meter.dart';
import 'widgets/waveform/waveform_meter.dart';

/// The Playback page: the current track's cover and title, the transport,
/// the waveform meter with the chapters and the A-B loop, the volume, the
/// level meter and the spectrum. Laid out for the space it gets:
///
/// * a column on phones in portrait and tall tablets, scrolling when the
///   text is large;
/// * side by side on short windows (phones in landscape): the deck on the
///   left, the waveform on the right;
/// * a stage on medium windows: the waveform on top, the deck in a row,
///   the spectrum under it;
/// * two columns on large and ultrawide windows: the deck on the left,
///   the waveform and the spectrum filling the rest.
///
/// With no current track it shows how to start one. It reads the player
/// from the app; tests hand one in with [player] and [guard].
class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({
    super.key,
    this.player,
    this.guard = unguarded,
    this.failed,
    this.onOpenFiles,
    this.onOpenStream,
  });

  /// The player to show, instead of the app's.
  final PlayerApi? player;

  /// The guard of [player]'s calls.
  final CallGuard guard;

  /// The failed queue entries, with [player].
  final ValueListenable<Set<Media>>? failed;

  /// Replaces opening the file picker (tests).
  final VoidCallback? onOpenFiles;

  /// Replaces going to the Stream section (tests).
  final VoidCallback? onOpenStream;

  @override
  Widget build(BuildContext context) {
    final body = _PlaybackBody(
      onOpenFiles: onOpenFiles,
      onOpenStream: onOpenStream,
    );
    final given = player;
    if (given != null) {
      return PlaybackScope(
        player: given,
        guard: guard,
        failed: failed,
        child: body,
      );
    }
    return PlaybackScope.fromApp(context, child: body)!;
  }
}

/// How the page is laid out for the space it has.
enum _Shape { column, side, stage, split }

_Shape _shapeFor(Size size) {
  final wide = WidthClass.of(size.width);
  if (HeightClass.of(size.height) == HeightClass.short &&
      size.width > size.height) {
    return _Shape.side;
  }
  if (size.width >= Breakpoints.splitContent) return _Shape.split;
  // Phones, and tablets standing up: one column.
  if (wide == WidthClass.compact || size.height > size.width * 1.2) {
    return _Shape.column;
  }
  return _Shape.stage;
}

class _PlaybackBody extends StatefulWidget {
  const _PlaybackBody({this.onOpenFiles, this.onOpenStream});

  final VoidCallback? onOpenFiles;
  final VoidCallback? onOpenStream;

  @override
  State<_PlaybackBody> createState() => _PlaybackBodyState();
}

class _PlaybackBodyState extends State<_PlaybackBody> {
  /// The waveform's height where the user can resize it; null until they
  /// do, so each shape starts at its own default.
  double? _meterHeight;

  // One identity for the waveform meter, so a change of shape reparents
  // it (its State and waveform subscription live on) instead of making a
  // new one: a new one would drop the stream's only listener, which
  // restarts the analysis and wipes a streaming waveform.
  final GlobalKey _waveformKey = GlobalKey(debugLabel: 'waveform');

  Future<void> _openFiles() async {
    final open = widget.onOpenFiles;
    if (open != null) return open();
    final scope = PlaybackScope.of(context);
    final notify = feedbackFor(context);
    final List<String> paths;
    try {
      paths = await pickAudioFiles();
    } on PlatformException catch (e) {
      notify('Could not open the file picker: ${e.message ?? e.code}');
      return;
    }
    if (paths.isEmpty) return;
    await scope.guard(
      () => scope.player.openAll([
        for (final p in paths) Media(p, extras: {'title': baseNameNoExt(p)}),
      ], play: true),
    );
  }

  void _openStream() {
    final open = widget.onOpenStream;
    if (open != null) return open();
    StatefulNavigationShell.maybeOf(context)?.goBranch(Section.stream.index);
  }

  @override
  Widget build(BuildContext context) {
    final scope = PlaybackScope.of(context);
    final player = scope.player;
    return Live<Playlist>(
      stream: player.stream.playlist,
      initial: player.state.playlist,
      builder: (context, pl) {
        if (currentMedia(pl) == null) {
          return PageFrame(
            title: 'Playback',
            scrollable: false,
            body: EmptyPlayback(
              onOpenFiles: _openFiles,
              onOpenStream: _openStream,
              onPlayQueue: pl.items.isEmpty
                  ? null
                  : () => scope.guard(() => player.jump(0)),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, c) {
            final shape = _shapeFor(c.biggest);
            // Phones keep the height for the player: the tab bar already
            // says where they are. The info button lives in the transport
            // on every shape, so the header has no actions.
            final header =
                shape != _Shape.side &&
                !WidthClass.of(c.maxWidth).below(WidthClass.medium);
            return PageFrame(
              title: header ? 'Playback' : null,
              scrollable: false,
              maxWidth: switch (shape) {
                _Shape.column => Breakpoints.medium,
                _Shape.stage => Breakpoints.wide,
                _Shape.side || _Shape.split => double.infinity,
              },
              body: switch (shape) {
                _Shape.column => _columnLayout(context),
                _Shape.side => _sideLayout(context),
                _Shape.stage => _stageLayout(context),
                _Shape.split => _splitLayout(context),
              },
            );
          },
        );
      },
    );
  }

  Widget _waveform({double? height}) {
    final meter = DecoratedBox(
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.shape(Tokens.rLg),
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: Tokens.shape(Tokens.rLg)),
        child: WaveformMeter(key: _waveformKey),
      ),
    );
    return height == null ? meter : SizedBox(height: height, child: meter);
  }

  Widget _cover(double size) {
    final scope = PlaybackScope.of(context);
    return DoubleTapSeek(
      onSeek: (by) => scope.guard(() => scope.player.seek(by, relative: true)),
      child: CoverArtView(player: scope.player, size: size),
    );
  }

  /// A waveform the user resizes by its bottom seam, above [below].
  Widget _resizable({
    required double initial,
    required double min,
    required double max,
    required Widget below,
  }) {
    final top = math.max(min, max);
    final height = (_meterHeight ?? initial).clamp(min, top).toDouble();
    final touch = context.layout.isTouch;
    // The gap between the panes; on touch the grab area is a full touch
    // target laid over the panes around the gap.
    final grip = touch ? 24.0 : 12.0;
    final hit = touch ? math.max(grip, context.layout.minTap) : grip;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _waveform(height: height),
            SizedBox(height: grip),
            Expanded(child: below),
          ],
        ),
        ResizeHandle.overlay(
          offset: height + grip / 2,
          hit: hit,
          handle: ResizeHandle(
            axis: Axis.horizontal,
            hitThickness: hit,
            label: 'Waveform height',
            // From the current height: several drag events can arrive
            // before the next build.
            onDelta: (dy) => setState(
              () => _meterHeight = ((_meterHeight ?? height) + dy)
                  .clamp(min, top)
                  .toDouble(),
            ),
          ),
        ),
      ],
    );
  }

  /// [above] at its own height, then [fill] taking what is left, at
  /// least a strip of it: the whole scrolls when [above] does not fit (a
  /// failure banner or a chapter line on a low window).
  Widget _fillBelow(List<Widget> above, Widget fill) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: above,
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: fill,
          ),
        ),
      ],
    );
  }

  /// The least waveform meter height: on touch its bottom row (the
  /// scrollbar and the zoom pill) is a touch target tall, so the meter
  /// grows by as much to keep the same wave.
  static double _leastMeter(BuildContext context) =>
      context.layout.isTouch ? 128 : 96;

  /// Phones in portrait, tall tablets: one column, the spectrum filling
  /// what is left, scrolling when the content does not fit.
  Widget _columnLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final cover = math.min(c.maxWidth * 0.62, h * 0.27).clamp(120.0, 320.0);
        final least = _leastMeter(context);
        final meter = (_meterHeight ?? h * 0.16)
            .clamp(least, math.max(least, h * 0.4))
            .toDouble();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FailedTrackBanner(),
                  Center(child: _cover(cover)),
                  const SizedBox(height: Tokens.s12),
                  const TrackInfo(),
                  const SizedBox(height: Tokens.s12),
                  _waveform(height: meter),
                  const PositionBar(),
                  const ChapterBar(),
                  const SizedBox(height: Tokens.s4),
                  const TransportControls(),
                  const SizedBox(height: Tokens.s8),
                  const VolumeControl(),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 88),
                child: const Column(
                  children: [
                    SizedBox(height: Tokens.s8),
                    VuMeter(),
                    SizedBox(height: Tokens.s8),
                    Expanded(child: SpectrumCurve()),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Short windows: the deck on the left, the waveform on the right.
  Widget _sideLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final deck = (c.maxWidth * 0.44).clamp(260.0, 420.0);
        final cover = (c.maxHeight * 0.26).clamp(56.0, 96.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: deck,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _cover(cover),
                        const SizedBox(width: Tokens.s12),
                        const Expanded(
                          child: TrackInfo(centered: false, compact: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: Tokens.s8),
                    const TransportControls(dense: true),
                    const VolumeControl(),
                    const ChapterBar(),
                  ],
                ),
              ),
            ),
            SizedBox(width: context.layout.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FailedTrackBanner(),
                  Expanded(child: _waveform()),
                  const PositionBar(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Medium windows: the waveform on top, the deck in a row, the spectrum
  /// under it.
  Widget _stageLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final cover = (c.maxWidth * 0.18).clamp(120.0, 168.0);
        final tap = context.layout.minTap;
        // The title (56), the play row (80) and the mode row (a tap
        // target), 12 apart.
        final rowH = math.max(cover, 160.0 + tap);
        return _resizable(
          initial: h * 0.28,
          min: _leastMeter(context),
          max: h - rowH - 160,
          below: _fillBelow([
            const PositionBar(),
            const ChapterBar(),
            const FailedTrackBanner(),
            const SizedBox(height: Tokens.s8),
            SizedBox(
              height: rowH,
              child: Row(
                children: [
                  _cover(cover),
                  const SizedBox(width: Tokens.s24),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TrackInfo(),
                        SizedBox(height: Tokens.s12),
                        TransportControls(),
                      ],
                    ),
                  ),
                  const SizedBox(width: Tokens.s24),
                  SizedBox(
                    width: tap,
                    child: const VolumeControl(axis: Axis.vertical),
                  ),
                  const SizedBox(width: Tokens.s12),
                  const VuMeter(axis: Axis.vertical),
                ],
              ),
            ),
            const SizedBox(height: Tokens.s12),
          ], const SpectrumCurve()),
        );
      },
    );
  }

  /// Large and ultrawide windows: the deck in a column on the left, the
  /// waveform and the spectrum filling the rest.
  Widget _splitLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final deck = (c.maxWidth * 0.28).clamp(340.0, 440.0);
        final cover = math.min(deck, h * 0.42);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: deck,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _cover(cover)),
                    const SizedBox(height: Tokens.s16),
                    const TrackInfo(),
                    const SizedBox(height: Tokens.s16),
                    const TransportControls(),
                    const SizedBox(height: Tokens.s12),
                    const VolumeControl(),
                    const SizedBox(height: Tokens.s8),
                    const VuMeter(),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Tokens.s32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FailedTrackBanner(),
                  Expanded(
                    child: _resizable(
                      initial: h * 0.5,
                      min: 140,
                      max: h - 220,
                      below: _fillBelow(const [
                        PositionBar(),
                        ChapterBar(),
                        SizedBox(height: Tokens.s12),
                      ], const SpectrumCurve()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
