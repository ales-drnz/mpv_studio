import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'rack_catalog.dart';

/// One stage of the rack: an [AudioEffect] with a stable [id], so the UI
/// keeps a stage's expanded state, editor and meters across edits,
/// reorders and duplicates of the same filter. [AudioEffect]s compare by
/// value, so two equal stages need the id to tell them apart.
@immutable
class RackStage {
  final int id;
  final AudioEffect effect;
  const RackStage(this.id, this.effect);

  RackStage withEffect(AudioEffect e) => RackStage(id, e);

  @override
  bool operator ==(Object other) =>
      other is RackStage && other.id == id && other.effect == effect;

  @override
  int get hashCode => Object.hash(id, effect);

  @override
  String toString() => 'RackStage($id, $effect)';
}

/// The rack's ordered chain: a value type whose operations return a new
/// chain. [effects] is the list the player plays.
@immutable
class RackChain {
  final List<RackStage> stages;

  const RackChain._(this.stages);

  static int _nextId = 1;
  static int _newId() => _nextId++;

  /// A chain of [effects], each with a fresh id.
  factory RackChain.of(List<AudioEffect> effects) => RackChain._(
    List.unmodifiable([for (final e in effects) RackStage(_newId(), e)]),
  );

  static const empty = RackChain._([]);

  RackChain _with(List<RackStage> next) => RackChain._(List.unmodifiable(next));

  List<AudioEffect> get effects => [for (final s in stages) s.effect];

  int get length => stages.length;
  bool get isEmpty => stages.isEmpty;

  int indexOf(int id) => stages.indexWhere((s) => s.id == id);

  RackStage? stage(int id) {
    final i = indexOf(id);
    return i < 0 ? null : stages[i];
  }

  /// [effects] with the ids of this chain kept where the stages match:
  /// the same stage first, then the same filter, in order. Used when the
  /// chain changes outside the rack (a rollback, another writer).
  RackChain reconcile(List<AudioEffect> effects) {
    final used = <int>{};
    int? take(bool Function(RackStage s) match) {
      for (final s in stages) {
        if (!used.contains(s.id) && match(s)) {
          used.add(s.id);
          return s.id;
        }
      }
      return null;
    }

    // Same shape, position by position: an edit of values only.
    final sameShape =
        effects.length == stages.length &&
        [
          for (var i = 0; i < effects.length; i++)
            _sameKind(effects[i], stages[i].effect),
        ].every((x) => x);
    if (sameShape) {
      return _with([
        for (var i = 0; i < effects.length; i++)
          RackStage(stages[i].id, effects[i]),
      ]);
    }
    final ids = <int?>[for (final e in effects) take((s) => s.effect == e)];
    return _with([
      for (var i = 0; i < effects.length; i++)
        RackStage(
          ids[i] ?? take((s) => _sameKind(s.effect, effects[i])) ?? _newId(),
          effects[i],
        ),
    ]);
  }

  static bool _sameKind(AudioEffect a, AudioEffect b) =>
      a.runtimeType == b.runtimeType && a.filter == b.filter;

  /// [e] added at [index], the end by default. Returns the new chain and
  /// the new stage's id.
  (RackChain, int) insert(AudioEffect e, {int? index}) {
    final id = _newId();
    final next = [...stages]
      ..insert(
        (index ?? stages.length).clamp(0, stages.length),
        RackStage(id, e),
      );
    return (_with(next), id);
  }

  RackChain remove(int id) => _with([
    for (final s in stages)
      if (s.id != id) s,
  ]);

  /// A copy of stage [id] right after it. Returns the copy's id too.
  (RackChain, int)? duplicate(int id) {
    final i = indexOf(id);
    if (i < 0) return null;
    return insert(stages[i].effect, index: i + 1);
  }

  /// Moves the stage at [from] so it ends up at index [to].
  RackChain move(int from, int to) {
    if (from < 0 || from >= stages.length) return this;
    final target = to.clamp(0, stages.length - 1);
    if (target == from) return this;
    final next = [...stages];
    final s = next.removeAt(from);
    next.insert(target, s);
    return _with(next);
  }

  RackChain replace(int id, AudioEffect e) =>
      _with([for (final s in stages) s.id == id ? s.withEffect(e) : s]);

  RackChain setEnabled(int id, bool on) {
    final s = stage(id);
    if (s == null) return this;
    return replace(id, withEnabled(s.effect, on));
  }

  /// Which occurrence of its filter stage [id] is, disabled stages
  /// included, as `stream.tap(instance:)` counts them. `null` for a raw
  /// stage, which has no tap.
  int? tapInstance(int id) {
    final i = indexOf(id);
    if (i < 0) return null;
    final f = stages[i].effect.filter;
    if (f == null) return null;
    var n = 0;
    for (var k = 0; k < i; k++) {
      if (stages[k].effect.filter == f) n++;
    }
    return n;
  }

  /// The chain with every stage switched off but the meters, which leave
  /// the audio unchanged: the "before" side of the global bypass. The
  /// list keeps its shape, so taps keep their instances.
  List<AudioEffect> get bypassed => [
    for (final s in stages)
      isMeterStage(s.effect) ? s.effect : withEnabled(s.effect, false),
  ];

  /// Whether a loudness meter stage is on.
  bool get meterOn =>
      stages.any((s) => isMeterStage(s.effect) && s.effect.enabled);

  /// The chain with the loudness meter on, appended at the end when there
  /// is none, or with every meter stage removed.
  RackChain withMeter(bool on) {
    if (!on) {
      return _with([
        for (final s in stages)
          if (!isMeterStage(s.effect)) s,
      ]);
    }
    if (stages.any((s) => isMeterStage(s.effect))) {
      return _with([
        for (final s in stages)
          isMeterStage(s.effect)
              ? s.withEffect(withEnabled(s.effect, true))
              : s,
      ]);
    }
    return insert(kMeterStage).$1;
  }

  @override
  bool operator ==(Object other) =>
      other is RackChain && listEquals(other.stages, stages);

  @override
  int get hashCode => Object.hashAll(stages);

  @override
  String toString() => 'RackChain($stages)';
}
