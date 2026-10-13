import 'package:flutter/material.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/tokens.dart';
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
                _Tile(icon: s.icon, title: s.title),
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

/// A square category tile: a centred accent icon over a title.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.squircle(Tokens.rLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.s12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: Tokens.accent),
            const SizedBox(height: Tokens.s12),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Tokens.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
