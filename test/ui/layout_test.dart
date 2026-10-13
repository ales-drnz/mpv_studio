import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/layout_harness.dart';

void main() {
  test('width and height classes', () {
    expect(WidthClass.of(360), WidthClass.compact);
    expect(WidthClass.of(600), WidthClass.medium);
    expect(WidthClass.of(839), WidthClass.medium);
    expect(WidthClass.of(840), WidthClass.expanded);
    expect(WidthClass.of(1200), WidthClass.large);
    expect(WidthClass.of(2560), WidthClass.xlarge);
    expect(WidthClass.large.atLeast(WidthClass.expanded), isTrue);
    expect(WidthClass.medium.below(WidthClass.expanded), isTrue);
    expect(HeightClass.of(412), HeightClass.short);
    expect(HeightClass.of(700), HeightClass.regular);
  });

  test('navigation, tap target and sheets per layout', () {
    StudioLayout at(double w, double h, InputMode i) =>
        StudioLayout.of(Size(w, h), input: i);
    expect(at(360, 780, InputMode.touch).navigation, ShellNavigation.bottomBar);
    expect(at(780, 360, InputMode.touch).navigation, ShellNavigation.rail);
    expect(at(800, 1280, InputMode.touch).navigation, ShellNavigation.rail);
    expect(
      at(1024, 700, InputMode.pointer).navigation,
      ShellNavigation.sidebar,
    );
    expect(at(360, 780, InputMode.touch).minTap, 48);
    expect(at(1440, 900, InputMode.pointer).minTap, 40);
    expect(at(1440, 900, InputMode.pointer).prefersSheets, isFalse);
    expect(at(1440, 900, InputMode.touch).prefersSheets, isTrue);
    expect(at(500, 900, InputMode.pointer).prefersSheets, isTrue);
  });

  test('grid columns follow the width', () {
    expect(ResponsiveGrid.columnsFor(320, minTileWidth: 150), 2);
    expect(ResponsiveGrid.columnsFor(100, minTileWidth: 150), 1);
    expect(ResponsiveGrid.columnsFor(1000, minTileWidth: 150), 6);
    expect(
      ResponsiveGrid.columnsFor(1000, minTileWidth: 150, maxColumns: 4),
      4,
    );
  });

  testWidgets('context.layout falls back to the MediaQuery', (tester) async {
    late StudioLayout layout;
    setStudioView(tester, const Size(400, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            layout = context.layout;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(layout.width, WidthClass.compact);
  });

  testWidgets('the page frame caps and centres its content', (tester) async {
    await pumpStudio(
      tester,
      const PageFrame(
        title: 'Wide',
        body: SizedBox(key: ValueKey('body'), height: 40),
      ),
      size: const Size(2560, 1080),
    );
    final body = tester.getRect(find.byKey(const ValueKey('body')));
    expect(body.width, Breakpoints.readable);
    expect(body.center.dx, closeTo(1280, 1));
    final title = tester.getRect(find.text('Wide'));
    expect(title.left, body.left);
  });

  testWidgets('the page frame scrolls instead of overflowing', (tester) async {
    await pumpStudio(
      tester,
      PageFrame(
        title: 'Long',
        body: Column(children: [for (var i = 0; i < 40; i++) Text('row $i')]),
      ),
      size: const Size(360, 780),
      input: InputMode.touch,
      textScale: 1.3,
    );
    expectNoOverflow(tester);
    await tester.drag(find.text('row 3'), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('row 39'), findsOneWidget);
  });

  group('two pane', () {
    Widget host(bool open) => TwoPane(
      list: const Text('list'),
      detail: open ? const Text('detail') : null,
      placeholder: const Text('pick one'),
    );

    testWidgets('splits on a wide area', (tester) async {
      await pumpStudio(tester, host(false), size: const Size(1200, 800));
      expect(find.text('list'), findsOneWidget);
      expect(find.text('pick one'), findsOneWidget);
      await pumpStudio(tester, host(true), size: const Size(1200, 800));
      expect(find.text('list'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
    });

    testWidgets('shows one pane on a narrow area', (tester) async {
      await pumpStudio(tester, host(true), size: const Size(360, 780));
      expect(find.text('detail'), findsOneWidget);
      expect(find.text('list'), findsNothing);
      expect(find.text('pick one'), findsNothing);
    });
  });

  group('adaptive menu', () {
    const items = [
      StudioMenuItem(value: 1, label: 'Rename', icon: Icons.edit_outlined),
      StudioMenuItem(value: 2, label: 'Remove', destructive: true),
    ];
    Widget region(ValueChanged<int> onSelected) => Center(
      child: StudioMenuRegion<int>(
        items: () => items,
        onSelected: onSelected,
        title: 'Track',
        child: const SizedBox(width: 100, height: 40, child: Text('target')),
      ),
    );

    testWidgets('right-click opens a popup menu on pointer', (tester) async {
      int? picked;
      await pumpStudio(tester, region((v) => picked = v));
      await tester.tap(find.text('target'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<int>), findsNWidgets(2));
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(picked, 2);
    });

    testWidgets('long press opens a bottom sheet on touch', (tester) async {
      int? picked;
      await pumpStudio(
        tester,
        region((v) => picked = v),
        size: const Size(412, 915),
        input: InputMode.touch,
      );
      await tester.longPress(find.text('target'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Track'), findsOneWidget);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(picked, 1);
    });
  });

  group('adaptive dialog', () {
    Widget opener() => Builder(
      builder: (context) => TextButton(
        onPressed: () => showStudioDialog<void>(
          context,
          title: 'Remove server?',
          builder: (_) => const Text('Its favourites stay.'),
          actions: (context) => [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
        child: const Text('open'),
      ),
    );

    testWidgets('is a dialog on a wide window', (tester) async {
      await pumpStudio(tester, opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('is a bottom sheet on a phone', (tester) async {
      await pumpStudio(
        tester,
        opener(),
        size: const Size(360, 780),
        input: InputMode.touch,
        textScale: 1.3,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Remove server?'), findsOneWidget);
      expectNoOverflow(tester);
    });
  });
}
