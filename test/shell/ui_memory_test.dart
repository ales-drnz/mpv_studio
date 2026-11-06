import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/settings/settings_catalog.dart';
import 'package:mpv_studio/features/settings/settings_page.dart';
import 'package:mpv_studio/shell/desktop_shell.dart';
import 'package:mpv_studio/shell/router.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/shell/ui_memory.dart';

import '../settings/studio_fakes.dart';
import '../stream/stream_fakes.dart';
import '../support/demo_page.dart';
import '../support/layout_harness.dart';

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('the app opens on the section left last', (tester) async {
    final router = createAppRouter(
      initialSection: Section.console,
      shell: (shell) => Scaffold(body: shell),
      page: (s) => DemoPage(section: s),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('page console'), findsOneWidget);
  });

  testWidgets('the sidebar opens collapsed as it was left', (tester) async {
    final values = <String, Object?>{'sidebarCollapsed': true};
    await pumpStudio(
      tester,
      MapUiMemory(
        values: values,
        child: const DesktopShell(
          section: Section.queue,
          onSelect: _none,
          body: SizedBox.expand(),
        ),
      ),
      size: const Size(1440, 900),
    );
    expect(find.byTooltip('Expand the sidebar'), findsOneWidget);
    await tester.tap(find.byTooltip('Expand the sidebar'));
    await tester.pumpAndSettle();
    expect(values['sidebarCollapsed'], isFalse);
  });

  testWidgets('the Stream page opens on the tab left last', (tester) async {
    final values = <String, Object?>{'streamTab': 'resolver'};
    await pumpStudio(
      tester,
      MapUiMemory(
        values: values,
        child: streamView(player: StreamPlayer()),
      ),
      size: const Size(1440, 900),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resolver'), findsWidgets);
    await tester.tap(find.text('Chapters').first);
    await tester.pumpAndSettle();
    expect(values['streamTab'], 'chapters');
  });

  testWidgets('Settings opens on the group left last', (tester) async {
    final values = <String, Object?>{'settingsGroup': 'network'};
    final h = await SettingsHarness.create();
    await pumpStudio(
      tester,
      MapUiMemory(
        values: values,
        child: h.wrap(const Scaffold(body: SettingsPage())),
      ),
      size: const Size(1440, 900),
    );
    expect(find.text(SettingsCatalog.httpProxy.title), findsWidgets);
    await tester.tap(find.text('Advanced').first);
    await tester.pumpAndSettle();
    expect(values['settingsGroup'], 'advanced');
  });
}

void _none(Section _) {}
