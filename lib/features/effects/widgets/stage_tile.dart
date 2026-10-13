import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/round_icon_button.dart';
import '../rack_catalog.dart';
import '../rack_controller.dart';
import '../stage_presets.dart';
import 'stage_actions.dart';
import 'stage_editor.dart';

/// One module of the rack: a drag handle, its slot number, the filter, a
/// power button and the more button. With [inline] an open stage unfolds
/// its [StageEditor] below; otherwise the page shows the editor elsewhere
/// and the tile marks the stage being edited as [selected].
///
/// Switched-on stages carry an accent stripe on the signal side, so the
/// live path reads down the rack at a glance; a stage that is off is
/// dimmed, and a meter stage is tagged as one. The stage being edited
/// beside the chain is filled with the secondary selection. Right-click (pointer) and
/// long press (touch) open the stage menu. The handle drags at once with
/// a pointer, and after a long press on touch, so a thumb scrolling the
/// rack never moves a stage by accident.
class StageTile extends StatelessWidget {
  final RackController rack;
  final int id;
  final int index;
  final bool inline;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<StageAction> onAction;

  const StageTile({
    super.key,
    required this.rack,
    required this.id,
    required this.index,
    required this.onTap,
    required this.onAction,
    this.inline = true,
    this.selected = false,
  });

  Future<void> _menu(BuildContext context, Offset? at) async {
    final picked = await showStageMenu(context, rack, id, position: at);
    if (picked != null) onAction(picked);
  }

  @override
  Widget build(BuildContext context) {
    final stage = rack.chain.stage(id);
    if (stage == null) return const SizedBox.shrink();
    final layout = context.layout;
    final e = stage.effect;
    final open = inline && rack.isExpanded(id);
    final on = e.enabled;
    final live = on && (!rack.bypass || isMeterStage(e));
    final meter = isMeterStage(e);
    final title = stageTitle(e);
    // Content on the selection fill is graphite in both themes.
    final ink = selected ? Tokens.onAccentContainer : null;
    final lit = ink ?? Tokens.accent;
    final faint = ink?.withValues(alpha: 0.6) ?? Tokens.fgFaint;

    final handleIcon = SizedBox.square(
      dimension: layout.minTap,
      child: Icon(Icons.drag_indicator_rounded, size: 18, color: faint),
    );
    final handle = Semantics(
      label: 'Reorder $title',
      child: layout.isTouch
          ? ReorderableDelayedDragStartListener(index: index, child: handleIcon)
          : ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Tooltip(message: 'Drag to reorder', child: handleIcon),
              ),
            ),
    );

    final body = Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            '${index + 1}'.padLeft(2, '0'),
            style: Tokens.numeric.copyWith(color: live ? lit : faint),
          ),
        ),
        const SizedBox(width: Tokens.s8),
        Icon(stageIcon(e), size: 18, color: live ? lit : faint),
        const SizedBox(width: Tokens.s12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tokens.body.copyWith(
                          color: ink ?? (on ? Tokens.fg : Tokens.fgDim),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (meter) _Tag('Meter', selected: selected),
                    if (e is RawAudioEffect) _Tag('Raw', selected: selected),
                  ],
                ),
                Text(
                  stageSubtitle(e),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tokens.caption.copyWith(
                    fontFamily: Tokens.mono,
                    color: faint,
                  ),
                ),
              ],
            ),
          ),
        ),
        RoundIconButton(
          key: ValueKey('stage-power-$id'),
          icon: Icons.power_settings_new_rounded,
          size: 20,
          tooltip: on ? 'Switch off' : 'Switch on',
          toggled: on,
          color: on ? lit : faint,
          onTap: () => powerStage(rack, id, !on),
        ),
        Builder(
          builder: (context) => RoundIconButton(
            key: ValueKey('stage-menu-$id'),
            icon: Icons.more_vert_rounded,
            size: 20,
            tooltip: 'Stage actions',
            color: ink ?? Tokens.fgDim,
            onTap: () => _menu(context, centreOf(context)),
          ),
        ),
        if (inline)
          Padding(
            padding: const EdgeInsets.only(right: Tokens.s8),
            child: Icon(
              open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20,
              color: Tokens.fgFaint,
            ),
          )
        else
          const SizedBox(width: Tokens.s4),
      ],
    );

    final header = Row(
      children: [
        handle,
        Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            expanded: inline ? open : null,
            label: '$title, ${on ? 'on' : 'off'}',
            child: StudioMenuRegion<StageAction>(
              title: title,
              items: () => stageMenuItems(rack, id),
              onSelected: onAction,
              child: InkWell(
                key: ValueKey('stage-header-$id'),
                customBorder: Tokens.shape(open ? Tokens.rLg : Tokens.rMd),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: layout.minTap),
                  child: body,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: on ? 1 : 0.72,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: Tokens.s4),
        decoration: ShapeDecoration(
          color: selected ? Tokens.accentContainer : Tokens.surface,
          // An open stage holds a whole editor: a card's radius.
          shape: Tokens.shape(open ? Tokens.rLg : Tokens.rMd),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: live ? (meter ? Tokens.amber : lit) : Colors.transparent,
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  if (open)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.s16,
                        0,
                        Tokens.s16,
                        Tokens.s12,
                      ),
                      child: StageEditor(rack: rack, id: id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small pill naming the kind of stage (meter, raw).
class _Tag extends StatelessWidget {
  final String text;
  final bool selected;
  const _Tag(this.text, {required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: Tokens.s8),
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s8),
      decoration: ShapeDecoration(
        color: selected
            ? Tokens.onAccentContainer.withValues(alpha: 0.12)
            : Tokens.surface3,
        shape: Tokens.pill,
      ),
      child: Text(
        text,
        style: Tokens.caption.copyWith(
          color: selected ? Tokens.onAccentContainer : Tokens.fgDim,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
