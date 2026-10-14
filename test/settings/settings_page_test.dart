import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/settings/settings_catalog.dart';
import 'package:mpv_studio/features/settings/settings_page.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/widgets/controls.dart';

import '../support/layout_harness.dart';
import 'studio_fakes.dart';

Future<SettingsHarness> pumpSettings(
  WidgetTester tester, {
  String size = '1440x900',
  InputMode? input,
  double textScale = 1,
  Map<String, Object?>? stored,
  PlayerConfiguration configuration = const PlayerConfiguration(),
}) async {
  final h = await SettingsHarness.create(
    stored: stored,
    configuration: configuration,
  );
  final s = studioSize(size);
  await pumpStudio(
    tester,
    h.wrap(const Scaffold(body: SettingsPage())),
    size: s.size,
    input: input ?? inputFor(s),
    textScale: textScale,
  );
  return h;
}

/// Scrolls [finder] into view and taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Lets the debounced settings save and the driver scan finish.
Future<void> drain(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('wide windows show the groups beside Listening', (tester) async {
    await pumpSettings(tester);
    for (final g in SettingsGroupId.values) {
      expect(find.text(g.title), findsWidgets);
    }
    expect(find.text(SettingsCatalog.speed.title), findsOneWidget);
  });

  testWidgets('search finds a setting in another group and jumps there', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.enterText(find.byType(TextField).first, 'proxy');
    await tester.pumpAndSettle();
    expect(find.text('Network, Connection'), findsOneWidget);

    await tester.tap(find.text('Network, Connection'));
    await tester.pumpAndSettle();
    // The Network group is open and the row is on screen.
    expect(find.text(SettingsCatalog.tlsVerify.title), findsOneWidget);
    final row = find.text(SettingsCatalog.httpProxy.title).last;
    expect(tester.getRect(row).top, lessThan(900));
    expect(find.text(SettingsCatalog.speed.title), findsNothing);
  });

  testWidgets('a search jump on a phone lets go of the search focus', (
    tester,
  ) async {
    await pumpSettings(tester, size: '360x780');
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'proxy');
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).first);
    final search = field.focusNode!;
    expect(search.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Network, Connection'));
    await tester.pumpAndSettle();
    expect(find.text(SettingsCatalog.tlsVerify.title), findsOneWidget);
    expect(search.hasFocus, isFalse);
    // The soft keyboard closes with it.
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('a narrow window pushes the group and back closes it', (
    tester,
  ) async {
    await pumpSettings(tester, size: '360x780');
    expect(find.text(SettingsCatalog.speed.title), findsNothing);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text(SettingsCatalog.logLevel.title), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(SettingsCatalog.logLevel.title), findsNothing);
    expect(find.text('Advanced'), findsOneWidget);
  });

  testWidgets('a refused setting becomes a guarded failure, not a crash', (
    tester,
  ) async {
    final h = await pumpSettings(tester);
    h.player.refuse.add('setShuffle');
    await tapVisible(tester, find.text(SettingsCatalog.shuffle.title).first);
    expect(h.player.calls, contains('setShuffle true'));
    expect(h.failures, hasLength(1));
    expect(h.failures.single, isA<MpvCommandException>());
  });

  testWidgets('a creation-only change raises the restart banner', (
    tester,
  ) async {
    final h = await pumpSettings(tester);
    expect(find.text('Restart player'), findsNothing);
    h.settings.recordNormalizeDownmix(true);
    await tester.pumpAndSettle();
    expect(
      find.text('Applies after a player restart: Normalize downmix.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Restart player'));
    expect(h.restarts, 1);
    await drain(tester);
  });

  testWidgets('the HLS variant applies at runtime', (tester) async {
    final h = await pumpSettings(tester);
    await tester.tap(find.text('Network').first);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Lowest'));
    expect(h.player.calls, contains('setHlsBitrate HlsBitrate.min'));
    expect(find.textContaining('next launch'), findsNothing);
  });

  testWidgets('Ctrl+F focuses the search field', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text(SettingsCatalog.speed.title));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('Advanced reopens the welcome screen', (tester) async {
    final h = await pumpSettings(tester);
    await tester.tap(find.text('Advanced').first);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Show'));
    expect(h.welcomes, 1);
  });

  testWidgets('no overflow at text scale 1.3 on a 360 wide phone', (
    tester,
  ) async {
    await pumpSettings(tester, size: '360x780', textScale: 1.3);
    expectNoOverflow(tester, reason: 'group list');
    for (final g in SettingsGroupId.values) {
      await tester.tap(find.text(g.title));
      await tester.pumpAndSettle();
      // Walk the whole group: every row is laid out on the way.
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      while (position.pixels < position.maxScrollExtent) {
        position.jumpTo(position.pixels + 300);
        await tester.pump();
        expectNoOverflow(tester, reason: '${g.title} at ${position.pixels}');
      }
      await drain(tester);
      expectNoOverflow(tester, reason: g.title);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a new scope reloads the sections that keep local state', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      stored: {
        'rawOptions': [
          ['cache-secs', '10'],
        ],
        'sessionOn': true,
      },
    );
    await tester.tap(find.text('Advanced').first);
    await tester.pumpAndSettle();
    expect(find.text('cache-secs=10'), findsOneWidget);

    // The same page, now on another player and settings (a restart).
    final next = await SettingsHarness.create(
      stored: {
        'rawOptions': [
          ['cache-secs', '99'],
        ],
        'sessionOn': false,
      },
    );
    await pumpStudio(
      tester,
      next.wrap(const Scaffold(body: SettingsPage())),
      size: studioSize('1440x900').size,
    );
    expect(find.text('cache-secs=99'), findsOneWidget);

    await tester.tap(find.text('Listening').first);
    await tester.pumpAndSettle();
    final publish = find.text(SettingsCatalog.sessionPublish.title);
    await tester.ensureVisible(publish);
    await tester.pumpAndSettle();
    final row = tester.widget<SwitchRow>(
      find.ancestor(of: publish, matching: find.byType(SwitchRow)),
    );
    expect(row.value, isFalse);
    await drain(tester);
  });

  testWidgets('devices with the same description show their ids', (
    tester,
  ) async {
    final h = await SettingsHarness.create();
    const pipewire = Device(
      name: 'pipewire/alsa_output.usb-Focusrite_Scarlett_Solo',
      description: 'Scarlett Solo USB',
    );
    const pulse = Device(
      name: 'pulse/alsa_output.usb-Focusrite_Scarlett_Solo',
      description: 'Scarlett Solo USB',
    );
    h.player.emit(
      (s) => s.copyWith(
        audioDevices: const [Device.auto, pipewire, pulse],
        audioDevice: pipewire,
      ),
    );
    await pumpStudio(
      tester,
      h.wrap(const Scaffold(body: SettingsPage())),
      size: studioSize('1440x900').size,
    );
    await tester.tap(find.text('Output').first);
    await tester.pumpAndSettle();
    // Closed, the control reads the description alone.
    expect(find.text(pipewire.name), findsNothing);
    final control = find.descendant(
      of: find.ancestor(
        of: find.text(SettingsCatalog.device.title),
        matching: find.byType(DropdownRow<Device>),
      ),
      matching: find.byType(AppDropdown<Device>),
    );
    await tester.tap(control);
    await tester.pumpAndSettle();
    // Open, every device carries its id under the description.
    expect(find.text('Scarlett Solo USB'), findsNWidgets(3));
    expect(find.text(pipewire.name), findsOneWidget);
    expect(find.text(pulse.name), findsOneWidget);
    await tester.tap(find.text(pulse.name));
    await tester.pumpAndSettle();
    // The pick still sets the device by its name.
    expect(h.player.calls.last, startsWith('setAudioDevice'));
    expect(h.player.calls.last, contains(pulse.name));
    await drain(tester);
  });
}
