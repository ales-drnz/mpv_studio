import 'package:flutter/material.dart';

import '../layout/layout_scope.dart';
import '../tokens.dart';

/// The uniform settings row: a title, an optional description, and then the
/// interaction. Compact controls (switch, value readout) sit at the trailing
/// edge of the header; wide controls (slider, selector, dropdown) sit on
/// their own line beneath it. Every settings control is built on this so the
/// whole panel reads with one rhythm.
class SettingTile extends StatelessWidget {
  final String title;
  final String? description;

  /// Compact control aligned to the trailing edge of the header row.
  final Widget? trailing;

  /// Wide control rendered full-width under the header.
  final Widget? below;

  final bool enabled;

  /// Makes the whole row tappable (used by switch rows).
  final VoidCallback? onTap;

  const SettingTile({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.below,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tokens.body.copyWith(
                  color: enabled ? Tokens.fg : Tokens.fgFaint,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(description!, style: Tokens.caption),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: Tokens.s12), trailing!],
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (below != null)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.s12),
            child: below,
          ),
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.s12),
      child: content,
    );

    if (onTap == null) return padded;
    return InkWell(
      onTap: enabled ? onTap : null,
      customBorder: Tokens.squircle(Tokens.rSm),
      child: padded,
    );
  }
}

/// Title (+ description) with a full-width custom [AppSlider] beneath and a
/// numeric readout in the header. Double-tap the slider to reset to
/// [resetTo] when provided.
class SliderRow extends StatelessWidget {
  final String label;
  final String? description;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double value)? format;
  final double? resetTo;
  final bool enabled;

  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.description,
    this.onChangeEnd,
    this.divisions,
    this.format,
    this.resetTo,
    this.enabled = true,
  });

  String _fmt(double v) => format?.call(v) ?? v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    Widget slider = AppSlider(
      value: clamped,
      min: min,
      max: max,
      divisions: divisions,
      enabled: enabled,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
    if (resetTo != null) {
      slider = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: enabled ? () => onChanged(resetTo!) : null,
        child: slider,
      );
    }
    return SettingTile(
      title: label,
      description: description,
      enabled: enabled,
      trailing: ValueBadge(
        _fmt(clamped),
        color: enabled ? Tokens.accent : Tokens.fgFaint,
      ),
      below: slider,
    );
  }
}

/// A read-only value, set in a small squircle chip and aligned flush to the
/// trailing edge. The single way settings values are shown.
class ValueBadge extends StatelessWidget {
  final String text;
  final Color? color;
  const ValueBadge(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s8, vertical: 4),
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.squircle(Tokens.rSm),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: Tokens.numeric.copyWith(color: color ?? Tokens.fgDim),
      ),
    );
  }
}

/// Title (+ description) on the left, a custom [AppSwitch] on the right.
/// Tapping anywhere on the row toggles.
class SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SettingTile(
      title: label,
      description: subtitle,
      enabled: enabled,
      onTap: () => onChanged(!value),
      trailing: AppSwitch(value: value, enabled: enabled),
    );
  }
}

/// Title (+ description) with a full-width single-line text field beneath,
/// in the same flat squircle language as the other controls. Seeds its
/// editing buffer from [value]; reports edits through [onChanged]. The
/// controller is reseeded only when [value] changes from outside (e.g. a
/// reset) and the field isn't focused, so live typing is never clobbered.
class TextRow extends StatefulWidget {
  final String label;
  final String? description;
  final String value;
  final String? hint;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const TextRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.hint,
    this.enabled = true,
  });

  @override
  State<TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<TextRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(TextRow old) {
    super.didUpdateWidget(old);
    // Resync from an external change (reset, engine sync) only while the
    // field is unfocused, so it never overwrites what the user is typing.
    if (widget.value != _controller.text && !_focus.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same flat squircle field as every other control (AppDropdown, the URL
    // bar): fixed [Tokens.controlH] height, surface2 fill, with the editable
    // text vertically centred via a Row(Expanded(...)) — so text fields sit at
    // the exact same height as dropdowns, segments and switches across the app.
    final field = Container(
      height: Tokens.controlH,
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.squircle(Tokens.rSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              style: Tokens.body.copyWith(
                fontFamily: Tokens.mono,
                color: widget.enabled ? Tokens.fg : Tokens.fgFaint,
              ),
              cursorColor: Tokens.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: widget.hint,
                hintStyle: Tokens.caption,
              ),
            ),
          ),
        ],
      ),
    );
    return SettingTile(
      title: widget.label,
      description: widget.description,
      enabled: widget.enabled,
      below: field,
    );
  }
}

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

  const DropdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.description,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return SettingTile(
      title: label,
      description: description,
      below: AppDropdown<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        hint: hint,
      ),
    );
  }
}

