import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/settings/sections/connection_section.dart';
import 'package:mpv_studio/features/settings/sections/driver_section.dart';
import 'package:mpv_studio/features/settings/settings_catalog.dart';
import 'package:mpv_studio/features/settings/settings_groups.dart';

import '../support/layout_harness.dart';
import 'studio_fakes.dart';

/// In a browser, what the browser decides is not offered as a setting.
void main() {
  testWidgets('TLS, proxy and cookies are the browser\'s', (tester) async {
    final h = await SettingsHarness.create();
    await pumpStudio(
      tester,
      h.wrap(
        const Scaffold(
          body: SingleChildScrollView(child: ConnectionSection(web: true)),
        ),
      ),
    );
    expect(find.text(SettingsCatalog.tlsVerify.title), findsNothing);
    expect(find.text(SettingsCatalog.httpProxy.title), findsNothing);
    expect(find.text(SettingsCatalog.cookies.title), findsNothing);
    expect(find.textContaining('the browser'), findsOneWidget);
    expect(find.text(SettingsCatalog.networkTimeout.title), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  test('the output has no driver or passthrough in a browser', () {
    final web = settingsSections(SettingsGroupId.output, web: true);
    expect(web.whereType<DriverSection>(), isEmpty);
    final native = settingsSections(SettingsGroupId.output);
    expect(native.whereType<DriverSection>(), isNotEmpty);
  });
}
