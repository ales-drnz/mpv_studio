import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/round_icon_button.dart';
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
    return RoundIconButton(
      key: ValueKey('detail-power-$id'),
      icon: Icons.power_settings_new_rounded,
      tooltip: on ? 'Switch off' : 'Switch on',
      toggled: on,
      color: on ? Tokens.accent : Tokens.fgFaint,
      onTap: () => powerStage(rack, id, !on),
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
    return RoundIconButton(
      key: ValueKey('detail-menu-$id'),
      icon: Icons.more_vert_rounded,
      tooltip: 'Stage actions',
      onTap: () async {
        final picked = await showStageMenu(
          context,
          rack,
          id,
          position: centreOf(context),
        );
        if (picked != null) onAction(picked);
      },
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
              padding: const EdgeInsets.fromLTRB(Tokens.s16, 0, 0, Tokens.s8),
              child: Row(
                children: [
                  Icon(stageIcon(e), size: 20, color: Tokens.fg),
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
                  RoundIconButton(
                    key: const ValueKey('detail-close'),
                    icon: Icons.close_rounded,
                    tooltip: 'Close the editor',
                    onTap: onClose,
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
