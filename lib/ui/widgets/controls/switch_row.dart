import 'package:flutter/material.dart';

import '../../tokens.dart';
import 'setting_tile.dart';

/// Title (+ description) on the left, a custom [AppSwitch] on the right.
/// Tapping anywhere on the row toggles, and so do Space and Enter when the
/// row has keyboard focus.
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
      toggled: value,
      onTap: () => onChanged(!value),
      trailing: AppSwitch(value: value, enabled: enabled),
    );
  }
}

/// A flat, theme-coloured toggle with a pill track and a round knob. Purely
/// visual: the surrounding [SwitchRow] (or card) owns the tap and the
/// semantics.
class AppSwitch extends StatelessWidget {
  final bool value;
  final bool enabled;
  const AppSwitch({super.key, required this.value, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final track = enabled
        ? (value ? Tokens.accent : Tokens.surface4)
        : Tokens.surface3;
    final knob = enabled
        ? (value ? Tokens.onAccent : Tokens.fgDim)
        : Tokens.fgFaint;
    // Shape contrast: the knob grows from a small dot (off) to a full
    // circle (on), as Material 3 switches do.
    final size = value ? 20.0 : 14.0;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(Tokens.s4),
        decoration: ShapeDecoration(color: track, shape: Tokens.pill),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: SizedBox.square(
            dimension: 20,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: size,
                height: size,
                decoration: ShapeDecoration(
                  color: knob,
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
