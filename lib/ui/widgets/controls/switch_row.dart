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

/// A flat, theme-coloured toggle with a rounded track and knob. Purely
/// visual: the surrounding [SwitchRow] (or card) owns the tap and the
/// semantics.
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
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 42,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: ShapeDecoration(color: track, shape: Tokens.shape(12)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: ShapeDecoration(color: knob, shape: Tokens.shape(9)),
          ),
        ),
      ),
    );
  }
}
