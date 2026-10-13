import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/player_scope.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/back_bar.dart';
import '../../ui/widgets/controls.dart';
import '../../ui/widgets/grid_card.dart';
import '../../ui/widgets/section_body.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/section_switcher.dart';
import '../../util/reactive.dart';
import 'rack_catalog.dart';
import 'rack_controller.dart';
import 'widgets/loudness_panel.dart';
import 'widgets/stage_editor.dart';
import 'widgets/stage_meters.dart';
import 'widgets/stage_tile.dart';

/// The Effects section: the signal chain as a rack of stages, in the
/// order mpv runs them, with quick editors for the featured effects and
/// the live loudness meter below.
///
/// The page wires the player in; [SignalChainView] is the rack itself.
class EffectsPage extends StatelessWidget {
  const EffectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final rack = PlayerScope.rackOf(context);
    final normalizer = PlayerScope.normalizerOf(context);
    return Live<SpectrumSettings>(
      stream: player.stream.spectrum,
      initial: player.state.spectrum,
      builder: (context, spectrum) => RackEnvironment(
        taps: (f, instance, side) =>
            player.stream.tap(f, instance: instance, side: side),
        spectrum: spectrum,
        loudness: player.stream.loudnessMeter,
        child: SignalChainView(
          rack: rack,
          footer: ListenableBuilder(
            listenable: Listenable.merge([rack, normalizer]),
            builder: (context, _) => LoudnessPanel(
              meterOn: rack.meterOn,
              onMeterChanged: rack.setMeter,
              readings: player.stream.loudnessMeter,
              scan: normalizer.lastScan,
              normalizationOn: normalizer.enabled,
              appliedGainDb: normalizer.appliedGainDb,
              targetLufs: normalizer.targetLufs,
              bypassed: rack.bypass,
            ),
          ),
        ),
      ),
    );
  }
}

/// The rack: a header with the global bypass and "Add stage", the quick
/// editor tiles, then the chain from input to output, reorderable by
/// drag. [footer] goes under the output (the loudness panel).
class SignalChainView extends StatelessWidget {
  final RackController rack;
  final Widget? footer;

  const SignalChainView({super.key, required this.rack, this.footer});

  Future<void> _add(BuildContext context) async {
    final e = await AddStageSheet.show(context);
    if (e != null) rack.add(e);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rack,
      builder: (context, _) {
        final stages = rack.chain.stages;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  Tokens.s20, Tokens.s8, Tokens.s20, 0),
              sliver: SliverList.list(children: [
                const SectionHeader('Quick editors'),
                _QuickTiles(rack: rack),
                const SizedBox(height: Tokens.s24),
                _RackHeader(rack: rack, onAdd: () => _add(context)),
                if (rack.error != null) _ErrorBanner(rack: rack),
                const _Node(label: 'INPUT', detail: 'Decoded audio'),
              ]),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.s20),
              sliver: stages.isEmpty
                  ? SliverToBoxAdapter(
                      child: _EmptyRack(onAdd: () => _add(context)))
                  : SliverReorderableList(
                      itemCount: stages.length,
                      onReorderItem: rack.move,
                      proxyDecorator: (child, _, _) => Material(
                        type: MaterialType.transparency,
                        child: child,
                      ),
                      itemBuilder: (context, i) => StageTile(
                        key: ValueKey(stages[i].id),
                        rack: rack,
                        id: stages[i].id,
                        index: i,
                      ),
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  Tokens.s20, 0, Tokens.s20, Tokens.s32),
              sliver: SliverList.list(children: [
                const _Node(
                    label: 'OUTPUT', detail: 'Then volume and the device'),
                if (footer != null) ...[
                  const SizedBox(height: Tokens.s24),
                  const SectionHeader('Loudness'),
                  footer!,
                ],
              ]),
            ),
          ],
        );
      },
    );
  }
}

class _RackHeader extends StatelessWidget {
  final RackController rack;
  final VoidCallback onAdd;
  const _RackHeader({required this.rack, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final n = rack.chain.length;
    final on = rack.chain.effects.where((e) => e.enabled).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Signal chain', style: Tokens.heading),
                const SizedBox(height: 2),
                Text(
                  n == 0
                      ? 'No stages'
                      : '$n ${n == 1 ? 'stage' : 'stages'}, $on on. '
                          'Drag to reorder.',
                  style: Tokens.caption,
                ),
              ],
            ),
          ),
          _PillButton(
            key: const ValueKey('rack-bypass'),
            icon: Icons.compare_arrows_rounded,
            label: rack.bypass ? 'Bypassed' : 'Bypass',
            active: rack.bypass,
            tooltip: 'Hear the chain off and on',
            onTap: () => rack.setBypass(!rack.bypass),
          ),
          const SizedBox(width: Tokens.s8),
          _PillButton(
            key: const ValueKey('rack-add'),
            icon: Icons.add_rounded,
            label: 'Add stage',
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final String? tooltip;
  final VoidCallback onTap;
  const _PillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Tokens.onAccent : Tokens.fg;
    final button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: Tokens.squircle(Tokens.rSm),
        child: Ink(
          height: Tokens.controlH,
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
          decoration: ShapeDecoration(
            color: active ? Tokens.amber : Tokens.surface2,
            shape: Tokens.squircle(Tokens.rSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: Tokens.s6),
              Text(label, style: Tokens.label.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class _ErrorBanner extends StatelessWidget {
  final RackController rack;
  const _ErrorBanner({required this.rack});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('rack-error'),
      margin: const EdgeInsets.only(bottom: Tokens.s8),
      padding: const EdgeInsets.fromLTRB(
          Tokens.s12, Tokens.s8, Tokens.s4, Tokens.s8),
      decoration: ShapeDecoration(
        color: Tokens.red.withValues(alpha: 0.14),
        shape: Tokens.squircle(Tokens.rSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Tokens.red),
          const SizedBox(width: Tokens.s8),
          Expanded(child: Text(rack.error!, style: Tokens.label)),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: rack.clearError,
            icon: const Icon(Icons.close_rounded,
                size: 16, color: Tokens.fgDim),
          ),
        ],
      ),
    );
  }
}

