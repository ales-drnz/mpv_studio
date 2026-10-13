import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../generated/filter_catalog.dart';
import '../../../ui/tokens.dart';
import '../rack_catalog.dart';
import '../rack_controller.dart';
import 'stage_editor.dart';

/// What the stage menu can do.
enum StageAction { duplicate, moveUp, moveDown, remove }

/// One module of the rack: a drag handle, its slot number, the filter,
/// a power button, a menu and the fold. Open, it shows the [StageEditor].
///
/// Switched-on stages carry an accent stripe on the signal side, so the
/// live path reads down the rack at a glance; a stage that is off is
/// dimmed, and a meter stage is tagged as one.
class StageTile extends StatelessWidget {
  final RackController rack;
  final int id;
  final int index;

  const StageTile({
    super.key,
    required this.rack,
    required this.id,
    required this.index,
  });

  void _onAction(StageAction a) {
    switch (a) {
      case StageAction.duplicate:
        rack.duplicate(id);
      case StageAction.moveUp:
        rack.move(index, index - 1);
      case StageAction.moveDown:
        rack.move(index, index + 1);
      case StageAction.remove:
        rack.remove(id);
    }
  }

  Future<void> _power(bool on) async {
    final e = rack.chain.stage(id)?.effect;
    if (e == null) return;
    // A filter with an empty mandatory option would be refused: start it
    // from its first preset instead.
    final d = descriptorOf(e.filter);
    if (on && !stageReady(e) && d != null && d.presets.isNotEmpty) {
      await applyPreset(rack, id, d, d.presets.first);
      return;
    }
    if (on && !stageReady(e) && !rack.isExpanded(id)) {
      rack.toggleExpanded(id);
      return;
    }
    rack.setEnabled(id, on);
  }

  @override
  Widget build(BuildContext context) {
    final stage = rack.chain.stage(id);
    if (stage == null) return const SizedBox.shrink();
    final e = stage.effect;
    final open = rack.isExpanded(id);
    final on = e.enabled;
    final live = on && (!rack.bypass || isMeterStage(e));
    final meter = isMeterStage(e);
    final last = index == rack.chain.length - 1;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
          Tokens.s4, Tokens.s8, Tokens.s4, Tokens.s8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: EdgeInsets.all(Tokens.s8),
                child: Icon(Icons.drag_indicator_rounded,
                    size: 18, color: Tokens.fgFaint),
              ),
            ),
          ),
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
          Icon(stageIcon(e),
              size: 18, color: live ? Tokens.accent : Tokens.fgFaint),
          const SizedBox(width: Tokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        stageTitle(e),
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
          IconButton(
            key: ValueKey('stage-power-$id'),
            tooltip: on ? 'Switch off' : 'Switch on',
            onPressed: () => _power(!on),
            icon: Icon(
              Icons.power_settings_new_rounded,
              size: 18,
              color: on ? Tokens.accent : Tokens.fgFaint,
            ),
          ),
          PopupMenuButton<StageAction>(
            key: ValueKey('stage-menu-$id'),
            tooltip: 'Stage actions',
            icon: const Icon(Icons.more_vert_rounded,
                size: 18, color: Tokens.fgDim),
            color: Tokens.surface3,
            onSelected: _onAction,
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: StageAction.duplicate, child: Text('Duplicate')),
              if (index > 0)
                const PopupMenuItem(
                    value: StageAction.moveUp, child: Text('Move up')),
              if (!last)
                const PopupMenuItem(
                    value: StageAction.moveDown, child: Text('Move down')),
              const PopupMenuItem(
                  value: StageAction.remove, child: Text('Remove')),
            ],
          ),
          Icon(
            open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            size: 18,
            color: Tokens.fgFaint,
          ),
          const SizedBox(width: Tokens.s4),
        ],
      ),
    );

    return Opacity(
      opacity: on ? 1 : 0.72,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: Tokens.s4),
        decoration: ShapeDecoration(
          color: open ? Tokens.surface2 : Tokens.surface,
          shape: Tokens.squircle(Tokens.rMd),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: ValueKey('stage-header-$id'),
                    onTap: () => rack.toggleExpanded(id),
                    child: header,
                  ),
                ),
                if (open)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Tokens.s16, 0, Tokens.s16, Tokens.s12),
                    child: StageEditor(rack: rack, id: id),
                  ),
              ],
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
      child: Text(text,
          style: Tokens.caption.copyWith(
            fontSize: 9.5,
            letterSpacing: 0.6,
            color: Tokens.fgDim,
          )),
    );
  }
}

