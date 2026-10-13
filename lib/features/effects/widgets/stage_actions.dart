import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../rack_catalog.dart';
import '../rack_controller.dart';

/// What the stage menu (the more button, right-click, long press) can do.
enum StageAction {
  power,
  duplicate,
  moveUp,
  moveDown,
  addBefore,
  addAfter,
  remove,
}

/// The menu of stage [id] in its chain position.
List<StudioMenuItem<StageAction>> stageMenuItems(RackController rack, int id) {
  final stage = rack.chain.stage(id);
  if (stage == null) return const [];
  final index = rack.chain.indexOf(id);
  final on = stage.effect.enabled;
  return [
    StudioMenuItem(
      value: StageAction.power,
      label: on ? 'Switch off' : 'Switch on',
      icon: Icons.power_settings_new_rounded,
    ),
    const StudioMenuItem(
      value: StageAction.duplicate,
      label: 'Duplicate',
      icon: Icons.copy_rounded,
    ),
    StudioMenuItem(
      value: StageAction.moveUp,
      label: 'Move up',
      icon: Icons.arrow_upward_rounded,
      enabled: index > 0,
    ),
    StudioMenuItem(
      value: StageAction.moveDown,
      label: 'Move down',
      icon: Icons.arrow_downward_rounded,
      enabled: index < rack.chain.length - 1,
    ),
    const StudioMenuItem(
      value: StageAction.addBefore,
      label: 'Add a stage before',
      icon: Icons.vertical_align_top_rounded,
    ),
    const StudioMenuItem(
      value: StageAction.addAfter,
      label: 'Add a stage after',
      icon: Icons.vertical_align_bottom_rounded,
    ),
    const StudioMenuItem(
      value: StageAction.remove,
      label: 'Remove',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    ),
  ];
}

/// Opens the menu of stage [id] at [position] (a context menu on pointer,
/// a bottom sheet on touch) and returns the action picked.
Future<StageAction?> showStageMenu(
  BuildContext context,
  RackController rack,
  int id, {
  Offset? position,
}) {
  final stage = rack.chain.stage(id);
  return showStudioMenu<StageAction>(
    context,
    items: stageMenuItems(rack, id),
    position: position,
    title: stage == null ? null : stageTitle(stage.effect),
  );
}

/// The global centre of [context]'s box, where a menu opened from a
/// button should appear.
Offset? centreOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(box.size.center(Offset.zero));
}
