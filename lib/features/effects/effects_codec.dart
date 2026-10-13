import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../generated/filter_catalog.dart';
import 'rack_catalog.dart';

/// Turns the whole effects chain into plain JSON and back, for
/// `AppSettings.effects`. Generic: every stage is written through its
/// filter's descriptor (name, enabled, one value per parameter), so a new
/// filter in the catalog persists with no code here.
///
/// ```json
/// {"version": 2, "chain": [
///   {"filter": "bass", "enabled": true, "params": {"gain": 4.0, ...}},
///   {"raw": "lavfi-anull", "enabled": false}
/// ]}
/// ```
///
/// [decode] also reads the blob of MPV Studio 0.2, one fixed key per
/// featured module (`eq`, `comp`, `bass` and so on), see [decodeLegacy].
class EffectsCodec {
  EffectsCodec._();

  /// The format [encode] writes.
  static const int version = 2;

  // ---- Encode ---------------------------------------------------------

  static Map<String, Object?> encode(List<AudioEffect> fx) => {
    'version': version,
    'chain': [for (final e in fx) ?encodeStage(e)],
  };

  /// One stage as JSON, or `null` for a filter the catalog does not know.
  static Map<String, Object?>? encodeStage(AudioEffect e) {
    if (e is RawAudioEffect) return {'raw': e.entry, 'enabled': e.enabled};
    final d = descriptorOf(e.filter);
    if (d == null) return null;
    return {
      'filter': d.name,
      'enabled': e.enabled,
      'params': {for (final p in d.params) p.name: _encodeParam(p, e)},
    };
  }

  static Object? _encodeParam(ParamSpec p, AudioEffect e) => switch (p) {
    // JSON has no NaN or infinity.
    DoubleParam d => d.get(e).isFinite ? d.get(e) : null,
    IntParam i => i.get(e),
    BoolParam b => b.get(e),
    StringParam s => s.get(e),
    EnumParam en => _enumLabel(en, en.get(e)),
  };

  static String? _enumLabel(EnumParam p, Object? value) {
    if (value == null) return null;
    for (final o in p.options) {
      if (o.value == value) return o.label;
    }
    return null;
  }

  // ---- Decode ---------------------------------------------------------

  /// The chain stored in [blob]: the current format, the 0.2 one, or an
  /// empty chain for anything else. Stages it cannot read are skipped,
  /// and a value it cannot read keeps the parameter's default.
  static List<AudioEffect> decode(Object? blob) {
    if (blob is! Map) return const [];
    final json = blob.cast<String, Object?>();
    final chain = json['chain'];
    if (chain is List) {
      return [for (final s in chain) ?decodeStage(s)];
    }
    return decodeLegacy(json);
  }

  /// One stage from its JSON, or `null` when it is not one.
  static AudioEffect? decodeStage(Object? json) {
    if (json is! Map) return null;
    final m = json.cast<String, Object?>();
    final enabled = m['enabled'] is bool ? m['enabled'] as bool : true;
    final raw = m['raw'];
    if (raw is String) return RawAudioEffect(raw, enabled: enabled);
    final name = m['filter'];
    if (name is! String) return null;
    final d = descriptorNamed(name);
    if (d == null) return null;
    var e = d.create();
    final params = m['params'];
    if (params is Map) {
      for (final p in d.params) {
        if (!params.containsKey(p.name)) continue;
        e = _decodeParam(p, e, params[p.name]);
      }
    }
    return d.setEnabled(e, enabled);
  }

  static AudioEffect _decodeParam(ParamSpec p, AudioEffect e, Object? v) {
    switch (p) {
      case DoubleParam d:
        if (v is num && v.isFinite) return d.set(e, v.toDouble());
      case IntParam i:
        if (v is num && v.isFinite) return i.set(e, v.round());
      case BoolParam b:
        if (v is bool) return b.set(e, v);
      case StringParam s:
        if (v is String) return s.set(e, v);
      case EnumParam en:
        for (final o in en.options) {
          if (o.label == v) return en.set(e, o.value);
        }
    }
    return e;
  }

