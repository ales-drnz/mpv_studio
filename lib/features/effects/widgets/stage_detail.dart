import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../rack_catalog.dart';
import '../rack_controller.dart';
import '../stage_presets.dart';
import 'rack_parts.dart';
import 'stage_actions.dart';
import 'stage_editor.dart';

/// One stage on its own, for the split and detail layouts: its power and
/// place in the chain, then the [StageEditor], scrolling by itself.
///
/// With [showHeader] it heads itself with the stage title, the stage menu
/// and a close button (the split layout); the detail layout puts the
/// title in the page header instead.
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
                    child: Semantics(
                      header: true,
                      child: Text(
                        stageTitle(e),
                        style: Tokens.heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) => IconButton(
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
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: Tokens.fgDim,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('detail-close'),
                    tooltip: 'Close the editor',
                    onPressed: onClose,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Tokens.fgDim,
                    ),
                  ),
                ],
              ),
            ),
          RackCard(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
            child: SwitchRow(
              label: 'Effect',
              subtitle:
                  'Stage ${rack.chain.indexOf(id) + 1} of '
                  '${rack.chain.length}. ${stageSubtitle(e)}',
              value: e.enabled,
              onChanged: (on) => powerStage(rack, id, on),
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