// ---- Custom widgets -------------------------------------------------

/// A flat, theme-coloured toggle with a squircle track and knob. Purely
/// visual — the surrounding [SwitchRow] owns the tap.
class AppSwitch extends StatelessWidget {
  final bool value;
  final bool enabled;
  const AppSwitch({super.key, required this.value, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final track = enabled
        ? (value ? Tokens.accent : Tokens.surface3)
        : Tokens.surface2;
    final knob = enabled
        ? (value ? Tokens.onAccent : Tokens.fgDim)
        : Tokens.fgFaint;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(color: track, shape: Tokens.squircle(12)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: ShapeDecoration(color: knob, shape: Tokens.squircle(9)),
        ),
      ),
    );
  }
}

/// A flat custom slider — squircle track, accent fill, squircle thumb.
/// Tap or drag to set; reports continuously through [onChanged] and once
/// through [onChangeEnd]. Snaps to [divisions] when given.
class AppSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const AppSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.enabled = true,
    this.onChangeEnd,
  });

  static const double _track = 6;

  double _snap(double v) {
    final c = v.clamp(min, max);
    if (divisions == null || max <= min) return c.toDouble();
    final step = (max - min) / divisions!;
    return (min + ((c - min) / step).round() * step).clamp(min, max).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // On touch the thumb and the grab band grow to fit a finger.
    final touch = context.layout.isTouch;
    final thumb = touch ? 22.0 : 16.0;
    final height = touch ? 44.0 : 24.0;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final span = (w - thumb).clamp(1.0, double.infinity);
        final frac = max <= min
            ? 0.0
            : ((value - min) / (max - min)).clamp(0.0, 1.0);

        double valueAt(double dx) {
          final t = ((dx - thumb / 2) / span).clamp(0.0, 1.0);
          return _snap(min + t * (max - min));
        }

        final fill = Tokens.accent;
        final empty = Tokens.surface3;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled
              ? (d) => onChanged(valueAt(d.localPosition.dx))
              : null,
          onHorizontalDragUpdate: enabled
              ? (d) => onChanged(valueAt(d.localPosition.dx))
              : null,
          onHorizontalDragEnd: enabled && onChangeEnd != null
              ? (_) => onChangeEnd!(value)
              : null,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Empty track.
                Container(
                  height: _track,
                  decoration: ShapeDecoration(
                    color: empty,
                    shape: Tokens.squircle(Tokens.rPill),
                  ),
                ),
                // Accent fill up to the thumb centre.
                Container(
                  height: _track,
                  width: thumb / 2 + frac * span,
                  decoration: ShapeDecoration(
                    color: enabled ? fill : Tokens.fgFaint,
                    shape: Tokens.squircle(Tokens.rPill),
                  ),
                ),
                // Thumb.
                Positioned(
                  left: frac * span,
                  child: Container(
                    width: thumb,
                    height: thumb,
                    decoration: ShapeDecoration(
                      color: enabled ? Tokens.fg : Tokens.fgFaint,
                      shape: Tokens.squircle(thumb / 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One selectable option in a [SegmentedControl].
class SegmentOption<T> {
  final T value;
  final String label;
  const SegmentOption(this.value, this.label);
}

/// A flat squircle pill of mutually-exclusive options. Used for short enum
/// picks (loop, gapless, cache mode, normalization, FFT window).
///
/// By default the segments share the width equally ([expand] `true`); set
/// [expand] `false` for a compact pill that hugs its content — e.g. when it
/// sits inline in a toolbar next to other controls.
class SegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelect;
  final bool expand;

  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Tokens.controlH,
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.squircle(Tokens.rSm),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final o in options)
            if (expand)
              Expanded(
                child: _Segment(
                  label: o.label,
                  active: o.value == selected,
                  onTap: () => onSelect(o.value),
                ),
              )
            else
              _Segment(
                label: o.label,
                active: o.value == selected,
                onTap: () => onSelect(o.value),
                hugContent: true,
              ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// Adds lateral padding so the segment reads well when it sizes to its
  /// label instead of filling an equal share of the row.
  final bool hugContent;

  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
    this.hugContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: Tokens.squircle(Tokens.rSm - 2),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: hugContent ? Tokens.s8 : 0,
            vertical: Tokens.s8,
          ),
          decoration: ShapeDecoration(
            color: active ? Tokens.accent : Colors.transparent,
            shape: Tokens.squircle(Tokens.rSm - 2),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active ? Tokens.onAccent : Tokens.fgDim,
            ),
          ),
        ),
      ),
    );
  }
}

