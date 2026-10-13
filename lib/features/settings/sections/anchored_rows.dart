import 'package:flutter/material.dart';

import '../../../ui/widgets/controls.dart';
import '../setting_anchor.dart';
import '../settings_catalog.dart';
import '../settings_scope.dart';

// The settings rows bound to a catalog entry: they take its title and
// description, carry its search anchor, and run every change through the
// scope's guard so what the player refuses becomes a notice.

/// A [SliderRow] for [entry] whose changes run through the scope's guard.
Widget anchoredSlider(
  SettingsScope scope,
  SettingEntry entry, {
  required double value,
  required double min,
  required double max,
  required String Function(double) format,
  required Future<void> Function(double) set,
  double? resetTo,
  int? divisions,
  bool enabled = true,
}) => SettingAnchor(
  entry: entry,
  child: SliderRow(
    label: entry.title,
    description: entry.description,
    value: value,
    min: min,
    max: max,
    divisions: divisions,
    resetTo: resetTo,
    format: format,
    enabled: enabled,
    onChanged: (x) => scope.run(() => set(x)),
  ),
);

/// A [SwitchRow] for [entry] whose changes run through the scope's guard.
Widget anchoredSwitch(
  SettingsScope scope,
  SettingEntry entry, {
  required bool value,
  required Future<void> Function(bool) set,
  bool enabled = true,
}) => SettingAnchor(
  entry: entry,
  child: SwitchRow(
    label: entry.title,
    subtitle: entry.description,
    value: value,
    enabled: enabled,
    onChanged: (v) => scope.run(() => set(v)),
  ),
);

/// A [SegmentedControl] row for [entry] whose picks run through the
/// scope's guard.
Widget anchoredSegments<T>(
  SettingsScope scope,
  SettingEntry entry, {
  required T selected,
  required List<SegmentOption<T>> options,
  required Future<void> Function(T) set,
  bool enabled = true,
}) => SettingAnchor(
  entry: entry,
  child: SettingTile(
    title: entry.title,
    description: entry.description,
    enabled: enabled,
    below: SegmentedControl<T>(
      selected: selected,
      options: options,
      enabled: enabled,
      onSelect: (v) => scope.run(() => set(v)),
    ),
  ),
);

/// A [DropdownRow] for [entry] whose picks run through the scope's guard;
/// a null pick is ignored.
Widget anchoredDropdown<T>(
  SettingsScope scope,
  SettingEntry entry, {
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required Future<void> Function(T) set,
  String? hint,
}) => SettingAnchor(
  entry: entry,
  child: DropdownRow<T>(
    label: entry.title,
    description: entry.description,
    value: value,
    hint: hint,
    items: items,
    onChanged: (v) {
      if (v != null) scope.run(() => set(v));
    },
  ),
);

/// A row for [entry] holding a file or folder [path]: the path (or
/// [unset] when empty) under the title, "Choose" to [pick] a new one, and
/// "Default" to clear it. [pick] returns null when cancelled.
Widget anchoredPath(
  SettingEntry entry, {
  required String path,
  required String unset,
  required Future<String?> Function() pick,
  required ValueChanged<String> onChanged,
}) => SettingAnchor(
  entry: entry,
  child: SettingTile(
    title: entry.title,
    description: path.isEmpty ? '${entry.description}. $unset' : path,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (path.isNotEmpty)
          TileButton(
            label: 'Default',
            tooltip: 'Use the default for ${entry.title}',
            onPressed: () => onChanged(''),
          ),
        TileButton(
          label: 'Choose',
          accent: true,
          tooltip: 'Choose the ${entry.title.toLowerCase()}',
          onPressed: () async {
            final picked = await pick();
            if (picked != null) onChanged(picked);
          },
        ),
      ],
    ),
  ),
);

/// Shows [message] as a short toast, for the result of an action row.
void showSettingsMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}
