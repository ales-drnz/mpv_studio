import 'package:flutter/material.dart';

import '../../layout/layout.dart';
import '../../tokens.dart';
import 'control_metrics.dart';
import 'setting_tile.dart';

/// Title (+ description) with a full-width [AppDropdown] beneath.
class DropdownRow<T> extends StatelessWidget {
  final String label;
  final String? description;

  /// Current selection. Pass `null` (with a [hint]) when the live value
  /// isn't among [items], so the control shows the hint instead.
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  /// When false the control is dimmed and won't open.
  final bool enabled;

  const DropdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.description,
    this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SettingTile(
      title: label,
      description: description,
      enabled: enabled,
      below: AppDropdown<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        hint: hint,
        label: label,
        enabled: enabled,
      ),
    );
  }
}

/// A choice of an [AppDropdown] with a second, smaller line under its
/// [label] in the menu and the sheet, such as the device id under a device
/// name, to tell apart choices that read the same. The closed control
/// shows the [label] alone.
class DropdownOption extends StatelessWidget {
  const DropdownOption({super.key, required this.label, this.caption});

  final String label;

  /// The second line; null for none.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    if (caption == null) return Text(label);
    // The caption takes the row's colour, so it reads on the selection
    // wash too.
    final color = DefaultTextStyle.of(context).style.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        Text(caption, style: Tokens.caption.copyWith(color: color)),
      ],
    );
  }
}

/// A flat dropdown: a pill trigger that opens the options as a menu
/// under it with a pointer, and as a bottom sheet with full size rows on
/// touch and on compact windows (see `LayoutScope`). Reuses
/// [DropdownMenuItem] purely as a (value, child) pair so call sites stay
/// plain; none of Material's dropdown chrome is used.
///
/// The menu is keyboard friendly (arrows, Enter, Escape) and the trigger
/// announces itself as a button with the current choice as its value.
class AppDropdown<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  /// When false the control is dimmed and **won't open** on tap (the caller
  /// no longer needs its own `Opacity` / `IgnorePointer` wrapper).
  final bool enabled;

  /// What the control picks, for screen readers and the sheet's title.
  final String? label;

  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.label,
  });

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

/// The picked item, wrapped so that a null value can be picked too and is
/// told apart from a dismissed menu.
class _Pick<T> {
  const _Pick(this.value);
  final T? value;
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  bool _open = false;

  Widget? _selectedChild() {
    for (final item in widget.items) {
      if (item.value == widget.value) return item.child;
    }
    return null;
  }

  Future<void> _show() async {
    setState(() => _open = true);
    // Read before any await: Flutter 3.38's analyzer flags the context in
    // the condition of an awaited conditional.
    final sheets = context.layout.prefersSheets;
    final picked = sheets ? await _sheet() : await _menu();
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null) widget.onChanged(picked.value);
  }

  Future<_Pick<T>?> _menu() {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset(0, box.size.height), ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final width = box.size.width;
    return showMenu<_Pick<T>>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      color: Tokens.tonal,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      menuPadding: const EdgeInsets.all(Tokens.s4),
      constraints: BoxConstraints(minWidth: width, maxWidth: width),
      shape: Tokens.shape(Tokens.rMd),
      items: [
        for (final item in widget.items)
          PopupMenuItem<_Pick<T>>(
            value: _Pick(item.value),
            enabled: item.enabled,
            height: context.layout.minTap,
            padding: EdgeInsets.zero,
            child: _MenuRow(
              active: item.value == widget.value,
              enabled: item.enabled,
              child: item.child,
            ),
          ),
      ],
    );
  }

  Future<_Pick<T>?> _sheet() {
    return showStudioSheet<_Pick<T>>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.s16,
                0,
                Tokens.s16,
                Tokens.s8,
              ),
              child: Text(widget.label!, style: Tokens.heading),
            ),
          for (final item in widget.items)
            InkWell(
              onTap: item.enabled
                  ? () => Navigator.of(context).pop(_Pick<T>(item.value))
                  : null,
              customBorder: Tokens.pill,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: _MenuRow(
                  active: item.value == widget.value,
                  enabled: item.enabled,
                  child: item.child,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _selectedChild();
    // The closed control has one line: an option shows its label only.
    final selected = child is DropdownOption ? Text(child.label) : child;
    final enabled = widget.enabled;
    final valueText = selected is Text ? selected.data : widget.hint;
    return Semantics(
      button: true,
      enabled: enabled,
      expanded: _open,
      label: widget.label,
      value: valueText,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? _show : null,
            customBorder: Tokens.pill,
            child: Container(
              height: controlHeightOf(context),
              padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
              decoration: ShapeDecoration(
                color: Tokens.surface3,
                shape: Tokens.pill,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle(
                      style: selected == null ? Tokens.caption : Tokens.body,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      child: selected ?? Text(widget.hint ?? 'Select'),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: Tokens.fgDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One option row of the menu and the sheet: the current choice on the
/// accent fill in its own content tone (14.8:1 in both themes), the rest
/// in the tonal surface's text tone, a disabled one greyed.
class _MenuRow extends StatelessWidget {
  final bool active;
  final bool enabled;
  final Widget child;
  const _MenuRow({
    required this.active,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? Tokens.fgFaint
        : active
        ? Tokens.onAccent
        : Tokens.onTonal;
    return Container(
      alignment: Alignment.centerLeft,
      decoration: ShapeDecoration(
        color: active && enabled ? Tokens.accent : Colors.transparent,
        shape: Tokens.pill,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.s16,
        vertical: Tokens.s12,
      ),
      child: Semantics(
        selected: active,
        child: DefaultTextStyle(
          style: Tokens.body.copyWith(
            color: color,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          child: child,
        ),
      ),
    );
  }
}
