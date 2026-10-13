import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/controls.dart';
import '../../ui/widgets/round_icon_button.dart';
import 'settings_catalog.dart';

/// The Settings search box. Escape clears it; Ctrl+F (Cmd+F) focuses it
/// (bound by the page).
class SettingsSearchField extends StatelessWidget {
  const SettingsSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): controller.clear,
      },
      child: AppTextField(
        controller: controller,
        focusNode: focusNode,
        hint: 'Search settings',
        label: 'Search settings',
        autocorrect: false,
        textInputAction: TextInputAction.search,
        leading: Icon(Icons.search_rounded, size: 18, color: Tokens.fgDim),
        action: controller.text.isEmpty
            ? null
            : RoundIconButton(
                icon: Icons.close_rounded,
                size: 20,
                color: Tokens.fgDim,
                tooltip: 'Clear search',
                onTap: controller.clear,
              ),
      ),
    );
  }
}

/// The settings matching [query] in every group, the matched words
/// highlighted; [onOpen] jumps to one.
class SettingsSearchResults extends StatelessWidget {
  const SettingsSearchResults({
    super.key,
    required this.query,
    required this.onOpen,
  });

  final String query;
  final ValueChanged<SettingEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final results = searchSettings(query);
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Tokens.s16),
        child: Semantics(
          liveRegion: true,
          child: Text(
            'No setting matches "$query".',
            style: Tokens.body.copyWith(color: Tokens.fgDim),
          ),
        ),
      );
    }
    return FocusTraversalGroup(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: Tokens.s24),
        itemCount: results.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.s16,
                0,
                Tokens.s16,
                Tokens.s8,
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  results.length == 1
                      ? '1 setting'
                      : '${results.length} settings',
                  style: Tokens.caption,
                ),
              ),
            );
          }
          final e = results[i - 1];
          return _ResultTile(
            entry: e,
            words: query.toLowerCase().split(RegExp(r'\s+')),
            onTap: () => onOpen(e),
          );
        },
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.entry,
    required this.words,
    required this.onTap,
  });

  final SettingEntry entry;
  final List<String> words;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${entry.title}, in ${entry.group.title}, ${entry.section}',
      excludeSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Tokens.s4),
        child: Material(
          color: Tokens.surface,
          shape: Tokens.shape(Tokens.rMd),
          child: InkWell(
            onTap: onTap,
            customBorder: Tokens.shape(Tokens.rMd),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: context.layout.minTap),
              child: Padding(
                padding: const EdgeInsets.all(Tokens.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      highlightMatches(entry.title, words, Tokens.body),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${entry.group.title}, ${entry.section}',
                      style: Tokens.caption.copyWith(color: Tokens.fgDim),
                    ),
                    const SizedBox(height: Tokens.s4),
                    Text.rich(
                      highlightMatches(
                        entry.description,
                        words,
                        Tokens.label.copyWith(color: Tokens.fgDim),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [text] in [style] with every occurrence of [words] (lower case) in bold
/// accent.
TextSpan highlightMatches(String text, List<String> words, TextStyle style) {
  final lower = text.toLowerCase();
  final marks = List<bool>.filled(text.length, false);
  for (final w in words) {
    if (w.isEmpty) continue;
    for (var i = lower.indexOf(w); i >= 0; i = lower.indexOf(w, i + 1)) {
      marks.fillRange(i, i + w.length, true);
    }
  }
  final hit = style.copyWith(color: Tokens.accent, fontWeight: FontWeight.w700);
  final spans = <TextSpan>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i == text.length || marks[i] != marks[start]) {
      spans.add(
        TextSpan(
          text: text.substring(start, i),
          style: marks[start] ? hit : style,
        ),
      );
      start = i;
    }
  }
  return TextSpan(children: spans, style: style);
}
