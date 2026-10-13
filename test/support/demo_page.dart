import 'package:flutter/material.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/widgets/grid_card.dart';
import 'package:mpv_studio/ui/widgets/section_body.dart';
import 'package:mpv_studio/ui/widgets/section_header.dart';

/// A stand-in section page built only from the shared layout pieces
/// ([PageFrame], [ResponsiveGrid], the settings card), so shell tests and
/// goldens show a realistic page without a player behind it.
class DemoPage extends StatelessWidget {
  const DemoPage({super.key, required this.section});

  final Section section;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: section.title,
      actions: [
        IconButton(
          onPressed: () {},
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('page ${section.name}'),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(hintText: 'Filter')),
          const SizedBox(height: 16),
          const SectionHeader('Categories'),
          ResponsiveGrid(
            minTileWidth: 140,
            tileAspectRatio: 1,
            children: [
              for (final s in Section.values)
                GridCard(icon: s.icon, title: s.title, onTap: () {}),
            ],
          ),
          const SizedBox(height: 24),
          const SettingsGroup(
            label: 'Details',
            children: [
              InfoRow(label: 'Sample rate', value: '44.1 kHz'),
              InfoRow(label: 'Format', value: 'FLAC, 16 bit'),
              InfoRow(label: 'Output', value: 'PipeWire'),
            ],
          ),
        ],
      ),
    );
  }
}
