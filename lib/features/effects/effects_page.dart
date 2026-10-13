import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../audio/biquad.dart';
import '../../audio/pcm_analysis.dart';
import '../../studio/player_scope.dart';
import '../../ui/tokens.dart';
import '../../util/reactive.dart';
import '../../ui/widgets/back_bar.dart';
import '../../ui/widgets/controls.dart';
import '../../ui/widgets/grid_card.dart';
import '../../ui/widgets/section_body.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/section_switcher.dart';
import '../../generated/filter_catalog.dart';
import 'effects_chain.dart';
import 'widgets/advanced_filter_page.dart';
import 'widgets/equalizer.dart';
import 'widgets/filter_card.dart';
import 'widgets/compressor_curve.dart';
import 'widgets/response_curve.dart';
import 'widgets/stereo_scope.dart';
import 'widgets/crossfeed_diagram.dart';
import 'widgets/crystalizer_waveform.dart';
import 'widgets/loudness_gauge.dart';

/// The DSP rack. The curated effects that earn a bespoke visualiser are
/// surfaced as a **grid** of squircle tiles (mirroring the Settings
/// landing); tapping one opens its dedicated editor — the hero graphic
/// over its controls, with a back affordance. The remaining ffmpeg
/// catalog stays a plain **list** below, so the two tiers read as clearly
/// different things.
///
/// The page is the single writer of mpv's `af` chain — changes push
/// atomically via `setAudioEffects` and mirror into [AppSettings].
/// Slider drags mutate a local draft for smooth motion and commit on
/// release; toggles and resets commit immediately.
class EffectsPage extends StatefulWidget {
  const EffectsPage({super.key});

  @override
  State<EffectsPage> createState() => _EffectsPageState();
}

