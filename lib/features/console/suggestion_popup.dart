import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import 'completion_engine.dart';

/// The autocomplete popup — a flat list of [Suggestion]s that sits just
/// above the console input and grows upward, Minecraft-style. The selected
/// row is washed in accent and bolds the typed match.
///
/// A command row shows its name with the **description underneath** and its
/// **argument signature to the right** (the parameters that follow as you
/// type it). Property/value rows are single-line with a type tag on the
/// right.
class SuggestionPopup extends StatefulWidget {
  final List<Suggestion> suggestions;
  final int selected;
  final String tokenSoFar;
  final ValueChanged<int> onTap;

  const SuggestionPopup({
    super.key,
    required this.suggestions,
    required this.selected,
    required this.tokenSoFar,
    required this.onTap,
  });

  @override
  State<SuggestionPopup> createState() => _SuggestionPopupState();
}

class _SuggestionPopupState extends State<SuggestionPopup> {
  final _scroll = ScrollController();

  /// Two-line (taller) rows when any suggestion carries a description
  /// (the command list); single-line otherwise (properties / values). A
  /// given popup is homogeneous in kind, so one height fits the whole list.
  double get _rowHeight =>
      widget.suggestions.any((s) => s.description != null) ? 44.0 : 30.0;

  @override
  void didUpdateWidget(SuggestionPopup old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _keepVisible());
    }
  }

  /// Scroll so the selected row stays in view as the user arrows through.
  void _keepVisible() {
    if (!_scroll.hasClients) return;
    final h = _rowHeight;
    final target = widget.selected * h;
    final top = _scroll.offset;
    final bottom = top + _scroll.position.viewportDimension;
    if (target < top) {
      _scroll.jumpTo(target);
    } else if (target + h > bottom) {
      _scroll.jumpTo(target + h - _scroll.position.viewportDimension);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Color _accent(SuggestionKind kind) => switch (kind) {
    SuggestionKind.command => Tokens.accent,
    SuggestionKind.property => Tokens.green,
    SuggestionKind.value => Tokens.amber,
  };

  @override
  Widget build(BuildContext context) {
    final rowHeight = _rowHeight;
    final visibleRows = widget.suggestions.length.clamp(1, 8);
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.s4),
      constraints: BoxConstraints(maxHeight: visibleRows * rowHeight + 2),
      decoration: ShapeDecoration(
        color: Tokens.surface3,
        shape: Tokens.squircle(Tokens.rSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.zero,
        itemExtent: rowHeight,
        shrinkWrap: true,
        itemCount: widget.suggestions.length,
        itemBuilder: (context, i) {
          final s = widget.suggestions[i];
          final active = i == widget.selected;
          return Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => widget.onTap(i),
              child: Container(
                color: active ? Tokens.accentWash : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: Tokens.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: active ? _accent(s.kind) : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: Tokens.s8),
                    // Name + (description underneath).
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label(
                            label: s.label,
                            match: widget.tokenSoFar,
                            active: active,
                          ),
                          if (s.description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                s.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Tokens.caption.copyWith(fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Parameters / type tag, to the right.
                    if (s.detail != null) ...[
                      const SizedBox(width: Tokens.s8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          s.detail!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontFamily: Tokens.mono,
                            fontSize: 10.5,
                            color: s.kind == SuggestionKind.command
                                ? Tokens.accentDim
                                : Tokens.fgFaint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The suggestion label with the matched prefix/substring bolded in accent.
class _Label extends StatelessWidget {
  final String label;
  final String match;
  final bool active;

  const _Label({
    required this.label,
    required this.match,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: Tokens.mono,
      fontSize: 12.5,
      color: active ? Tokens.fg : Tokens.fgDim,
    );
    final i = match.isEmpty
        ? -1
        : label.toLowerCase().indexOf(match.toLowerCase());
    if (i < 0) {
      return Text(
        label,
        style: base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: label.substring(0, i)),
          TextSpan(
            text: label.substring(i, i + match.length),
            style: base.copyWith(
              color: Tokens.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: label.substring(i + match.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
