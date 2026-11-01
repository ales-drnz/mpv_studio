import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/settings/settings_catalog.dart';
import 'package:mpv_studio/studio/app_info.dart';

import 'settings_page_test.dart' show pumpSettings, tapVisible;
import '../support/layout_harness.dart';

void main() {
  setUpAll(loadStudioFonts);
  tearDown(LicenseRegistry.reset);

  testWidgets('Open source licenses opens the license page, with the texts '
      'registered for libmpv', (tester) async {
    // What mpv_audio_kit registers at MpvAudioKit.ensureInitialized.
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks(['libmpv'], 'libmpv for web: LGPL'),
      ),
    );
    await pumpSettings(tester);
    await tester.tap(find.text('Advanced').first);
    await tester.pumpAndSettle();
    expect(find.text(SettingsCatalog.licenses.title), findsOneWidget);

    await tapVisible(tester, find.text('View'));
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text(appName), findsWidgets);
    expect(find.text(appVersion), findsOneWidget);
    // The page reads the registry outside the fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('libmpv'), findsWidgets);
  });

  test('search finds the licenses', () {
    expect(searchSettings('licence').first, SettingsCatalog.licenses);
    expect(searchSettings('open source').first, SettingsCatalog.licenses);
  });
}
