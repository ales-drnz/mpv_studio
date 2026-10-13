import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/shell/desktop_shell.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/shell/mobile_shell.dart';
import 'package:mpv_studio/shell/rail_shell.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/tokens.dart';

import '../support/layout_harness.dart';

void main() {
  group('navigation follows the window class', () {
    final expected = {
      '360x780': MobileShell,
      '412x915': MobileShell,
      '780x360': RailShell,
      '915x412': RailShell,
      '800x1280': RailShell,
      '1024x700': DesktopShell,
      '1440x900': DesktopShell,
      '1920x1080': DesktopShell,
      '2560x1080': DesktopShell,
    };
    for (final s in studioSizes) {
      testWidgets('$s uses ${expected[s.name]}', (tester) async {
        await pumpShell(tester, size: s.size, input: inputFor(s));
        expect(find.byType(expected[s.name]!), findsOneWidget);
        expect(find.byType(MiniPlayer), findsOneWidget);
        expectNoOverflow(tester, reason: s.name);
      });
    }

    testWidgets('a low window puts the mini-player in the rail', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(780, 360));
      final mini = tester.widget<MiniPlayer>(find.byType(MiniPlayer));
      expect(mini.variant, MiniPlayerVariant.rail);
    });

    testWidgets('resizing keeps the section and its state', (tester) async {
      await pumpShell(tester, size: const Size(1440, 900));
      await tester.enterText(find.byType(EditableText).first, 'kept');
      setStudioView(tester, const Size(360, 780));
      await tester.pumpAndSettle();
      expect(find.byType(MobileShell), findsOneWidget);
      expect(find.text('page queue'), findsOneWidget);
      expect(find.text('kept'), findsOneWidget);
    });
  });

  group('the shell consumes the safe area once', () {
    for (final name in ['412x915', '915x412', '1024x700']) {
      testWidgets('pages see no insets at $name', (tester) async {
        final size = studioSize(name).size;
        EdgeInsets? seen;
        await pumpShell(
          tester,
          size: size,
          input: InputMode.touch,
          padding: phoneInsets(size),
          page: (section) => Builder(
            builder: (context) {
              if (section == Section.queue) {
                seen = MediaQuery.paddingOf(context);
              }
              return const SizedBox.expand();
            },
          ),
        );
        expect(seen, EdgeInsets.zero);
      });
    }

    testWidgets('a page frame title sits right under the inset', (
      tester,
    ) async {
      await pumpShell(
        tester,
        size: const Size(412, 915),
        input: InputMode.touch,
        padding: phoneInsets(const Size(412, 915)),
      );
      final header = tester.getRect(find.byType(PageHeader));
      // The 24 status bar inset plus the header's own 8 top padding on a
      // phone.
      expect(header.top, 24 + Tokens.s8);
    });
  });

  group('text scaled to 1.3 does not overflow', () {
    for (final name in ['360x780', '780x360']) {
      for (final section in Section.values) {
        testWidgets('$name on ${section.name}', (tester) async {
          await pumpShell(
            tester,
            size: studioSize(name).size,
            section: section,
            input: InputMode.touch,
            textScale: 1.3,
            padding: phoneInsets(studioSize(name).size),
          );
          expectNoOverflow(tester);
        });
      }
    }

    testWidgets('the More sheet at 360x780', (tester) async {
      await pumpShell(
        tester,
        size: const Size(360, 780),
        input: InputMode.touch,
        textScale: 1.3,
      );
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Console'),
        ),
        findsOneWidget,
      );
      expect(find.text('Theme: Dark'), findsNothing);
      expectNoOverflow(tester);
    });
  });

  group('Android back', () {
    Future<bool> back(WidgetTester tester) async {
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      return handled;
    }

    testWidgets('closes the More sheet, then returns to Playback', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(360, 780));
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);

      await back(tester);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('page queue'), findsOneWidget);

      await back(tester);
      expect(find.text('page nowPlaying'), findsOneWidget);
    });

    testWidgets('pops a pushed detail before leaving the section', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(360, 780));
      Navigator.of(tester.element(find.text('page queue'))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('detail')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);

      await back(tester);
      expect(find.text('detail'), findsNothing);
      expect(find.text('page queue'), findsOneWidget);
    });

    testWidgets('closes a TwoPane detail first', (tester) async {
      await pumpShell(tester, size: const Size(360, 780));
      final page = tester.element(find.text('page queue'));
      Navigator.of(
        page,
      ).push(MaterialPageRoute<void>(builder: (_) => const _TwoPaneHost()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('item'));
      await tester.pumpAndSettle();
      expect(find.text('the detail'), findsOneWidget);

      await back(tester);
      expect(find.text('the detail'), findsNothing);
      expect(find.text('item'), findsOneWidget);
    });

    testWidgets('tells predictive back the app handles it off Playback', (
      tester,
    ) async {
      final handles = <bool>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            handles.add(call.arguments as bool);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      // The app only reports to the platform while it is running.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpShell(
        tester,
        size: const Size(360, 780),
        section: Section.nowPlaying,
      );
      expect(handles.last, isFalse, reason: 'Playback lets the system exit');

      // The tab, not the page's own Queue tile.
      await tester.tap(find.byTooltip('Queue'));
      await tester.pumpAndSettle();
      expect(handles.last, isTrue, reason: 'Queue goes back to Playback');

      await back(tester);
      expect(find.text('page nowPlaying'), findsOneWidget);
      expect(handles.last, isFalse);
    });

    testWidgets('lets the system exit from Playback', (tester) async {
      await pumpShell(
        tester,
        size: const Size(360, 780),
        section: Section.nowPlaying,
      );
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await back(tester);
      expect(find.text('page nowPlaying'), findsOneWidget);
      expect(calls.map((c) => c.method), contains('SystemNavigator.pop'));
    });
  });

  group('theme', () {
    testWidgets('the shell switch changes the palette and keeps state', (
      tester,
    ) async {
      final shell = await pumpShell(tester, size: const Size(1440, 900));
      await tester.enterText(find.byType(EditableText).first, 'kept');
      expect(Palette.active, Palette.dark);
      final darkBg = Tokens.bg;

      await tester.tap(find.byTooltip('Theme: Dark'));
      await tester.pumpAndSettle();
      expect(shell.theme.mode, ThemeMode.light);
      expect(Palette.active, Palette.light);
      expect(find.byTooltip('Theme: Light'), findsOneWidget);
      expect(find.text('page queue'), findsOneWidget);
      expect(find.text('kept'), findsOneWidget);
      // The root Scaffold was rebuilt with the light background.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Palette.light.bg);
      expect(scaffold.backgroundColor, isNot(darkBg));

      await tester.tap(find.byTooltip('Theme: Light'));
      await tester.pumpAndSettle();
      expect(shell.theme.mode, ThemeMode.system);
    });

    testWidgets('system mode follows the platform brightness', (tester) async {
      final shell = await pumpShell(tester, size: const Size(1440, 900));
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      shell.theme.mode = ThemeMode.system;
      await tester.pumpAndSettle();
      expect(Palette.active, Palette.dark);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(Palette.active, Palette.light);
    });
  });

  testWidgets('F1 and the sidebar list the keyboard shortcuts', (tester) async {
    await pumpShell(tester, size: const Size(1440, 900));
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();
    expect(find.text('Play or pause'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Keyboard shortcuts'));
    await tester.pumpAndSettle();
    expect(find.text('Play or pause'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Play or pause'), findsNothing);
  });

  testWidgets('touch layouts leave the tools to Settings', (tester) async {
    await pumpShell(
      tester,
      size: const Size(1024, 700),
      input: InputMode.touch,
    );
    expect(find.text('Keyboard shortcuts'), findsNothing);
    expect(find.text('Theme: Dark'), findsNothing);
  });
}

class _TwoPaneHost extends StatefulWidget {
  const _TwoPaneHost();

  @override
  State<_TwoPaneHost> createState() => _TwoPaneHostState();
}

class _TwoPaneHostState extends State<_TwoPaneHost> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Material(
    child: TwoPane(
      list: Center(
        child: TextButton(
          onPressed: () => setState(() => _open = true),
          child: const Text('item'),
        ),
      ),
      detail: _open ? const Center(child: Text('the detail')) : null,
      onCloseDetail: () => setState(() => _open = false),
    ),
  );
}
