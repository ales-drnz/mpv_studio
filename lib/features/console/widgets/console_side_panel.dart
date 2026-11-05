import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/focus_ring.dart';
import '../../../ui/widgets/section_header.dart';
import '../command_catalog.dart';

/// The Console's side column on a wide window: the command being typed,
/// with its arguments and what it does, and the commands run, newest
/// first, which a tap puts back in the field.
class ConsoleSidePanel extends StatelessWidget {
  const ConsoleSidePanel({
    super.key,
    required this.history,
    required this.active,
    required this.onPick,
  });

  /// The lines run, oldest first.
  final List<String> history;

  /// The command the line being typed starts with, if known.
  final MpvCommand? active;
  final ValueChanged<String> onPick;

  /// How many commands it lists.
  static const int recent = 30;

  @override
  Widget build(BuildContext context) {
    final command = active;
    final lines = history.reversed.take(recent).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: Tokens.s16),
      children: [
        const SectionHeader('Command'),
        Container(
          padding: const EdgeInsets.all(Tokens.s16),
          decoration: ShapeDecoration(
            color: Tokens.surface,
            shape: Tokens.shape(Tokens.rLg),
          ),
          child: command == null
              ? Text(
                  'Type a command or a property: its arguments and what it '
                  'does show here.',
                  style: Tokens.label,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        command.name,
                        command.signature,
                      ].where((s) => s.isNotEmpty).join(' '),
                      style: Tokens.numericLg,
                    ),
                    const SizedBox(height: Tokens.s8),
                    Text(command.doc, style: Tokens.body),
                  ],
                ),
        ),
        const SizedBox(height: Tokens.s24),
        const SectionHeader('Recent commands'),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
            child: Text('The commands you run show here.', style: Tokens.label),
          ),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.s4),
            child: Material(
              color: Tokens.surface,
              shape: Tokens.shape(Tokens.rMd),
              child: FocusRing(
                shape: Tokens.shape(Tokens.rMd),
                inside: true,
                child: InkWell(
                  onTap: () => onPick(line),
                  customBorder: Tokens.shape(Tokens.rMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Tokens.s16,
                      vertical: Tokens.s12,
                    ),
                    child: Text(
                      line,
                      style: Tokens.numeric.copyWith(color: Tokens.fg),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
