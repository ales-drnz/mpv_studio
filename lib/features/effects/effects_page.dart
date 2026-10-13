import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/player_scope.dart';
import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/section_switcher.dart';
import '../../util/reactive.dart';
import 'rack_catalog.dart';
import 'rack_controller.dart';
import 'rack_environment.dart';
import 'rack_mode.dart';
import 'stage_presets.dart';
import 'widgets/add_stage_dialog.dart';
import 'widgets/loudness_panel.dart';
import 'widgets/quick_editors.dart';
import 'widgets/rack_parts.dart';
import 'widgets/stage_actions.dart';
import 'widgets/stage_detail.dart';
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
        pcm: player.stream.pcm,
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

/// The rack page: a header with the global bypass and "Add stage", the
/// quick editors, then the chain from input to output, reorderable by
/// drag. [footer] goes under the output (the loudness panel).
///
/// Where an open stage is edited depends on the room ([RackMode]): in
/// place on pointer windows, beside the chain on wide ones, and on its
/// own over the chain on phones, touch screens and low windows.
class SignalChainView extends StatefulWidget {
  final RackController rack;
  final Widget? footer;

  const SignalChainView({super.key, required this.rack, this.footer});

  @override
  State<SignalChainView> createState() => _SignalChainViewState();
}

class _SignalChainViewState extends State<SignalChainView> {
  /// One key per stage tile, to scroll an opened stage into view.
  final _tiles = <int, GlobalKey>{};

  /// The mode of the last build, for the callbacks.
  RackMode _mode = RackMode.inline;

  RackController get rack => widget.rack;

