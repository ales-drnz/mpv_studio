import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/focus_ring.dart';
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
    // Content on the selection fill is graphite in both themes. Text keeps
    // its full tone (4.5:1 or more); only glyphs of an off stage fade.
    final ink = selected ? Tokens.onAccentContainer : null;
    final lit = ink ?? Tokens.accent;
    final faint = ink ?? Tokens.fgFaint;
    final faintGlyph = ink?.withValues(alpha: 0.8) ?? Tokens.fgFaint;

    final handleIcon = SizedBox.square(
      dimension: layout.minTap,
      child: Icon(
        Icons.drag_indicator_rounded,
        size: Tokens.iconMd,
        color: faintGlyph,
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
          width: 24,
          child: Text(
            '${index + 1}'.padLeft(2, '0'),
            style: Tokens.numeric.copyWith(color: live ? lit : faint),
          ),
        ),
        const SizedBox(width: Tokens.s8),
        Icon(stageIcon(e), size: Tokens.iconMd, color: live ? lit : faintGlyph),
        const SizedBox(width: Tokens.s12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Two lines before an ellipsis: beside a tag a narrow
                    // chain cut the name ("Loudness met…").
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
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
                  // A description in words: the sans caption, mono being
                  // for figures and filter names.
                  style: Tokens.caption.copyWith(color: faint),
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
          color: on ? lit : faintGlyph,
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

    // The ink spans the whole header, the handle included, so the hover
    // and the splash fill the tile edge to edge and the tile's clip gives
    // them its rounded corners. A tap on the handle does nothing.
    final ring = FocusRing(
      shape: Tokens.shape(open ? Tokens.rLg : Tokens.rMd),
      inside: true,
      child: InkWell(
        key: ValueKey('stage-header-$id'),
        customBorder: Tokens.shape(open ? Tokens.rLg : Tokens.rMd),
        onTap: onTap,
        // The header's own button below carries the tap for assistive tech.
        excludeFromSemantics: true,
        child: Row(
          children: [
            GestureDetector(onTap: () {}, child: handle),
            Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                expanded: inline ? open : null,
                label: '$title, ${on ? 'on' : 'off'}',
                onTap: onTap,
                child: StudioMenuRegion<StageAction>(
                  title: title,
                  items: () => stageMenuItems(rack, id),
                  onSelected: onAction,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: layout.minTap),
                    child: body,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final header = Focus(
      // Keys on the focused header: Alt+Up and Alt+Down move the stage,
      // Delete removes it (with an undo). Not a stop of its own.
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        final alt = HardwareKeyboard.instance.isAltPressed;
        final last = rack.chain.length - 1;
        final action = switch (key) {
          LogicalKeyboardKey.arrowUp when alt && index > 0 =>
            StageAction.moveUp,
          LogicalKeyboardKey.arrowDown when alt && index < last =>
            StageAction.moveDown,
          LogicalKeyboardKey.delete when !_modified() => StageAction.remove,
          _ => null,
        };
        if (action == null) return KeyEventResult.ignored;
        onAction(action);
        return KeyEventResult.handled;
      },
      child: ring,
    );

    // An off stage reads by its dim title and glyphs and the missing
    // state bar, not by fading the whole tile (its captions would drop
    // under 4.5:1).
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Tokens.s4),
      decoration: ShapeDecoration(
        color: selected ? Tokens.accentContainer : Tokens.surface,
        // An open stage holds a whole editor: a card's radius.
        shape: Tokens.shape(open ? Tokens.rLg : Tokens.rMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // The state bar: a pill inset from the corners, so their arcs
          // never clip it.
          Positioned(
            left: Tokens.s4,
            top: Tokens.s8,
            bottom: Tokens.s8,
            width: Tokens.s4,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                // A meter's amber vanishes on the selection grey (1.1:1):
                // there it takes the selection's ink like the rest.
                color: !live
                    ? Colors.transparent
                    : meter && !selected
                    ? Tokens.amber
                    : lit,
                shape: Tokens.pill,
              ),
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
    );
  }
}

/// Whether a modifier is held: Delete with one is someone else's key.
bool _modified() {
  final keys = HardwareKeyboard.instance;
  return keys.isControlPressed ||
      keys.isMetaPressed ||
      keys.isAltPressed ||
      keys.isShiftPressed;
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
