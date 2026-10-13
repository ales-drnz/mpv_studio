import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import 'console_log_view.dart';

/// The log levels the filter offers, most severe first.
const kConsoleLevels = [
  LogLevel.error,
  LogLevel.warn,
  LogLevel.info,
  LogLevel.v,
  LogLevel.debug,
  LogLevel.trace,
];

/// The search field and the level filter, under the Console title.
class ConsoleFilterBar extends StatelessWidget {
  const ConsoleFilterBar({
    super.key,
    required this.search,
    required this.onSearch,
    required this.level,
    required this.onLevel,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final LogLevel level;
  final ValueChanged<LogLevel> onLevel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s4),
      child: Row(
        children: [
          Expanded(
            child: _SearchField(controller: search, onChanged: onSearch),
          ),
          const SizedBox(width: Tokens.s8),
          _LevelButton(level: level, onLevel: onLevel),
        ],
      ),
    );
  }
}

/// The level filter: a button naming the level, opening a menu (a sheet on
/// touch) of the levels.
class _LevelButton extends StatelessWidget {
  const _LevelButton({required this.level, required this.onLevel});

  final LogLevel level;
  final ValueChanged<LogLevel> onLevel;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final picked = await showStudioMenu<LogLevel>(
      context,
      title: 'Show log lines down to',
      position: box?.localToGlobal(box.size.bottomLeft(Offset.zero)),
      items: [
        for (final l in kConsoleLevels)
          StudioMenuItem(
            value: l,
            label: logLevelLabel(l),
            icon: l == level ? Icons.check_rounded : null,
          ),
      ],
    );
    if (picked != null) onLevel(picked);
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    return Tooltip(
      message: 'Log level',
      child: OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.filter_list_rounded, size: 18),
        label: Text(logLevelLabel(level)),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, layout.minTap),
          foregroundColor: Tokens.fg,
          side: BorderSide(color: Tokens.line2),
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
        ),
      ),
    );
  }
}

/// The log search box. Filters the scrollback live; a clear button shows
/// once there is a query.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    return Container(
      constraints: BoxConstraints(minHeight: layout.minTap),
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.shape(Tokens.rSm),
      ),
      padding: const EdgeInsets.only(left: Tokens.s12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: Tokens.fgFaint),
          const SizedBox(width: Tokens.s8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: Tokens.body,
              cursorColor: Tokens.accent,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search the log',
                hintStyle: Tokens.caption,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: Tokens.s8)
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: Tokens.fgFaint,
                    constraints: BoxConstraints.tightFor(
                      width: layout.minTap,
                      height: layout.minTap,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The command field: prompt, text, and a run button.
class ConsoleInput extends StatelessWidget {
  const ConsoleInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onTap,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    return Container(
      constraints: BoxConstraints(minHeight: layout.minTap),
      padding: const EdgeInsets.only(left: Tokens.s12),
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.shape(Tokens.rSm),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Text(
              '›',
              style: TextStyle(color: Tokens.accent, fontSize: 16),
            ),
          ),
          const SizedBox(width: Tokens.s8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(
                fontFamily: Tokens.mono,
                fontSize: 13,
                color: Tokens.fg,
              ),
              cursorColor: Tokens.accent,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.send,
              // The page's tap region owns closing; tapping a suggestion
              // must not drop the focus first.
              onTapOutside: (_) {},
              onTap: onTap,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'mpv command, or help',
                hintStyle: Tokens.caption,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => IconButton(
              tooltip: 'Run',
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => onSubmitted(value.text),
              icon: const Icon(Icons.keyboard_return_rounded, size: 18),
              color: Tokens.accent,
              constraints: BoxConstraints.tightFor(
                width: layout.minTap,
                height: layout.minTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