  @override
  void initState() {
    super.initState();
    // Back on the page with a stage left open: show its controls, as when
    // it was opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final open = rack.focused;
      if (mounted && open != null && _mode == RackMode.inline) {
        _revealNow(open);
      }
    });
  }

  /// Opens stage [id] the way the current mode shows it.
  void _open(int id) {
    if (_mode == RackMode.inline) {
      rack.open(id);
      _reveal(id);
    } else {
      rack.open(id, only: true);
    }
  }

  void _tap(int id) {
    if (_mode == RackMode.inline && rack.isExpanded(id)) {
      rack.toggleExpanded(id);
    } else {
      _open(id);
    }
  }

  /// A quick editor: the first stage of [filter], added at the end of the
  /// chain when there is none.
  void _openFilter(AudioFilter filter) {
    final first = rack.chain.stages
        .where((s) => s.effect.filter == filter)
        .firstOrNull;
    _open(first?.id ?? rack.add(descriptorOf(filter)!.create()));
  }

  Future<void> _add({int? index}) async {
    final e = await showAddStage(context);
    if (e == null || !mounted) return;
    _open(rack.add(e, index: index));
  }

  void _action(int id, StageAction action) {
    final i = rack.chain.indexOf(id);
    final stage = rack.chain.stage(id);
    if (stage == null) return;
    switch (action) {
      case StageAction.power:
        powerStage(rack, id, !stage.effect.enabled);
      case StageAction.duplicate:
        final copy = rack.duplicate(id);
        if (copy != null && rack.isExpanded(copy)) _open(copy);
      case StageAction.moveUp:
        rack.move(i, i - 1);
      case StageAction.moveDown:
        rack.move(i, i + 1);
      case StageAction.addBefore:
        _add(index: i);
      case StageAction.addAfter:
        _add(index: i + 1);
      case StageAction.remove:
        rack.remove(id);
    }
  }

  /// Scrolls stage [id] into view once laid out: the whole tile when it
  /// fits, else its top, so the controls of a stage just opened are on
  /// screen instead of under the bottom edge.
  void _reveal(int id) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealNow(id));
  }

  void _revealNow(int id) {
    final ctx = _tiles[id]?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final box = ctx.findRenderObject();
    final scrollable = Scrollable.maybeOf(ctx);
    if (box is! RenderBox || !box.attached || scrollable == null) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = scrollable.position;
    final atTop = viewport.getOffsetToReveal(box, 0).offset;
    final atBottom = viewport.getOffsetToReveal(box, 1).offset;
    var target = position.pixels;
    if (box.size.height > position.viewportDimension || target > atTop) {
      target = atTop;
    } else if (target < atBottom) {
      target = atBottom;
    }
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 1) return;
    position.animateTo(
      target,
      duration: kNavTransition,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _chain({required bool inline, required bool quick, double end = 0}) {
    final stages = rack.chain.stages;
    final focused = rack.focused;
    return CustomScrollView(
      key: const PageStorageKey('rack-chain'),
      // Chains are short: building every tile lets a stage that opens
      // off screen be found and scrolled to.
      scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(0, Tokens.s8, end, 0),
          sliver: SliverList.list(
            children: [
              if (quick) ...[
                QuickEditors(rack: rack, onOpen: _openFilter),
                const SizedBox(height: Tokens.s16),
              ],
              const RackNode(label: 'Input', detail: 'Decoded audio'),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(right: end),
          sliver: stages.isEmpty
              ? SliverToBoxAdapter(child: EmptyRack(onAdd: _add))
              : SliverReorderableList(
                  itemCount: stages.length,
                  onReorderItem: rack.move,
                  proxyDecorator: (child, _, _) =>
                      Material(type: MaterialType.transparency, child: child),
                  itemBuilder: (context, i) {
                    final id = stages[i].id;
                    return StageTile(
                      key: _tiles.putIfAbsent(id, GlobalKey.new),
                      rack: rack,
                      id: id,
                      index: i,
                      inline: inline,
                      selected: !inline && focused == id,
                      onTap: () => _tap(id),
                      onAction: (a) => _action(id, a),
                    );
                  },
                ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(0, 0, end, Tokens.s32),
          sliver: SliverList.list(
            children: [
              const RackNode(
                label: 'Output',
                detail: 'Then volume and the device',
              ),
              if (widget.footer != null) ...[
                const SizedBox(height: Tokens.s24),
                const SectionHeader('Loudness'),
                widget.footer!,
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rack,
      builder: (context, _) {
        final layout = context.layout;
        return LayoutBuilder(
          builder: (context, c) {
            final gutter = layout.gutter;
            final width = math.min(c.maxWidth - 2 * gutter, Breakpoints.wide);
            final mode = _mode = RackMode.of(layout, width, c.maxHeight);
            _tiles.removeWhere((id, _) => rack.chain.stage(id) == null);
            final focus = mode == RackMode.inline ? null : rack.focused;
            final covering = mode == RackMode.detail && focus != null;

            final Widget content;
            switch (mode) {
              case RackMode.inline:
                content = _chain(inline: true, quick: true);
              case RackMode.detail:
                content = TwoPane(
                  // Never side by side here, even on a wide low window.
                  minDetailWidth: double.infinity,
                  list: _chain(inline: false, quick: true),
                  detail: focus == null
                      ? null
                      : StageDetail(
                          key: ValueKey('detail-$focus'),
                          rack: rack,
                          id: focus,
                          showHeader: false,
                          padding: EdgeInsets.only(
                            top: Tokens.s4,
                            bottom: layout.pagePadding.bottom,
                          ),
                          onClose: rack.closeAll,
                          onAction: (a) => _action(focus, a),
                        ),
                  onCloseDetail: rack.closeAll,
                );
              case RackMode.split:
                content = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: Tokens.s8,
                        bottom: Tokens.s12,
                      ),
                      child: QuickEditors(
                        rack: rack,
                        onOpen: _openFilter,
                        singleRow: true,
                      ),
                    ),
                    Expanded(
                      child: TwoPane(
                        listWidth: RackMode.listWidth,
                        minDetailWidth: RackMode.minDetailWidth,
                        list: _chain(
                          inline: false,
                          quick: false,
                          end: layout.gap,
                        ),
                        detail: focus == null
                            ? null
                            : StageDetail(
                                key: ValueKey('detail-$focus'),
                                rack: rack,
                                id: focus,
                                padding: EdgeInsets.fromLTRB(
                                  layout.gap,
                                  Tokens.s8,
                                  0,
                                  layout.pagePadding.bottom,
                                ),
                                onClose: rack.closeAll,
                                onAction: (a) => _action(focus, a),
                              ),
                        placeholder: const _NoStageOpen(),
                        onCloseDetail: rack.closeAll,
                      ),
                    ),
                  ],
                );
            }

            final stage = focus == null ? null : rack.chain.stage(focus);
            return PageFrame(
              title: covering && stage != null
                  ? stageTitle(stage.effect)
                  : 'Effects',
              onBack: covering ? rack.closeAll : null,
              actions: covering
                  ? [
                      StagePowerButton(rack: rack, id: focus),
                      StageMenuButton(
                        rack: rack,
                        id: focus,
                        onAction: (a) => _action(focus, a),
                      ),
                    ]
                  : [
                      RackHeaderButton(
                        key: const ValueKey('rack-bypass'),
                        icon: Icons.compare_arrows_rounded,
                        label: rack.bypass ? 'Bypassed' : 'Bypass',
                        tooltip: rack.bypass
                            ? 'Play the chain again'
                            : 'Hear the audio without the chain',
                        active: rack.bypass,
                        compact: layout.isCompact,
                        onTap: () => rack.setBypass(!rack.bypass),
                      ),
                      RackHeaderButton(
                        key: const ValueKey('rack-add'),
                        icon: Icons.add_rounded,
                        label: 'Add stage',
                        tooltip: 'Add a stage to the chain',
                        compact: layout.isCompact,
                        onTap: _add,
                      ),
                    ],
              // A low window gives the editor every line it can.
              subtitle: covering && layout.isShort
                  ? null
                  : covering
                  ? stagePlace(rack, focus)
                  : chainSummary(rack, layout),
              scrollable: false,
              maxWidth: mode == RackMode.split
                  ? Breakpoints.wide
                  : Breakpoints.readable,
              padding: EdgeInsets.symmetric(horizontal: gutter),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (rack.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Tokens.s8),
                      child: RackErrorBanner(rack: rack),
                    ),
                  Expanded(child: content),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// The editor side of the split layout with no stage open.
class _NoStageOpen extends StatelessWidget {
  const _NoStageOpen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 28, color: Tokens.fgFaint),
            const SizedBox(height: Tokens.s12),
            Text(
              'Pick a stage to edit it here.',
              style: Tokens.body.copyWith(color: Tokens.fgDim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Tokens.s4),
            Text(
              'The chain stays in view while you edit.',
              style: Tokens.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
