import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// The samples on one side of one stage: `player.stream.tap`.
typedef TapSource =
    Stream<PcmFrame> Function(AudioFilter filter, int instance, TapSide side);

/// What the rack's meters and graphic editors read, handed down the tree
/// so the rack can be built without a player in tests.
class RackEnvironment extends InheritedWidget {
  /// The before and after taps of a stage.
  final TapSource taps;

  /// The output of the whole chain: `player.stream.pcm`.
  final Stream<PcmFrame> pcm;

  /// How the stage meters split the spectrum into bands.
  final SpectrumSettings spectrum;

  /// The live loudness meter: `player.stream.loudnessMeter`.
  final Stream<Loudness> loudness;

  const RackEnvironment({
    super.key,
    required this.taps,
    required this.pcm,
    required this.spectrum,
    required this.loudness,
    required super.child,
  });

  static RackEnvironment? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RackEnvironment>();

  @override
  bool updateShouldNotify(RackEnvironment old) =>
      old.taps != taps ||
      old.pcm != pcm ||
      old.spectrum != spectrum ||
      old.loudness != loudness;
}
