import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
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
/// dimmed, and a meter stage is tagged as one. Right-click (pointer) and
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

    final handleIcon = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s8),
      child: SizedBox(
        height: layout.minTap,
        child: Icon(
          Icons.drag_indicator_rounded,
          size: 18,
          color: Tokens.fgFaint,
        ),
      ),
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
          width: 22,
          child: Text(
            '${index + 1}'.padLeft(2, '0'),
            style: Tokens.numeric.copyWith(
              color: live ? Tokens.accent : Tokens.fgFaint,
            ),
          ),
        ),
        const SizedBox(width: Tokens.s8),
        Icon(
          stageIcon(e),
          size: 18,
          color: live ? Tokens.accent : Tokens.fgFaint,
        ),
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
                          color: on ? Tokens.fg : Tokens.fgDim,
                        ),
                      ),
                    ),
                    if (meter) const _Tag('METER'),
                    if (e is RawAudioEffect) const _Tag('RAW'),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  stageSubtitle(e),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tokens.caption.copyWith(fontFamily: Tokens.mono),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          key: ValueKey('stage-power-$id'),
          tooltip: on ? 'Switch off' : 'Switch on',
          onPressed: () => powerStage(rack, id, !on),
          icon: Icon(
            Icons.power_settings_new_rounded,
            size: 18,
            color: on ? Tokens.accent : Tokens.fgFaint,
          ),
        ),
        Builder(
          builder: (context) => IconButton(
            key: ValueKey('stage-menu-$id'),
            tooltip: 'Stage actions',
            onPressed: () => _menu(context, centreOf(context)),
            icon: Icon(Icons.more_vert_rounded, size: 18, color: Tokens.fgDim),
          ),
        ),
        if (inline)
          Padding(
            padding: const EdgeInsets.only(right: Tokens.s8),
            child: Icon(
              open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
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
          color: open || selected ? Tokens.surface2 : Tokens.surface,
          shape: Tokens.squircle(
            Tokens.rMd,
            side: selected
                ? BorderSide(color: Tokens.accentDim)
                : BorderSide.none,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: live
                    ? (meter ? Tokens.amber : Tokens.accent)
                    : Colors.transparent,
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

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: Tokens.s8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: ShapeDecoration(
        color: Tokens.surface3,
        shape: Tokens.squircle(4),
      ),
      child: Text(
        text,
        style: Tokens.caption.copyWith(
          fontSize: 9.5,
          letterSpacing: 0.6,
          color: Tokens.fgDim,
        ),
      ),
    );
  }
}