/// The catalog to add a stage from: a search over every filter, grouped
/// like the library's README, plus a raw lavfi stage. Pops the new stage.
class AddStageSheet extends StatefulWidget {
  const AddStageSheet({super.key});

  /// Opens the sheet and returns the stage to add, if any.
  static Future<AudioEffect?> show(BuildContext context) =>
      showModalBottomSheet<AudioEffect>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Tokens.surface,
        shape: Tokens.squircle(Tokens.rLg),
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.85,
          child: AddStageSheet(),
        ),
      );

  @override
  State<AddStageSheet> createState() => _AddStageSheetState();
}

class _AddStageSheetState extends State<AddStageSheet> {
  String _query = '';

  static const _advancedTitle = 'Advanced (mandatory options)';

  List<(String, List<FilterDescriptor>)> _groups() {
    bool match(FilterDescriptor d) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return d.name.contains(q) ||
          d.title.toLowerCase().contains(q) ||
          (kFeaturedSubtitles[d.filter]?.toLowerCase().contains(q) ?? false);
    }

    final out = <(String, List<FilterDescriptor>)>[
      ('Featured', kFeaturedCatalog.where(match).toList()),
      for (final c in kFilterCategories)
        (
          c.title,
          kFilterCatalog
              .where((d) => d.category == c.slug && !d.advanced && match(d))
              .toList(),
        ),
      (_advancedTitle, kFilterCatalog.where((d) => d.advanced && match(d)).toList()),
    ];
    return [
      for (final g in out)
        if (g.$2.isNotEmpty) g,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    final showRaw = _query.isEmpty || 'raw lavfi'.contains(_query.toLowerCase());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Tokens.s20, Tokens.s16, Tokens.s20, Tokens.s8),
          child: Row(
            children: [
              const Text('Add stage', style: Tokens.heading),
              const SizedBox(width: Tokens.s16),
              Expanded(
                child: Container(
                  height: Tokens.controlH,
                  padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
                  decoration: ShapeDecoration(
                    color: Tokens.surface2,
                    shape: Tokens.squircle(Tokens.rSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          size: 16, color: Tokens.fgFaint),
                      const SizedBox(width: Tokens.s8),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('add-stage-search'),
                          autofocus: false,
                          onChanged: (v) => setState(() => _query = v),
                          style: Tokens.body,
                          cursorColor: Tokens.accent,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Search filters',
                            hintStyle: Tokens.caption,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                Tokens.s12, 0, Tokens.s12, Tokens.s24),
            children: [
              if (showRaw)
                _Entry(
                  id: 'raw',
                  icon: Icons.code_rounded,
                  title: 'Raw lavfi',
                  subtitle: 'Any lavfi filter, written by hand',
                  onTap: () => Navigator.of(context)
                      .pop(const RawAudioEffect('lavfi-anull')),
                ),
              for (final (title, list) in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Tokens.s8, Tokens.s16, Tokens.s8, Tokens.s4),
                  child: Text(title.toUpperCase(), style: Tokens.caption),
                ),
                for (final d in list)
                  _Entry(
                    id: d.name,
                    icon: d.icon,
                    title: d.title,
                    subtitle: kFeaturedSubtitles[d.filter] ?? d.wire,
                    onTap: () {
                      final e = d.create();
                      // Not ready to play yet: added off, to fill in.
                      Navigator.of(context)
                          .pop(stageReady(e) ? e : d.setEnabled(e, false));
                    },
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Entry({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('add-$id'),
        customBorder: Tokens.squircle(Tokens.rSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Tokens.s8, vertical: Tokens.s8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Tokens.accent),
              const SizedBox(width: Tokens.s12),
              Expanded(child: Text(title, style: Tokens.body)),
              const SizedBox(width: Tokens.s8),
              Flexible(
                child: Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Tokens.caption),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
