import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Short readouts shared by the Engine panel views.
class EngineFormat {
  EngineFormat._();

  /// `12.3 s`, or `1:05` past a minute.
  static String seconds(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final ms = d.inMilliseconds;
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)} s';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// A byte rate as `850 KB/s` or `2.4 MB/s`.
  static String rate(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 KB/s';
    if (bytesPerSecond < 1000 * 1000) {
      return '${(bytesPerSecond / 1000).toStringAsFixed(0)} KB/s';
    }
    return '${(bytesPerSecond / 1e6).toStringAsFixed(1)} MB/s';
  }

  /// `44.1 kHz`, `48 kHz`.
  static String sampleRate(int? hz) {
    if (hz == null || hz <= 0) return 'n/a';
    final k = hz / 1000;
    return k == k.roundToDouble() ? '${k.round()} kHz' : '$k kHz';
  }

  /// Format, rate and channels of [p] as separate readouts.
  static ({String codec, String format, String rate, String channels}) params(
          AudioParams p) =>
      (
        codec: p.codecName ?? p.codec ?? 'n/a',
        format: p.format?.mpvValue ?? 'n/a',
        rate: sampleRate(p.sampleRate),
        channels: p.hrChannels ??
            p.channels?.mpvValue ??
            (p.channelCount != null ? '${p.channelCount} ch' : 'n/a'),
      );

  static String playbackState(MpvPlaybackState s) => switch (s) {
        MpvPlaybackState.idle => 'Idle',
        MpvPlaybackState.loading => 'Loading',
        MpvPlaybackState.buffering => 'Buffering',
        MpvPlaybackState.playing => 'Playing',
        MpvPlaybackState.paused => 'Paused',
        MpvPlaybackState.completed => 'Completed',
      };

  static String outputState(AudioOutputState s) => switch (s) {
        AudioOutputState.closed => 'Closed',
        AudioOutputState.initializing => 'Opening',
        AudioOutputState.active => 'Active',
        AudioOutputState.failed => 'Failed',
      };
}