  // ---- MPV Studio 0.2 -------------------------------------------------

  /// The keys of the 0.2 blob, in the order its modules ran.
  static const legacyKeys = [
    'eq',
    'comp',
    'bass',
    'treble',
    'crossfeed',
    'crystalizer',
    'stereo',
    'subboost',
    'loudnorm',
  ];

  /// Whether [json] is a blob written by MPV Studio 0.2.
  static bool isLegacy(Object? json) =>
      json is Map && json['chain'] == null && legacyKeys.any(json.containsKey);

  /// Reads the 0.2 blob: one module per featured filter, all of them always
  /// present. Only the modules the user touched become stages (switched on,
  /// or with a value off its default), in the old fixed order, so the
  /// rack does not open with nine idle stages.
  static List<AudioEffect> decodeLegacy(Map<String, Object?> json) {
    double d(Map<String, Object?> m, String k, double fallback) =>
        (m[k] is num) ? (m[k] as num).toDouble() : fallback;
    bool b(Map<String, Object?> m, String k, bool fallback) =>
        m[k] is bool ? m[k] as bool : fallback;
    Map<String, Object?> m(String k) =>
        json[k] is Map ? (json[k] as Map).cast<String, Object?>() : const {};

    final eq = m('eq');
    final eqParams = <String, double>{};
    if (eq['params'] is Map) {
      (eq['params'] as Map).forEach((k, v) {
        if (k is String && v is num) eqParams[k] = v.toDouble();
      });
    }
    final comp = m('comp');
    final bass = m('bass');
    final treble = m('treble');
    final cf = m('crossfeed');
    final cr = m('crystalizer');
    final st = m('stereo');
    final sb = m('subboost');
    final ln = m('loudnorm');

    final all = <AudioEffect>[
      SuperequalizerEffect(enabled: b(eq, 'enabled', false), params: eqParams),
      AcompressorEffect(
        enabled: b(comp, 'enabled', false),
        threshold: d(comp, 'threshold', 0.125),
        ratio: d(comp, 'ratio', 2),
        attack: d(comp, 'attack', 20),
        release: d(comp, 'release', 250),
        makeup: d(comp, 'makeup', 1),
        knee: d(comp, 'knee', 2.82843),
      ),
      BassEffect(
        enabled: b(bass, 'enabled', false),
        gain: d(bass, 'gain', 0),
        frequency: d(bass, 'frequency', 100),
      ),
      TrebleEffect(
        enabled: b(treble, 'enabled', false),
        gain: d(treble, 'gain', 0),
        frequency: d(treble, 'frequency', 3000),
      ),
      CrossfeedEffect(
        enabled: b(cf, 'enabled', false),
        strength: d(cf, 'strength', 0.2),
        range: d(cf, 'range', 0.5),
      ),
      CrystalizerEffect(enabled: b(cr, 'enabled', false), i: d(cr, 'i', 2)),
      ExtrastereoEffect(enabled: b(st, 'enabled', false), m: d(st, 'm', 2.5)),
      AsubboostEffect(
        enabled: b(sb, 'enabled', false),
        boost: d(sb, 'boost', 2),
        cutoff: d(sb, 'cutoff', 100),
        dry: d(sb, 'dry', 1),
        wet: d(sb, 'wet', 1),
        feedback: d(sb, 'feedback', 0.9),
      ),
      LoudnormEffect(
        enabled: b(ln, 'enabled', false),
        i: d(ln, 'i', -24),
        lra: d(ln, 'lra', 7),
        tp: d(ln, 'tp', -2),
        linear: b(ln, 'linear', true),
      ),
    ];
    return [
      for (final e in all)
        if (e.enabled ||
            e != withEnabled(descriptorOf(e.filter)!.create(), false))
          e,
    ];
  }
}
