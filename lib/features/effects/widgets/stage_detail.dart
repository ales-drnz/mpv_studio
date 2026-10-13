import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../rack_catalog.dart';
import '../rack_controller.dart';
import '../stage_presets.dart';
import 'rack_parts.dart';
import 'stage_actions.dart';
import 'stage_editor.dart';

/// Where stage [id] sits in the chain, for the editor's subtitle.
String stagePlace(RackController rack, int id) {
  final stage = rack.chain.stage(id);
  if (stage == null) return '';
  return 'Stage ${rack.chain.indexOf(id) + 1} of ${rack.chain.length}. '
      '${stageSubtitle(stage.effect)}';
}

/// The power button of stage [id], lit while it is on.
class StagePowerButton extends StatelessWidget {
  final RackController rack;
  final int id;
  const StagePowerButton({super.key, required this.rack, required this.id});

  @override
  Widget build(BuildContext context) {
    final on = rack.chain.stage(id)?.effect.enabled ?? false;
    return IconButton(
      key: ValueKey('detail-power-$id'),
      tooltip: on ? 'Switch off' : 'Switch on',
      isSelected: on,
      onPressed: () => powerStage(rack, id, !on),
      icon: Icon(
        Icons.power_settings_new_rounded,
        color: on ? Tokens.accent : Tokens.fgFaint,
      ),
    );
  }
}

/// The stage menu button of stage [id].
class StageMenuButton extends StatelessWidget {
  final RackController rack;
  final int id;
  final ValueChanged<StageAction> onAction;
  const StageMenuButton({
    super.key,
    required this.rack,
    required this.id,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: ValueKey('detail-menu-$id'),
      tooltip: 'Stage actions',
      onPressed: () async {
        final picked = await showStageMenu(
          context,
          rack,
          id,
          position: centreOf(context),
        );
        if (picked != null) onAction(picked);
      },
      icon: Icon(Icons.more_vert_rounded, color: Tokens.fgDim),
    );
  }
}

/// One stage on its own, for the split and detail layouts: the
/// [StageEditor] in a card, scrolling by itself.
///
/// With [showHeader] it heads itself with the stage title, its place in
/// the chain, power, the stage menu and a close button (the split
/// layout); the detail layout puts those in the page header instead, so
/// the editor starts right under it.
class StageDetail extends StatelessWidget {
  final RackController rack;
  final int id;
  final bool showHeader;
  final VoidCallback onClose;
  final ValueChanged<StageAction> onAction;
  final EdgeInsets padding;

  const StageDetail({
    super.key,
    required this.rack,
    required this.id,
    required this.onClose,
    required this.onAction,
    this.showHeader = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final stage = rack.chain.stage(id);
    if (stage == null) return const SizedBox.shrink();
    final e = stage.effect;
    return SingleChildScrollView(
      key: PageStorageKey('stage-detail-$id'),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.s8),
              child: Row(
                children: [
                  Icon(stageIcon(e), size: 20, color: Tokens.accent),
                  const SizedBox(width: Tokens.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            stageTitle(e),
                            style: Tokens.heading,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          stagePlace(rack, id),
                          style: Tokens.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StagePowerButton(rack: rack, id: id),
                  StageMenuButton(rack: rack, id: id, onAction: onAction),
                  IconButton(
                    key: const ValueKey('detail-close'),
                    tooltip: 'Close the editor',
                    onPressed: onClose,
                    icon: Icon(Icons.close_rounded, color: Tokens.fgDim),
                  ),
                ],
              ),
            ),
          RackCard(
            child: StageEditor(rack: rack, id: id),
          ),
        ],
      ),
    );
  }
}
