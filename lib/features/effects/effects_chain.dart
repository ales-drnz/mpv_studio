import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../generated/filter_catalog.dart';

/// The rack keeps at most one stage per filter in the effects chain. These
/// helpers read and write the chain that way: a filter's stage is edited in
/// place, and a filter seen for the first time is appended.
extension RackChain on List<AudioEffect> {
  /// The stage of type [T], or `null` when the chain has none.
  T? stage<T extends AudioEffect>() {
    for (final e in this) {
      if (e is T) return e;
    }
    return null;
  }

  /// The chain with [next] in place of the stage of the same filter, or
  /// with [next] appended when there is none.
  List<AudioEffect> put(AudioEffect next) {
    final i = indexWhere(
      (e) => e.filter != null && e.filter == next.filter,
    );
    if (i < 0) return [...this, next];
    return [...this]..[i] = next;
  }
}

/// A catalog filter's stage in the chain.
extension DescriptorStage on FilterDescriptor {
  /// This filter's stage in [fx], or a new bypassed one.
  AudioEffect stageIn(List<AudioEffect> fx) {
    for (final e in fx) {
      if (e.filter == filter) return e;
    }
    return setEnabled(create(), false);
  }

  /// Whether [fx] has this filter's stage, switched on.
  bool isEnabled(List<AudioEffect> fx) =>
      fx.any((e) => e.filter == filter && e.enabled);

  /// [fx] with this filter's stage changed by [change].
  List<AudioEffect> edit(
    List<AudioEffect> fx,
    AudioEffect Function(AudioEffect stage) change,
  ) =>
      fx.put(change(stageIn(fx)));
}