/// A custom dropdown: a squircle trigger that opens a themed overlay list.
/// Reuses [DropdownMenuItem] purely as a (value, child) pair so existing
/// call sites are unchanged — none of Material's dropdown chrome is used.
class AppDropdown<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  /// When false the control is dimmed and **won't open** on tap (the caller
  /// no longer needs its own `Opacity` / `IgnorePointer` wrapper).
  final bool enabled;

  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  OverlayEntry? _entry;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  void _close() {
    if (!_open) return;
    _remove();
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_open) {
      _close();
      return;
    }
    final box = context.findRenderObject() as RenderBox;
    // Position the menu from the trigger's rect rather than a
    // CompositedTransformFollower: a RenderFollowerLayer in the overlay would
    // crash any OverlayPortal-based child (Tooltip, SelectionArea, …) that an
    // item might contain, because its paint transform isn't known at layout.
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final height = box.size.height;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Tap-away barrier.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Positioned(
            left: topLeft.dx,
            top: topLeft.dy + height + Tokens.s4,
            width: width,
            child: _menu(height),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  Widget _menu(double anchorHeight) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: ShapeDecoration(
          color: Tokens.surface3,
          shape: Tokens.squircle(Tokens.rSm),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Tokens.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in widget.items)
                _MenuItem(
                  active: item.value == widget.value,
                  enabled: item.enabled,
                  onTap: () {
                    widget.onChanged(item.value);
                    _close();
                  },
                  child: item.child,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _selectedChild() {
    for (final item in widget.items) {
      if (item.value == widget.value) return item.child;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedChild();
    final enabled = widget.enabled;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? _toggle : null,
          customBorder: Tokens.squircle(Tokens.rSm),
          child: Container(
            height: Tokens.controlH,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
            decoration: ShapeDecoration(
              color: Tokens.surface2,
              shape: Tokens.squircle(Tokens.rSm),
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
    );
  }
}

class _MenuItem extends StatelessWidget {
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;
  const _MenuItem({
    required this.active,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? Tokens.fgFaint
        : active
        ? Tokens.accent
        : Tokens.fg;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        // A disabled item stays visible but inert (greyed, no tap).
        onTap: enabled ? onTap : null,
        customBorder: Tokens.squircle(Tokens.rSm - 2),
        child: Container(
          decoration: ShapeDecoration(
            color: active && enabled ? Tokens.accentWash : Colors.transparent,
            shape: Tokens.squircle(Tokens.rSm - 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.s12,
            vertical: 10,
          ),
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
      ),
    );
  }
}
