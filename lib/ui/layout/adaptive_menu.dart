import 'package:flutter/material.dart';

import '../tokens.dart';
import 'adaptive_dialog.dart';
import 'layout_scope.dart';

/// One entry of [showStudioMenu].
@immutable
class StudioMenuItem<T> {
  const StudioMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;

  /// Drawn in red (remove, delete, clear).
  final bool destructive;
}

/// Opens a menu of [items] and returns the picked value (null when
/// dismissed). With a pointer and a [position] (the global position of
/// the click) it is a context menu there; on touch, on compact windows or
/// without a position it is a bottom sheet with [title] on top and full
/// size tap targets.
Future<T?> showStudioMenu<T>(
  BuildContext context, {
  required List<StudioMenuItem<T>> items,
  Offset? position,
  String? title,
}) {
  final layout = context.layout;
  if (position != null && !layout.prefersSheets) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final at = overlay.globalToLocal(position);
    return showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(at.dx, at.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      color: Tokens.surface2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Tokens.squircle(Tokens.rMd, side: BorderSide(color: Tokens.line2)),
      items: [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            enabled: item.enabled,
            height: layout.minTap,
            child: _MenuRow(item: item),
          ),
      ],
    );
  }
  return showStudioSheet<T>(
    context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.s16,
              0,
              Tokens.s16,
              Tokens.s8,
            ),
            child: Text(
              title,
              style: Tokens.heading,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        for (final item in items)
          InkWell(
            onTap: item.enabled
                ? () => Navigator.of(context).pop(item.value)
                : null,
            customBorder: Tokens.squircle(Tokens.rSm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _MenuRow(item: item),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.item});

  final StudioMenuItem<T> item;

  @override
  Widget build(BuildContext context) {
    final color = !item.enabled
        ? Tokens.fgFaint
        : item.destructive
        ? Tokens.red
        : Tokens.fg;
    return Row(
      children: [
        if (item.icon != null) ...[
          Icon(
            item.icon,
            size: 18,
            color: item.destructive ? color : Tokens.fgDim,
          ),
          const SizedBox(width: Tokens.s12),
        ],
        Flexible(
          child: Text(
            item.label,
            style: Tokens.body.copyWith(color: color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Gives [child] a context menu: right-click on pointer devices, long
/// press everywhere. [items] is called when the menu opens, and
/// [onSelected] gets the picked value.
class StudioMenuRegion<T> extends StatelessWidget {
  const StudioMenuRegion({
    super.key,
    required this.items,
    required this.onSelected,
    this.title,
    required this.child,
  });

  final List<StudioMenuItem<T>> Function() items;
  final ValueChanged<T> onSelected;

  /// Heads the bottom sheet variant.
  final String? title;

  final Widget child;

  Future<void> _open(BuildContext context, Offset position) async {
    final picked = await showStudioMenu<T>(
      context,
      items: items(),
      position: position,
      title: title,
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (d) => _open(context, d.globalPosition),
      onLongPressStart: (d) => _open(context, d.globalPosition),
      child: child,
    );
  }
}
