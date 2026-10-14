import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/palette.dart';
import 'package:mpv_studio/ui/widgets/round_icon_button.dart';

import '../support/layout_harness.dart';

void main() {
  Color fillOf(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    return (box.decoration! as ShapeDecoration).color!;
  }

  testWidgets('a selected button takes the selection fill and says so', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpStudio(
      tester,
      Scaffold(
        body: Center(
          child: RoundIconButton(
            icon: Icons.favorite_rounded,
            tooltip: 'Favorite',
            selected: true,
            onTap: () {},
          ),
        ),
      ),
      palette: Palette.light,
    );
    expect(fillOf(tester), Palette.light.accentContainer);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Favorite')),
      // isSemantics replaces it from Flutter 3.40; the app still supports 3.38.
      // ignore: deprecated_member_use
      containsSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('on the selection fill the button draws in its content tone', (
    tester,
  ) async {
    await pumpStudio(
      tester,
      Scaffold(
        body: Center(
          child: RoundIconButton(
            icon: Icons.more_vert_rounded,
            tooltip: 'More',
            selected: true,
            onContainer: true,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(fillOf(tester), Colors.transparent);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.more_vert_rounded)).color,
      Palette.dark.onAccentContainer,
    );
  });
}
