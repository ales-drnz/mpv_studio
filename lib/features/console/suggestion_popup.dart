import 'package:flutter/material.dart';

import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import 'completion_engine.dart';

/// The autocomplete popup: a flat list of [Suggestion]s that sits just
/// above the console input and grows upward, Minecraft-style: a tonal
/// panel of pill rows, the selected one in the secondary selection fill.
/// The typed match is bold.
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
  /// (the command list), single-line otherwise (properties and values). A
  /// popup is homogeneous in kind, so one height fits the whole list. On
  /// touch every row is at least a finger tall.
  double get _rowHeight {
    final twoLines = widget.suggestions.any((s) => s.description != null);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final base = (twoLines ? 48.0 : 36.0) * scale.clamp(1.0, 2.0);
    return context.layout.isTouch && base < 52 ? 52 : base;
  }

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
    final target = Tokens.s4 + widget.selected * h;
    final top = _scroll.offset;
    final bottom = top + _scroll.position.viewportDimension;
    if (target < top) {
      _scroll.jumpTo(target - Tokens.s4);
    } else if (target + h > bottom) {
      _scroll.jumpTo(
        target + h + Tokens.s4 - _scroll.position.viewportDimension,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = _rowHeight;
    final visibleRows = widget.suggestions.length.clamp(1, 8);
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.s8),
      constraints: BoxConstraints(
        maxHeight: visibleRows * rowHeight + 2 * Tokens.s4,
      ),
      decoration: ShapeDecoration(
        color: Tokens.surface3,
        shape: Tokens.shape(Tokens.rMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(Tokens.s4),
        itemExtent: rowHeight,
        shrinkWrap: true,
        itemCount: widget.suggestions.length,
        itemBuilder: (context, i) {
          final s = widget.suggestions[i];
          final active = i == widget.selected;
          final ink = active ? Tokens.onAccentContainer : null;
          return Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => widget.onTap(i),
              customBorder: Tokens.shape(Tokens.rSm),
              child: Ink(
                decoration: ShapeDecoration(
                  color: active ? Tokens.accentContainer : Colors.transparent,
                  shape: Tokens.shape(Tokens.rSm),
                ),
                padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                s.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Tokens.caption.copyWith(
                                  color: ink ?? Tokens.fgFaint,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Parameters or type tag, to the right.
                    if (s.detail != null) ...[
                      const SizedBox(width: Tokens.s8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          s.detail!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: Tokens.numeric.copyWith(
                            fontSize: 11,
                            color:
                                ink ??
                                (s.kind == SuggestionKind.command
                                    ? Tokens.fgDim
                                    : Tokens.fgFaint),
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
    final base = Tokens.numeric.copyWith(
      fontSize: 13,
      color: active ? Tokens.onAccentContainer : Tokens.fgDim,
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
              color: active ? Tokens.onAccentContainer : Tokens.accent,
              fontWeight: FontWeight.w800,
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
