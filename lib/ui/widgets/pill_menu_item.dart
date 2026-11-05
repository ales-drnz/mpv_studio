import 'package:flutter/material.dart';

import '../tokens.dart';
import 'focus_ring.dart';

/// A [PopupMenuItem] whose hover, press and focus take the item's pill, as
/// every other row of the app does: Flutter's own item lights a rectangle
/// across the menu. Behaves as a [PopupMenuItem] otherwise (the menu's
/// keyboard, semantics and result).
class PillMenuItem<T> extends PopupMenuItem<T> {
  const PillMenuItem({
    super.key,
    super.value,
    super.enabled,
    super.height,
    required super.child,
  }) : super(padding: EdgeInsets.zero);

  @override
  PopupMenuItemState<T, PillMenuItem<T>> createState() =>
      _PillMenuItemState<T>();
}

class _PillMenuItemState<T> extends PopupMenuItemState<T, PillMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: buildSemantics(
        child: FocusRing(
          inside: true,
          child: InkWell(
            onTap: widget.enabled ? handleTap : null,
            canRequestFocus: widget.enabled,
            customBorder: Tokens.pill,
            mouseCursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.height),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                // A disabled item dims an icon its row does not colour,
                // as Flutter's item does.
                child: widget.enabled
                    ? buildChild()
                    : IconTheme.merge(
                        data: const IconThemeData(opacity: 0.5),
                        child: buildChild() ?? const SizedBox.shrink(),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
