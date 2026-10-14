import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/effects_page.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/rack_environment.dart';
import 'package:mpv_studio/features/queue/queue_details.dart';
import 'package:mpv_studio/features/queue/queue_page.dart';
import 'package:mpv_studio/features/settings/settings_page.dart';
import 'package:mpv_studio/studio/playback_issues.dart';
import 'package:mpv_studio/studio/studio_host.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';
import 'package:mpv_studio/ui/theme.dart';

import '../queue/queue_fake.dart';
import '../settings/studio_fakes.dart';
import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

/// A stand-in studio: the services the Queue, Effects and Settings pages
/// hold, which a restart disposes as the real one does.
class _Studio {
  _Studio(this.name, this.settings)
    : player = QueueFakePlayer(
        const PlayerState(
          playlist: Playlist([
            Media('https://example.test/a.flac'),
            Media('https://example.test/b.flac'),
          ], index: 0),
        ),
      ) {
    details = player.details();
    rack = RackController(FakeEngine([const BassEffect(gain: 3)]));
  }

  final String name;
  final QueueFakePlayer player;
  final SettingsHarness settings;
  late final QueueDetails details;
  late final RackController rack;

  void shutDown() {
    details.dispose();
    rack.dispose();
  }
}

Widget _pages(_Studio studio) => MaterialApp(
  theme: AppTheme.of(Palette.dark, input: InputMode.pointer),
  builder: (context, child) => LayoutScope(child: child!),
  home: Scaffold(
    body: Row(
      children: [
        Expanded(
          child: QueueView(
            player: studio.player,
            guard: unguarded,
            details: studio.details,
            pickFiles: () async => const [],
            pickFolder: () async => const [],
            pickPlaylist: () async => null,
          ),
        ),
        Expanded(
          child: RackEnvironment(
            taps: (_, _, _) => const Stream.empty(),
            pcm: const Stream.empty(),
            spectrum: const SpectrumSettings(),
            loudness: const Stream.empty(),
            child: SignalChainView(rack: studio.rack),
          ),
        ),
        Expanded(child: studio.settings.wrap(const SettingsPage())),
      ],
    ),
  ),
);

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('a restart with Queue, Effects and Settings mounted swaps '
      'cleanly', (tester) async {
    setStudioView(tester, const Size(2400, 900));
    final first = _Studio('one', await SettingsHarness.create());
    final second = _Studio('two', await SettingsHarness.create());
    addTearDown(second.shutDown);
    final next = Completer<_Studio>();
    var shutDownWhileMounted = false;
    late StudioRestart restart;

    await tester.pumpWidget(
      StudioHost<_Studio>(
        initial: first,
        restart: (old) {
          shutDownWhileMounted = find.byType(QueueView).evaluate().isNotEmpty;
          old.shutDown();
          return next.future;
        },
        launch: () async => second,
        busyBuilder: (_) => const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('restarting'),
        ),
        errorBuilder: (_, error, _) => Directionality(
          textDirection: TextDirection.ltr,
          child: Text('failed: $error'),
        ),
        builder: (context, studio, r) {
          restart = r;
          return _pages(studio);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QueueView), findsOneWidget);
    expect(find.byType(SignalChainView), findsOneWidget);
    expect(find.byType(SettingsPage), findsOneWidget);

    final done = restart.run();
    await tester.pump();
    await tester.pump();
    // The old studio went down only once its pages were gone.
    expect(shutDownWhileMounted, isFalse);
    expect(find.text('restarting'), findsOneWidget);
    // The old player still reports as it shuts down: nothing listens.
    first.player.emit(
      (s) => s.copyWith(playlist: const Playlist([], index: -1)),
    );
    await tester.pump();

    next.complete(second);
    await done;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(QueueView), findsOneWidget);
    expect(find.byType(SignalChainView), findsOneWidget);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('restarting'), findsNothing);
  });
}
