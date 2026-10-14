import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';
import 'package:mpv_studio/ui/widgets/controls/dropdown.dart';

import '../support/layout_harness.dart';
import 'palette_contrast_test.dart' show contrast;

/// The colour [text] is drawn in.
Color _colorOf(WidgetTester tester, Finder text) {
  final widget = tester.widget<Text>(text);
  return widget.style?.color ??
      DefaultTextStyle.of(tester.element(text)).style.color!;
}

/// The fill right under [text]: the nearest coloured shape around it,
/// else the menu's Material.
Color _fillUnder(WidgetTester tester, Finder text) {
  Color? fill;
  tester.element(text).visitAncestorElements((a) {
    final w = a.widget;
    final d = switch (w) {
      DecoratedBox() => w.decoration,
      _ => null,
    };
    if (d is ShapeDecoration && d.color != null && d.color!.a > 0) {
      fill = d.color;
      return false;
    }
    if (w is Material && w.color != null) {
      fill = w.color;
      return false;
    }
    return true;
  });
  return fill!;
}

/// Menus are on the tonal surface with its own text tone, the current
/// choice on the accent fill in its own tone: every label reads at 4.5:1
/// or more in both themes (the old menus drew the current choice white
/// on the ring grey).
void main() {
  setUpAll(loadStudioFonts);

  for (final palette in [Palette.dark, Palette.light]) {
    final theme = palette.isDark ? 'dark' : 'light';

    testWidgets('$theme dropdown menu', (tester) async {
      await pumpStudio(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AppDropdown<int>(
                value: 2,
                label: 'Device',
                onChanged: (_) {},
                items: const [
                  DropdownMenuItem(
                    value: 1,
                    child: DropdownOption(label: 'Auto'),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: DropdownOption(
                      label: 'Built-in Audio',
                      caption: 'pipewire/alsa_output.analog-stereo',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: DropdownOption(
                      label: 'Studio Interface',
                      caption: 'pipewire/alsa_output.usb-interface',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        palette: palette,
      );
      await tester.tap(find.byType(AppDropdown<int>));
      await tester.pumpAndSettle();
      for (final label in [
        'Auto',
        'pipewire/alsa_output.analog-stereo',
        'Studio Interface',
        'pipewire/alsa_output.usb-interface',
      ]) {
        final text = find.text(label).last;
        expect(
          contrast(_colorOf(tester, text), _fillUnder(tester, text)),
          greaterThanOrEqualTo(4.5),
          reason: label,
        );
      }
      // The current choice, in the menu.
      final current = find.text('Built-in Audio').last;
      expect(
        contrast(_colorOf(tester, current), _fillUnder(tester, current)),
        greaterThanOrEqualTo(4.5),
      );
      expect(_fillUnder(tester, find.text('Auto').last), palette.tonal);
    });

    testWidgets('$theme context menu', (tester) async {
      await pumpStudio(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showStudioMenu<int>(
                  context,
                  position: const Offset(200, 200),
                  items: const [
                    StudioMenuItem(value: 1, label: 'Play', icon: Icons.add),
                    StudioMenuItem(
                      value: 2,
                      label: 'Remove',
                      icon: Icons.close,
                      destructive: true,
                    ),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        palette: palette,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (final label in ['Play', 'Remove']) {
        final text = find.text(label);
        expect(
          contrast(_colorOf(tester, text), _fillUnder(tester, text)),
          greaterThanOrEqualTo(4.5),
          reason: label,
        );
        expect(_fillUnder(tester, text), palette.tonal);
      }
      // The destructive mark is the icon's red.
      final icon = tester.widget<Icon>(find.byIcon(Icons.close));
      expect(icon.color, palette.red);
    });
  }
}
