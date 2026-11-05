import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/tokens.dart';
import 'package:mpv_studio/ui/widgets/controls/switch_row.dart';
import 'package:mpv_studio/ui/widgets/round_icon_button.dart';
import 'package:mpv_studio/ui/widgets/section_switcher.dart';

/// With the platform's reduced motion on, the shared widgets change at
/// once instead of animating.
void main() {
  Widget host(Widget child, {required bool reduce}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(body: child),
    ),
  );

  testWidgets('Tokens.motion is zero with reduced motion', (tester) async {
    late Duration reduced, full;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            reduced = Tokens.motion(context, Tokens.motionMedium);
            return const SizedBox();
          },
        ),
        reduce: true,
      ),
    );
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            full = Tokens.motion(context, Tokens.motionMedium);
            return const SizedBox();
          },
        ),
        reduce: false,
      ),
    );
    expect(reduced, Duration.zero);
    expect(full, Tokens.motionMedium);
  });

  for (final reduce in [true, false]) {
    testWidgets(
      'SectionSwitcher swaps ${reduce ? 'at once' : 'with a '
                'fade'} (reduced motion ${reduce ? 'on' : 'off'})',
      (tester) async {
        Widget page(String name) => host(
          SectionSwitcher(
            child: KeyedSubtree(key: ValueKey(name), child: Text(name)),
          ),
          reduce: reduce,
        );
        await tester.pumpWidget(page('list'));
        await tester.pumpWidget(page('detail'));
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.text('list'), reduce ? findsNothing : findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('list'), findsNothing);
      },
    );
  }

  testWidgets('AppSwitch and RoundIconButton do not animate', (tester) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [
            const AppSwitch(value: true),
            RoundIconButton(icon: Icons.add, tooltip: 'Add', onTap: () {}),
          ],
        ),
        reduce: true,
      ),
    );
    // The app's own animations; Material's theme fades are not ours.
    final animated = tester.widgetList<ImplicitlyAnimatedWidget>(
      find.byWidgetPredicate(
        (w) => w is AnimatedContainer || w is AnimatedAlign,
      ),
    );
    expect(animated, isNotEmpty);
    for (final w in animated) {
      expect(w.duration, Duration.zero, reason: '${w.runtimeType}');
    }
  });
}
