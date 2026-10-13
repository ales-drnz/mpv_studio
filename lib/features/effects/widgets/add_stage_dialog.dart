import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../generated/filter_catalog.dart';
import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../rack_catalog.dart';
import '../stage_presets.dart';

/// Opens the catalog to add a stage from (a dialog on medium and wider
/// windows, a bottom sheet on compact ones) and returns the stage picked.
Future<AudioEffect?> showAddStage(BuildContext context) =>
    showStudioDialog<AudioEffect>(
      context,
      title: 'Add stage',
      maxWidth: 560,
      builder: (context) => const AddStageCatalog(),
    );

/// The catalog: a search over every filter, grouped like the library's
/// README, plus a raw lavfi stage. Pops the new stage, switched off when
/// it needs an option filled in first.
class AddStageCatalog extends StatefulWidget {
  const AddStageCatalog({super.key});

  @override
  State<AddStageCatalog> createState() => _AddStageCatalogState();
}

class _AddStageCatalogState extends State<AddStageCatalog> {
  String _query = '';

  static const _advancedTitle = 'Advanced (mandatory options)';

  bool _match(FilterDescriptor d) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return d.name.contains(q) ||
        d.title.toLowerCase().contains(q) ||
        (kFeaturedSubtitles[d.filter]?.toLowerCase().contains(q) ?? false);
  }

  List<(String, List<FilterDescriptor>)> _groups() {
    final out = <(String, List<FilterDescriptor>)>[
      ('Featured', kFeaturedCatalog.where(_match).toList()),
      for (final c in kFilterCategories)
        (
          c.title,
          kFilterCatalog
              .where((d) => d.category == c.slug && !d.advanced && _match(d))
              .toList(),
        ),
      (
        _advancedTitle,
        kFilterCatalog.where((d) => d.advanced && _match(d)).toList(),
      ),
    ];
    return [
      for (final g in out)
        if (g.$2.isNotEmpty) g,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final groups = _groups();
    final q = _query.trim().toLowerCase();
    final showRaw = q.isEmpty || 'raw lavfi'.contains(q);
    // The dialog and the sheet scroll their content as a whole; a height
    // that fits what the keyboard leaves (less the title, the handle and
    // the padding around) keeps the search field in place over a list
    // that is the only thing scrolling.
    final mq = MediaQuery.of(context);
    final room = (mq.size.height - mq.viewInsets.bottom) * 0.9 - 120;
    final height = room.clamp(120.0, 560.0);

    final entries = <Widget>[
      if (showRaw)
        _Entry(
          id: 'raw',
          icon: Icons.code_rounded,
          title: 'Raw lavfi',
          subtitle: 'Any lavfi filter, written by hand',
          onTap: () =>
              Navigator.of(context).pop(const RawAudioEffect('lavfi-anull')),
        ),
      for (final (title, list) in groups) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.s8,
            Tokens.s16,
            Tokens.s8,
            Tokens.s4,
          ),
          child: Semantics(
            header: true,
            child: Text(title.toUpperCase(), style: Tokens.caption),
          ),
        ),
        for (final d in list)
          _Entry(
            id: d.name,
            icon: d.icon,
            title: d.title,
            subtitle: kFeaturedSubtitles[d.filter] ?? d.wire,
            onTap: () {
              final e = d.create();
              Navigator.of(
                context,
              ).pop(stageReady(e) ? e : d.setEnabled(e, false));
            },
          ),
      ],
      if (!showRaw && groups.isEmpty)
        Padding(
          padding: const EdgeInsets.all(Tokens.s24),
          child: Text(
            'No filter matches "${_query.trim()}".',
            style: Tokens.caption,
            textAlign: TextAlign.center,
          ),
        ),
    ];

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: BoxConstraints(minHeight: layout.minTap),
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
            decoration: ShapeDecoration(
              color: Tokens.surface2,
              shape: Tokens.shape(Tokens.rSm),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 16, color: Tokens.fgFaint),
                const SizedBox(width: Tokens.s8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('add-stage-search'),
                    autofocus: layout.isPointer,
                    onChanged: (v) => setState(() => _query = v),
                    style: Tokens.body,
                    cursorColor: Tokens.accent,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
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
          const SizedBox(height: Tokens.s4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Tokens.s8),
              children: entries,
            ),
          ),
        ],
      ),
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
        customBorder: Tokens.shape(Tokens.rSm),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.layout.minTap),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.s8,
              vertical: Tokens.s4,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Tokens.accent),
                const SizedBox(width: Tokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: Tokens.body),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tokens.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