/// The ends of the chain, joined to the stages by the signal line.
class _Node extends StatelessWidget {
  final String label;
  final String detail;
  const _Node({required this.label, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.s4),
      child: Row(
        children: [
          const SizedBox(width: Tokens.s16),
          Container(
            width: 8,
            height: 8,
            decoration: const ShapeDecoration(
              color: Tokens.accentDim,
              shape: CircleBorder(),
            ),
          ),
          const SizedBox(width: Tokens.s12),
          Text(label,
              style: Tokens.caption.copyWith(
                letterSpacing: 1.2,
                color: Tokens.fgDim,
              )),
          const SizedBox(width: Tokens.s8),
          Text(detail, style: Tokens.caption),
        ],
      ),
    );
  }
}

class _EmptyRack extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyRack({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Tokens.s4),
      padding: const EdgeInsets.all(Tokens.s20),
      decoration: ShapeDecoration(
        shape: Tokens.squircle(Tokens.rMd,
            side: const BorderSide(color: Tokens.line2)),
      ),
      child: Column(
        children: [
          const Text('The audio plays as decoded.', style: Tokens.body),
          const SizedBox(height: Tokens.s4),
          const Text('Add a stage, or open a quick editor above.',
              style: Tokens.caption),
          const SizedBox(height: Tokens.s12),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add stage'),
            style: TextButton.styleFrom(
              foregroundColor: Tokens.accent,
              textStyle: Tokens.label,
            ),
          ),
        ],
      ),
    );
  }
}

/// The featured effects as tiles: one tap opens the first stage of that
/// filter in its quick editor, adding the stage first when the chain has
/// none.
class _QuickTiles extends StatelessWidget {
  final RackController rack;
  const _QuickTiles({required this.rack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kFeaturedCatalog.length,
        separatorBuilder: (_, _) => const SizedBox(width: Tokens.s12),
        itemBuilder: (context, i) {
          final d = kFeaturedCatalog[i];
          final first = rack.chain.stages
              .where((s) => s.effect.filter == d.filter)
              .firstOrNull;
          return SizedBox(
            width: 112,
            child: GridCard(
              key: ValueKey('quick-${d.name}'),
              icon: d.icon,
              title: d.title,
              active: first?.effect.enabled ?? false,
              onTap: () => openQuickEditor(context, rack, d.filter),
            ),
          );
        },
      ),
    );
  }
}

/// Opens the quick editor of the first [filter] stage, adding one at the
/// end of the chain when there is none.
void openQuickEditor(
  BuildContext context,
  RackController rack,
  AudioFilter filter,
) {
  final d = descriptorOf(filter)!;
  final id = rack.chain.stages
          .where((s) => s.effect.filter == filter)
          .firstOrNull
          ?.id ??
      rack.add(d.create());
  // Open in the rack too, so the editor gets its meters.
  if (!rack.isExpanded(id)) rack.toggleExpanded(id);
  final env = RackEnvironment.maybeOf(context);
  final screen = QuickEditorScreen(rack: rack, id: id);
  Navigator.of(context).push(fadeSlidePageRoute(env == null
      ? screen
      : RackEnvironment(
          taps: env.taps,
          spectrum: env.spectrum,
          loudness: env.loudness,
          child: screen,
        )));
}

/// A featured stage on its own page: power, the stage editor, and where
/// the stage sits in the chain.
class QuickEditorScreen extends StatelessWidget {
  final RackController rack;
  final int id;
  const QuickEditorScreen({super.key, required this.rack, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: rack,
          builder: (context, _) {
            final stage = rack.chain.stage(id);
            final title = stage == null ? 'Removed' : stageTitle(stage.effect);
            return Column(
              children: [
                BackBar(
                  title: title,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: stage == null
                      ? const Center(
                          child: Text('This stage is no longer in the chain.',
                              style: Tokens.caption))
                      : SectionBody(children: [
                          _Card(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Tokens.s16),
                            child: SwitchRow(
                              label: 'Effect',
                              subtitle: 'Stage ${rack.chain.indexOf(id) + 1} '
                                  'of ${rack.chain.length}. '
                                  '${stageSubtitle(stage.effect)}',
                              value: stage.effect.enabled,
                              onChanged: (on) => rack.setEnabled(id, on),
                            ),
                          ),
                          _Card(child: StageEditor(rack: rack, id: id)),
                        ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({
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
