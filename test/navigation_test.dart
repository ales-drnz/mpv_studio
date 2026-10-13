import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/shell/desktop_shell.dart';
import 'package:mpv_studio/shell/mobile_shell.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/theme.dart';

/// Hosts a shell the way AppShell does, keeping the selected section.
class _Host extends StatefulWidget {
  final bool desktop;
  const _Host({required this.desktop});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Section section = Section.nowPlaying;

  @override
  Widget build(BuildContext context) {
    void select(Section s) => setState(() => section = s);
    final body = Center(child: Text('page ${section.name}'));
    final mini = section == Section.nowPlaying
        ? null
        : const SizedBox(key: ValueKey('mini'), height: 56);
    return Scaffold(
      body: widget.desktop
          ? DesktopShell(
              section: section,
              onSelect: select,
              body: body,
              miniPlayer: mini,
            )
          : MobileShell(
              section: section,
              onSelect: select,
              body: body,
              miniPlayer: mini,
            ),
    );
  }
}

Future<void> _pump(WidgetTester tester, Widget host, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: host));
  await tester.pumpAndSettle();
}

void main() {
  test('four mobile tabs, the rest in More', () {
    expect(Section.tabs, [
      Section.nowPlaying,
      Section.queue,
      Section.stream,
      Section.effects,
    ]);
    expect(Section.more, [Section.engine, Section.settings, Section.console]);
  });

  group('mobile', () {
    const phone = Size(390, 844);

    testWidgets('the tab bar has Play, Queue, Stream, FX and More', (
      tester,
    ) async {
      await _pump(tester, const _Host(desktop: false), phone);
      for (final label in ['Play', 'Queue', 'Stream', 'FX', 'More']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Engine'), findsNothing);
    });

    testWidgets('More opens Engine, Settings and Console', (tester) async {
      await _pump(tester, const _Host(desktop: false), phone);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Engine'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Console'), findsOneWidget);

      await tester.tap(find.text('Engine'));
      await tester.pumpAndSettle();
      expect(find.text('page engine'), findsOneWidget);
      expect(find.text('Engine'), findsNothing, reason: 'sheet closed');
      // The More tab now shows the Engine icon.
      expect(find.byIcon(Section.engine.activeIcon), findsOneWidget);
    });

    testWidgets('a tab switches section', (tester) async {
      await _pump(tester, const _Host(desktop: false), phone);
      await tester.tap(find.text('Queue'));
      await tester.pumpAndSettle();
      expect(find.text('page queue'), findsOneWidget);
    });

    testWidgets('the mini-player sits above the tab bar off Playback', (
      tester,
    ) async {
      await _pump(tester, const _Host(desktop: false), phone);
      expect(find.byKey(const ValueKey('mini')), findsNothing);

      await tester.tap(find.text('FX'));
      await tester.pumpAndSettle();
      final mini = tester.getRect(find.byKey(const ValueKey('mini')));
      final tab = tester.getRect(find.text('FX'));
      expect(mini.bottom, lessThanOrEqualTo(tab.top));
      expect(mini.bottom, greaterThan(phone.height - 120));
    });

    testWidgets('tabs carry tooltips and selected semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const _Host(desktop: false), phone);
      expect(find.byTooltip('More sections'), findsOneWidget);
      expect(find.byTooltip('Effects'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Play')),
        matchesSemantics(
          label: 'Play',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('desktop', () {
    const desktop = Size(1280, 800);

    testWidgets('the sidebar lists every section, Engine included', (
      tester,
    ) async {
      await _pump(tester, const _Host(desktop: true), desktop);
      for (final s in Section.values) {
        expect(find.text(s.title), findsOneWidget, reason: s.title);
      }
      await tester.tap(find.text('Engine'));
      await tester.pumpAndSettle();
      expect(find.text('page engine'), findsOneWidget);
    });

    testWidgets('the mini-player runs along the bottom off Playback', (
      tester,
    ) async {
      await _pump(tester, const _Host(desktop: true), desktop);
      expect(find.byKey(const ValueKey('mini')), findsNothing);

      await tester.tap(find.text('Queue'));
      await tester.pumpAndSettle();
      final mini = tester.getRect(find.byKey(const ValueKey('mini')));
      expect(mini.bottom, desktop.height);
      expect(mini.width, desktop.width);
    });
  });
}
