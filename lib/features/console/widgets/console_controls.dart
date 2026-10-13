import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/round_icon_button.dart';
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
    return Tooltip(
      message: 'Log level',
      child: OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.filter_list_rounded, size: 20),
        label: Text(logLevelLabel(level)),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, controlHeightOf(context)),
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
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
    return AppTextField(
      controller: controller,
      onChanged: onChanged,
      hint: 'Search the log',
      semanticLabel: 'Search the log',
      leading: Icon(Icons.search_rounded, size: 20, color: Tokens.fgDim),
      action: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => value.text.isEmpty
            ? const SizedBox(width: Tokens.s12)
            : RoundIconButton(
                tooltip: 'Clear search',
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                icon: Icons.close_rounded,
                size: 20,
              ),
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
    final h = controlHeightOf(context);
    final field = Container(
      constraints: BoxConstraints(minHeight: h),
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
      decoration: ShapeDecoration(color: Tokens.surface3, shape: Tokens.pill),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Text(
              '›',
              style: Tokens.heading.copyWith(color: Tokens.fgDim, height: 1),
            ),
          ),
          const SizedBox(width: Tokens.s8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: Tokens.body.copyWith(fontFamily: Tokens.mono),
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
                hintStyle: Tokens.body.copyWith(color: Tokens.fgFaint),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: Tokens.s8),
              ),
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: Tokens.s8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => RoundIconButton(
            tooltip: 'Run',
            tone: RoundTone.primary,
            diameter: h,
            size: 20,
            onTap: value.text.trim().isEmpty
                ? null
                : () => onSubmitted(value.text),
            icon: Icons.keyboard_return_rounded,
          ),
        ),
      ],
    );
  }
}
