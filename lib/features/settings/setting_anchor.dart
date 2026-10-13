import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import 'settings_catalog.dart';

/// The setting search jumped to, for the [SettingAnchor] with its id to
/// scroll itself into view and flash. Cleared once revealed.
class SettingsFocus extends ValueNotifier<String?> {
  SettingsFocus() : super(null);
}

/// Hands a [SettingsFocus] to the anchors below.
class SettingsFocusScope extends InheritedWidget {
  const SettingsFocusScope({
    super.key,
    required this.focus,
    required super.child,
  });

  final SettingsFocus focus;

  static SettingsFocus? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsFocusScope>()?.focus;

  @override
  bool updateShouldNotify(SettingsFocusScope old) => old.focus != focus;
}

/// Marks the row of [entry] so search can reveal it: when the
/// [SettingsFocus] names it, the row scrolls into view and its background
/// flashes the accent wash.
class SettingAnchor extends StatefulWidget {
  const SettingAnchor({super.key, required this.entry, required this.child});

  final SettingEntry entry;
  final Widget child;

  @override
  State<SettingAnchor> createState() => _SettingAnchorState();
}

class _SettingAnchorState extends State<SettingAnchor>
    with SingleTickerProviderStateMixin {
  static const _flash = Duration(milliseconds: 1800);

  SettingsFocus? _focus;
  late final _glow = AnimationController(vsync: this, duration: _flash);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final focus = SettingsFocusScope.maybeOf(context);
    if (focus == _focus) return;
    _focus?.removeListener(_check);
    _focus = focus?..addListener(_check);
    _check();
  }

  void _check() {
    if (_focus?.value != widget.entry.id) return;
    // After the frame that built the group, so the scroll view knows the
    // row's place.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focus?.value != widget.entry.id) return;
      _focus!.value = null;
      Scrollable.ensureVisible(
        context,
        alignment: 0.2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      _glow.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _focus?.removeListener(_check);
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        // Full wash, held, then fading out.
        final t = _glow.isAnimating ? (1 - _glow.value) * 1.6 : 0.0;
        final wash = Tokens.accentWash;
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: wash.withValues(alpha: wash.a * t.clamp(0.0, 1.0)),
            shape: Tokens.squircle(Tokens.rSm),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