class _EffectsPageState extends State<EffectsPage>
    with StreamListenerState<EffectsPage> {
  late final Player _player;
  late List<AudioEffect> _fx;
  bool _editing = false;

  /// Mirrors [_fx] so a pushed featured-editor route can rebuild on every edit
  /// (a route can't observe this State's `setState` directly).
  late final ValueNotifier<List<AudioEffect>> _fxVN;

  @override
  void onSubscribe() {
    _player = PlayerScope.of(context);
    _fx = _player.state.audioEffects;
    _fxVN = ValueNotifier(_fx);
    listen(_player.stream.audioEffects, (v) {
      // Resync from the engine only when the user isn't mid-drag, so an
      // optimistic local draft is never clobbered.
      if (!_editing && mounted && v != _fx) {
        setState(() => _fx = v);
        _fxVN.value = v;
      }
    });
  }

  @override
  void dispose() {
    _fxVN.dispose();
    super.dispose();
  }

  /// Updates the local draft only (no engine write) — used during drags.
  void _setLocal(List<AudioEffect> next) {
    setState(() {
      _fx = next;
      _editing = true;
    });
    _fxVN.value = next;
  }

  /// Pushes the current draft to the engine. Persistence happens
  /// automatically via the [AppSettings] observer on `stream.audioEffects`.
  void _commit() {
    _editing = false;
    _player.setAudioEffects(_fx);
  }

  /// Sets a new chain and commits immediately — toggles, resets.
  void _commitNow(List<AudioEffect> next) {
    setState(() {
      _fx = next;
      _editing = false;
    });
    _fxVN.value = next;
    _player.setAudioEffects(next);
  }

  SliderRowSpec _spec(
    String label,
    double value,
    double min,
    double max,
    List<AudioEffect> Function(double v) apply, {
    String Function(double v)? format,
  }) =>
      SliderRowSpec(
        label: label,
        value: value,
        min: min,
        max: max,
        format: format,
        onChanged: (v) => _setLocal(apply(v)),
        onChangeEnd: _commit,
      );

  static String _pct(double v) => '${(v * 100).round()}%';

  // ── Featured effect descriptors ───────────────────────────────────
  //
  // Each carries everything both the grid tile (icon, title, on-state)
  // and the detail editor (graphic, controls, toggle, reset) need.

  List<_Featured> _featured() {
    // A module not in the chain yet shows its defaults, bypassed, so the
    // cards always have concrete values to show.
    final eq =
        _fx.stage<SuperequalizerEffect>() ?? const SuperequalizerEffect(enabled: false);
    final comp =
        _fx.stage<AcompressorEffect>() ?? const AcompressorEffect(enabled: false);
    final bass = _fx.stage<BassEffect>() ?? const BassEffect(enabled: false);
    final treble =
        _fx.stage<TrebleEffect>() ?? const TrebleEffect(enabled: false);
    final cf =
        _fx.stage<CrossfeedEffect>() ?? const CrossfeedEffect(enabled: false);
    final cr =
        _fx.stage<CrystalizerEffect>() ?? const CrystalizerEffect(enabled: false);
    final st =
        _fx.stage<ExtrastereoEffect>() ?? const ExtrastereoEffect(enabled: false);
    final sb =
        _fx.stage<AsubboostEffect>() ?? const AsubboostEffect(enabled: false);
    final ln =
        _fx.stage<LoudnormEffect>() ?? const LoudnormEffect(enabled: false);

    return [
      // ---- 18-band graphic EQ -----------------------------------------
      _Featured(
        title: 'Equalizer',
        subtitle: '18-band graphic',
        icon: Icons.equalizer_rounded,
        enabled: eq.enabled,
        onEnabled: (v) =>
            _commitNow(_fx.put(eq.copyWith(enabled: v))),
        onReset: () => _commitNow(_fx.put(
            SuperequalizerEffect(enabled: eq.enabled, params: const {}))),
        graphic: Equalizer(
          bandsDb: {
            for (final b in kEqBands)
              b.key: eqLinearToDb(eq.params[b.key] ?? 1.0),
          },
          enabled: eq.enabled,
          onChanged: (key, db) {
            final params = Map<String, double>.from(eq.params);
            if (db.abs() < 0.05) {
              params.remove(key);
            } else {
              params[key] = eqDbToLinear(db);
            }
            _setLocal(_fx.put(eq.copyWith(params: params)));
          },
          onChangeEnd: _commit,
        ),
        controls: const [],
      ),

      // ---- Compressor -------------------------------------------------
      _Featured(
        title: 'Compressor',
        subtitle: 'Dynamic range control',
        icon: Icons.compress_rounded,
        enabled: comp.enabled,
        onEnabled: (v) =>
            _commitNow(_fx.put(comp.copyWith(enabled: v))),
        onReset: () => _commitNow(
            _fx.put(AcompressorEffect(enabled: comp.enabled))),
        graphic: CompressorCurve(
          threshold: comp.threshold,
          ratio: comp.ratio,
          knee: comp.knee,
          makeup: comp.makeup,
          enabled: comp.enabled,
        ),
        controls: [
          _spec(
              'Threshold',
              eqLinearToDb(comp.threshold),
              -60,
              0,
              (v) => _fx.put(comp.copyWith(
                      threshold: eqDbToLinear(v).clamp(0.000977, 1.0))),
              format: (v) => '${v.round()} dB'),
          _spec('Ratio', comp.ratio, 1, 20,
              (v) => _fx.put(comp.copyWith(ratio: v)),
              format: (v) => '${v.toStringAsFixed(1)}:1'),
          _spec('Attack', comp.attack, 1, 200,
              (v) => _fx.put(comp.copyWith(attack: v)),
              format: (v) => '${v.round()} ms'),
          _spec('Release', comp.release, 20, 2000,
              (v) => _fx.put(comp.copyWith(release: v)),
              format: (v) => '${v.round()} ms'),
          _spec(
              'Make-up gain',
              eqLinearToDb(comp.makeup),
              0,
              24,
              (v) => _fx.put(
                  comp.copyWith(makeup: eqDbToLinear(v).clamp(1.0, 64.0))),
              format: (v) => '+${v.round()} dB'),
        ],
      ),

      // ---- Bass -------------------------------------------------------
      _Featured(
        title: 'Bass',
        subtitle: 'Low shelf',
        icon: Icons.graphic_eq_rounded,
        enabled: bass.enabled,
        onEnabled: (v) =>
            _commitNow(_fx.put(bass.copyWith(enabled: v))),
        onReset: () =>
            _commitNow(_fx.put(BassEffect(enabled: bass.enabled))),
        graphic: ResponseCurve(
          response: BiquadResponse.lowShelf(bass.frequency, bass.gain),
          markerHz: bass.frequency,
          enabled: bass.enabled,
        ),
        controls: [
          _spec('Gain', bass.gain, -24, 24,
              (v) => _fx.put(bass.copyWith(gain: v)),
              format: (v) => '${v.toStringAsFixed(1)} dB'),
          _spec('Frequency', bass.frequency, 20, 500,
              (v) => _fx.put(bass.copyWith(frequency: v)),
              format: (v) => '${v.round()} Hz'),
        ],
      ),

      // ---- Treble -----------------------------------------------------
      _Featured(
        title: 'Treble',
        subtitle: 'High shelf',
        icon: Icons.graphic_eq_rounded,
        enabled: treble.enabled,
        onEnabled: (v) =>
            _commitNow(_fx.put(treble.copyWith(enabled: v))),
        onReset: () => _commitNow(
            _fx.put(TrebleEffect(enabled: treble.enabled))),
        graphic: ResponseCurve(
          response: BiquadResponse.highShelf(treble.frequency, treble.gain),
          markerHz: treble.frequency,
          enabled: treble.enabled,
        ),
        controls: [
          _spec('Gain', treble.gain, -24, 24,
              (v) => _fx.put(treble.copyWith(gain: v)),
              format: (v) => '${v.toStringAsFixed(1)} dB'),
          _spec('Frequency', treble.frequency, 1000, 16000,
              (v) => _fx.put(treble.copyWith(frequency: v)),
              format: (v) => '${(v / 1000).toStringAsFixed(1)}k Hz'),
        ],
      ),

      // ---- Sub boost --------------------------------------------------
      _Featured(
        title: 'Sub boost',
        subtitle: 'Synthesised low end',
        icon: Icons.surround_sound_rounded,
        enabled: sb.enabled,
        onEnabled: (v) =>
            _commitNow(_fx.put(sb.copyWith(enabled: v))),
        onReset: () => _commitNow(
            _fx.put(AsubboostEffect(enabled: sb.enabled))),
        graphic: ResponseCurve(
          response: BiquadResponse.lowShelf(
              sb.cutoff, amplitudeToDb(sb.boost)),
          markerHz: sb.cutoff,
          enabled: sb.enabled,
        ),
        controls: [
          _spec('Boost', sb.boost, 1, 12,
              (v) => _fx.put(sb.copyWith(boost: v)),
              format: (v) => v.toStringAsFixed(1)),
          _spec('Cutoff', sb.cutoff, 50, 900,
              (v) => _fx.put(sb.copyWith(cutoff: v)),
              format: (v) => '${v.round()} Hz'),
          _spec('Wet', sb.wet, 0, 1,
              (v) => _fx.put(sb.copyWith(wet: v)),
              format: _pct),
          _spec('Dry', sb.dry, 0, 1,
              (v) => _fx.put(sb.copyWith(dry: v)),
              format: _pct),
        ],
      ),

      // ---- Stereo width -----------------------------------------------
      _Featured(
        title: 'Stereo width',
        subtitle: 'Widen the stereo image',
        icon: Icons.panorama_horizontal_rounded,
        enabled: st.enabled,
        onEnabled: (v) =>
            _commitNow(_fx.put(st.copyWith(enabled: v))),
        onReset: () => _commitNow(
            _fx.put(ExtrastereoEffect(enabled: st.enabled))),
        graphic: StereoScope(enabled: st.enabled),
        controls: [
          _spec('Amount', st.m, 0, 8,
              (v) => _fx.put(st.copyWith(m: v)),
              format: (v) => v.toStringAsFixed(1)),
        ],
      ),

      // ---- Crossfeed --------------------------------------------------
      _Featured(
        title: 'Crossfeed',
        subtitle: 'Headphone channel blend',
        icon: Icons.headphones_rounded,
        enabled: cf.enabled,
        onEnabled: (v) =>
            _commitNow(_fx.put(cf.copyWith(enabled: v))),
        onReset: () => _commitNow(
            _fx.put(CrossfeedEffect(enabled: cf.enabled))),
        graphic: CrossfeedDiagram(
          strength: cf.strength,
          range: cf.range,
          enabled: cf.enabled,
        ),
        controls: [
          _spec('Strength', cf.strength, 0, 1,
              (v) => _fx.put(cf.copyWith(strength: v)),
              format: _pct),
          _spec('Range', cf.range, 0, 1,
              (v) => _fx.put(cf.copyWith(range: v)),
              format: _pct),
        ],
      ),

      // ---- Clarity (crystalizer) --------------------------------------
      _Featured(
        title: 'Clarity',
        subtitle: 'Crystalizer expander',
        icon: Icons.auto_awesome_rounded,
        enabled: cr.enabled,
        onEnabled: (v) =>
            _commitNow(_fx.put(cr.copyWith(enabled: v))),
        onReset: () => _commitNow(
            _fx.put(CrystalizerEffect(enabled: cr.enabled))),
        graphic: CrystalizerWaveform(intensity: cr.i, enabled: cr.enabled),
        controls: [
          _spec('Intensity', cr.i, -10, 10,
              (v) => _fx.put(cr.copyWith(i: v)),
              format: (v) => v.toStringAsFixed(1)),
        ],
      ),

      // ---- Loudness ---------------------------------------------------
      _Featured(
        title: 'Loudness',
        subtitle: 'EBU R128 normalization',
        icon: Icons.volume_up_rounded,
        enabled: ln.enabled,
        onEnabled: (v) =>
            _commitNow(_fx.put(ln.copyWith(enabled: v))),
        onReset: () => _commitNow(
            _fx.put(LoudnormEffect(enabled: ln.enabled))),
        graphic: LoudnessGauge(
          target: ln.i,
          range: ln.lra,
          truePeak: ln.tp,
          enabled: ln.enabled,
        ),
        controls: [
          _spec('Target', ln.i, -70, -5,
              (v) => _fx.put(ln.copyWith(i: v)),
              format: (v) => '${v.round()} LUFS'),
          _spec('Range', ln.lra, 1, 50,
              (v) => _fx.put(ln.copyWith(lra: v)),
              format: (v) => '${v.round()} LU'),
          _spec('True peak', ln.tp, -9, 0,
              (v) => _fx.put(ln.copyWith(tp: v)),
              format: (v) => '${v.toStringAsFixed(1)} dB'),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final featured = _featured();
    final advanced = [for (final d in kFilterCatalog) if (d.advanced) d];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          Tokens.s20, Tokens.s8, Tokens.s20, Tokens.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Featured'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 168,
              crossAxisSpacing: Tokens.s12,
              mainAxisSpacing: Tokens.s12,
              childAspectRatio: 1,
            ),
            itemCount: featured.length,
            itemBuilder: (context, i) => GridCard(
              icon: featured[i].icon,
              title: featured[i].title,
              active: featured[i].enabled,
              // Push a detail route with the shared fade+slide transition. The
              // editor rebuilds live off _fxVN (_featured()[i] re-read each
              // time) so its sliders track the engine state.
              onTap: () => Navigator.of(context).push(
                fadeSlidePageRoute(
                  _FeaturedDetailScreen(
                    listenable: _fxVN,
                    title: featured[i].title,
                    detailBuilder: () => _FeaturedDetail(spec: _featured()[i]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Tokens.s24),
          // Advanced: the required-param filters (chorus / pan / channelmap /
          // aeval / arnndn). Each opens a dedicated page with curated presets,
          // a custom field, and — for arnndn — a model-file picker, so they're
          // only ever enabled with valid values (never broken in the chain).
          const SectionHeader('Advanced'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 168,
              crossAxisSpacing: Tokens.s12,
              mainAxisSpacing: Tokens.s12,
              childAspectRatio: 1,
            ),
            itemCount: advanced.length,
            itemBuilder: (context, i) {
              final spec = advanced[i];
              return GridCard(
                icon: spec.icon,
                title: spec.title,
                active: spec.isEnabled(_fx),
                onTap: () => Navigator.of(context).push(
                  fadeSlidePageRoute(AdvancedFilterPage(spec: spec)),
                ),
              );
            },
          ),
          const SizedBox(height: Tokens.s24),
          const SectionHeader('All effects'),
          for (final cat in kFilterCategories) _CatalogTile(category: cat),
        ],
      ),
    );
  }
}

/// A pushed full-page editor for one featured effect. Rebuilds via
/// [listenable] (the page's `_fxVN`) so its controls stay in sync with the
/// engine while editing. Pushed via [fadeSlidePageRoute].
class _FeaturedDetailScreen extends StatelessWidget {
  final Listenable listenable;
  final String title;
  final Widget Function() detailBuilder;
  const _FeaturedDetailScreen({
    required this.listenable,
    required this.title,
    required this.detailBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            BackBar(
              title: title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: listenable,
                builder: (_, _) => detailBuilder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bundles everything a featured effect needs for both its grid tile and
/// its detail editor.
class _Featured {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onReset;

  /// Hero visualiser shown above the controls in the detail editor.
  final Widget graphic;

  /// Slider controls; empty for effects whose graphic *is* the control
  /// (the equalizer).
  final List<SliderRowSpec> controls;

  const _Featured({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onEnabled,
    required this.onReset,
    required this.graphic,
    required this.controls,
  });
}

/// Bundles a [SliderRow]'s parameters so a module can declare its controls
/// as a flat list and let the editor render them.
class SliderRowSpec {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double v)? format;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  const SliderRowSpec({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.format,
  });

  Widget build(bool enabled) => SliderRow(
        label: label,
        value: value,
        min: min,
        max: max,
        format: format,
        enabled: enabled,
        onChanged: onChanged,
        onChangeEnd: (_) => onChangeEnd(),
      );
}

/// The dedicated editor for one featured effect: a bypass toggle, the hero
/// graphic, the controls, and a reset — all in the flat card language.
class _FeaturedDetail extends StatelessWidget {
  final _Featured spec;
  const _FeaturedDetail({required this.spec});

  @override
  Widget build(BuildContext context) {
    return SectionBody(
      children: [
        // Bypass toggle.
        _DetailCard(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
          child: SwitchRow(
            label: 'Effect',
            subtitle: spec.subtitle,
            value: spec.enabled,
            onChanged: spec.onEnabled,
          ),
        ),
        // Hero graphic.
        _DetailCard(child: spec.graphic),
        // Controls.
        if (spec.controls.isNotEmpty)
          _DetailCard(
            child: Column(
              children: [
                for (var i = 0; i < spec.controls.length; i++) ...[
                  if (i > 0) const SizedBox(height: Tokens.s4),
                  spec.controls[i].build(spec.enabled),
                ],
              ],
            ),
          ),
        // Reset.
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: spec.onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Reset'),
            style: TextButton.styleFrom(
              foregroundColor: Tokens.fgDim,
              textStyle: Tokens.label,
            ),
          ),
        ),
      ],
    );
  }
}

/// A flat bordered surface card used to frame the detail editor's blocks.
class _DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _DetailCard({
    required this.child,
    this.padding = const EdgeInsets.all(Tokens.s16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.s12),
      padding: padding,
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.squircle(Tokens.rMd),
      ),
      child: child,
    );
  }
}

/// A tile in the "All effects" index. Opens a full page listing every
/// filter in [category] as a typed card.
class _CatalogTile extends StatelessWidget {
  final FilterCategory category;
  const _CatalogTile({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.s8),
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.squircle(Tokens.rMd),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: Tokens.squircle(Tokens.rMd),
          onTap: () => Navigator.of(context).push(
            fadeSlidePageRoute(_CatalogCategoryScreen(category: category)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.s16,
              vertical: Tokens.s12,
            ),
            child: Row(
              children: [
                Icon(category.icon, size: 18, color: Tokens.fgDim),
                const SizedBox(width: Tokens.s12),
                Expanded(child: Text(category.title, style: Tokens.body)),
                Text(
                  '${kFilterCatalog.where((d) => d.category == category.slug && !d.advanced).length}',
                  style: Tokens.numeric,
                ),
                const SizedBox(width: Tokens.s8),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Tokens.fgFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-page list of one catalog category's filter cards, pushed over the
/// shell with a back affordance.
class _CatalogCategoryScreen extends StatelessWidget {
  final FilterCategory category;
  const _CatalogCategoryScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            BackBar(
              title: category.title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SectionBody(
                  children: [CategoryFiltersView(slug: category.slug)]),
            ),
          ],
        ),
      ),
    );
  }
}
