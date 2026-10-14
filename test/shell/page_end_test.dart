import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/console/console_page.dart';
import 'package:mpv_studio/features/console/widgets/console_log_view.dart';
import 'package:mpv_studio/features/effects/effects_page.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/rack_environment.dart';
import 'package:mpv_studio/features/engine/engine_page.dart';
import 'package:mpv_studio/features/now_playing/now_playing_page.dart';
import 'package:mpv_studio/features/now_playing/widgets/spectrum_curve.dart';
import 'package:mpv_studio/features/onboarding/onboarding.dart';
import 'package:mpv_studio/features/queue/queue_page.dart';
import 'package:mpv_studio/features/settings/settings_page.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/samba/samba_share.dart';
import 'package:mpv_studio/features/stream/samba/samba_tab.dart';
import 'package:mpv_studio/features/stream/signed_url_resolver.dart';
import 'package:mpv_studio/features/stream/stream_page.dart';
import 'package:mpv_studio/shell/mobile_shell.dart';
import 'package:mpv_studio/shell/nav_parts.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/shell/snack_clearance.dart';
import 'package:mpv_studio/studio/playback_issues.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../console/console_fixture.dart';
import '../now_playing/playback_fake.dart';
import '../queue/queue_fake.dart';
import '../settings/studio_fakes.dart';
import '../stream/stream_fakes.dart';
import '../support/demo_page.dart';
import '../support/fake_engine.dart';
import '../support/fake_player.dart';
import '../support/layout_harness.dart';

/// Every page, in the shell at a desktop and a phone size, scrolled to the
/// end: the last item of every scroll view ends exactly the gutter above
/// the visible edge of the page (the stage panel edge on a desktop, the
/// top of the mini-player over the tab bar on a phone), so no card is cut
/// by the edge or by a line above it, and every page ends the same way.
void main() {
  setUpAll(loadStudioFonts);

  const sizes = ['1440x900', '412x915'];

  Future<void> pumpPage(
    WidgetTester tester,
    String size,
    Section section,
    Widget page, {
    FakePlayer? player,
  }) async {
    final s = studioSize(size);
    final input = inputFor(s);
    await pumpShell(
      tester,
      size: s.size,
      section: section,
      input: input,
      padding: input == InputMode.touch ? phoneInsets(s.size) : EdgeInsets.zero,
      player: player,
      page: (sec) => sec == section ? page : DemoPage(section: sec),
    );
    // Lists that page or list folders deliver after the first frames.
    await tester.pumpAndSettle();
  }

  /// The visible bottom edge of the page: the inside of the stage panel,
  /// or the top of the mini-player and tab bar on a phone.
  double edgeOf(WidgetTester tester) {
    final mobile = find.byType(MobileShell);
    if (mobile.evaluate().isNotEmpty) {
      return tester
          .getRect(
            find.descendant(of: mobile, matching: find.byType(SnackObstacle)),
          )
          .top;
    }
    return tester
        .getRect(
          find
              .descendant(
                of: find.byType(StagePanel),
                matching: find.byType(ClipRRect),
              )
              .first,
        )
        .bottom;
  }

  double gutterOf(WidgetTester tester) =>
      tester.element(find.byType(PageFrame)).layout.gutter;

  /// Scroll chrome, painted over the whole view: not an item.
  bool chrome(CustomPainter? p) =>
      p is ScrollbarPainter || '${p.runtimeType}'.contains('Overscroll');

  /// Whether [w] paints something the eye sees as an item: text, icons, a
  /// card or row fill, a picture, a painted chart.
  bool visual(Widget w) => switch (w) {
    RichText() || RawImage() || EditableText() || ColoredBox() => true,
    DecoratedBox() => true,
    Ink(:final decoration) => decoration != null,
    Material(:final type) => type != MaterialType.transparency,
    CustomPaint(:final painter, :final foregroundPainter) =>
      (painter != null && !chrome(painter)) ||
          (foregroundPainter != null && !chrome(foregroundPainter)),
    _ => false,
  };

  /// The lowest bottom of anything painted under [of]. The Playback
  /// spectrum is not counted: it is the one part that runs full bleed,
  /// down to the edge.
  double contentBottom(WidgetTester tester, Finder of) {
    final items = find.descendant(
      of: of,
      matching: find.byWidgetPredicate(visual),
    );
    final bleed = find
        .descendant(
          of: find.byType(SpectrumCurve),
          matching: find.byWidgetPredicate(visual),
        )
        .evaluate()
        .toSet();
    var bottom = double.negativeInfinity;
    for (final e in items.evaluate()) {
      if (bleed.contains(e)) continue;
      final box = e.renderObject;
      if (box is! RenderBox || !box.hasSize || box.size.isEmpty) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      bottom = math.max(bottom, rect.bottom);
    }
    return bottom;
  }

  Future<void> scrollToEnd(WidgetTester tester, ScrollableState s) async {
    // A lazy list only estimates its length until its end is built.
    for (var i = 0; i < 8; i++) {
      final p = s.position;
      if (p.pixels >= p.maxScrollExtent) break;
      p.jumpTo(p.maxScrollExtent);
      await tester.pumpAndSettle();
    }
  }

  /// Scrolls every vertical scroll view of the page that overflows to its
  /// end, and checks its last item ends the gutter above the edge. With
  /// [mustScroll], at least one has to overflow, so the check is real.
  Future<void> expectScrollEnds(
    WidgetTester tester,
    String reason, {
    bool mustScroll = true,
    Finder? except,
  }) async {
    final edge = edgeOf(tester);
    final gutter = gutterOf(tester);
    final skip = except == null
        ? const <Element>{}
        : find
              .descendant(of: except, matching: find.byType(Scrollable))
              .evaluate()
              .toSet();
    final scrollables = find
        .descendant(
          of: find.byType(PageFrame),
          matching: find.byType(Scrollable),
        )
        .evaluate()
        .where((e) => !skip.contains(e))
        .map((e) => (e as StatefulElement).state as ScrollableState)
        .where(
          (s) =>
              axisDirectionToAxis(s.axisDirection) == Axis.vertical &&
              s.position.maxScrollExtent > 0,
        )
        .toList();
    if (mustScroll) {
      expect(scrollables, isNotEmpty, reason: '$reason: nothing scrolls');
    }
    for (final s in scrollables) {
      await scrollToEnd(tester, s);
      final viewport = s.context.findRenderObject()! as RenderBox;
      final bottom =
          viewport.localToGlobal(Offset.zero).dy + viewport.size.height;
      expect(
        bottom,
        moreOrLessEquals(edge, epsilon: 1),
        reason: '$reason: the scroll view stops short of the edge',
      );
      final gap = edge - contentBottom(tester, find.byWidget(s.widget));
      expect(
        gap,
        moreOrLessEquals(gutter, epsilon: 1),
        reason: '$reason: the last item ends $gap above the edge',
      );
    }
  }

  /// Checks the lowest item of the whole page (a page that fills its
  /// height, like Playback) ends the gutter above the edge.
  void expectPageEnds(WidgetTester tester, String reason) {
    final gap = edgeOf(tester) - contentBottom(tester, find.byType(PageFrame));
    expect(
      gap,
      moreOrLessEquals(gutterOf(tester), epsilon: 1),
      reason: '$reason: the page ends $gap above the edge',
    );
  }

  for (final size in sizes) {
    testWidgets('Playback at $size', (tester) async {
      final player = playingTrack();
      await pumpPage(
        tester,
        size,
        Section.nowPlaying,
        NowPlayingPage(player: player, onOpenFiles: () {}, onOpenStream: () {}),
        player: player,
      );
      // The spectrum is the full-bleed exception: it reaches the edge;
      // everything else ends at least the gutter above it.
      // On a phone the column scrolls: to its end, where the spectrum is.
      final scroll = find.ancestor(
        of: find.byType(SpectrumCurve, skipOffstage: false),
        matching: find.byType(Scrollable, skipOffstage: false),
      );
      if (scroll.evaluate().isNotEmpty) {
        await scrollToEnd(tester, tester.state(scroll.first));
      }
      final edge = edgeOf(tester);
      expect(
        tester.getRect(find.byType(SpectrumCurve)).bottom,
        moreOrLessEquals(edge, epsilon: 1),
        reason: 'the spectrum ends on the edge',
      );
      final gap = edge - contentBottom(tester, find.byType(PageFrame));
      expect(
        gap,
        greaterThanOrEqualTo(gutterOf(tester) - 1),
        reason: 'the rest ends $gap above the edge',
      );
    });

    testWidgets('Queue at $size', (tester) async {
      final player = QueueFakePlayer(
        PlayerState(
          playlist: Playlist([
            for (var i = 0; i < 40; i++)
              Media(
                'https://example.test/$i.flac',
                extras: {'title': 'Track $i'},
              ),
          ], index: 1),
        ),
      );
      final details = player.details();
      addTearDown(details.dispose);
      await pumpPage(
        tester,
        size,
        Section.queue,
        Scaffold(
          body: QueueView(
            player: player,
            guard: unguarded,
            details: details,
            pickFiles: () async => const [],
            pickFolder: () async => const [],
            pickPlaylist: () async => null,
          ),
        ),
      );
      await expectScrollEnds(tester, 'queue');
    });

    group('Stream at $size', () {
      final tracks = [
        for (var i = 0; i < 30; i++)
          ServerTrack(
            id: '$i',
            title: 'Track $i',
            artist: 'Miles Davis',
            album: 'Kind of Blue',
            duration: const Duration(minutes: 5),
          ),
      ];
      final albums = [
        for (var i = 0; i < 30; i++)
          ServerAlbum(id: '$i', title: 'Album $i', artist: 'Bill Evans'),
      ];

      Future<void> stream(WidgetTester tester, Widget view) =>
          pumpPage(tester, size, Section.stream, view);

      testWidgets('lab', (tester) async {
        await stream(tester, streamView(player: StreamPlayer()));
        await expectScrollEnds(tester, 'lab');
      });

      testWidgets('chapters', (tester) async {
        final player = StreamPlayer(
          PlayerState(
            playlist: const Playlist([
              Media('https://example.test/long.flac'),
            ], index: 0),
            duration: const Duration(minutes: 40),
            chapters: [
              for (var i = 0; i < 30; i++)
                Chapter(
                  time: Duration(minutes: i),
                  title: 'Part $i',
                ),
            ],
          ),
        );
        await stream(
          tester,
          streamView(player: player, tab: StreamTab.chapters),
        );
        // The tab fits both windows; its body is the Lab's, checked above.
        await expectScrollEnds(tester, 'chapters', mustScroll: false);
      });

      testWidgets('resolver', (tester) async {
        final resolver = SignedUrlResolver();
        final entry = SignedUrlResolver.wrap('http://localhost:8000/a.flac');
        for (var i = 0; i < 12; i++) {
          resolver.resolve(
            SourceResolveRequest(
              media: Media(entry),
              uri: entry,
              isRetry: false,
            ),
          );
        }
        await stream(
          tester,
          streamView(
            player: StreamPlayer(),
            resolver: resolver,
            tab: StreamTab.resolver,
          ),
        );
        await expectScrollEnds(tester, 'resolver');
      });

      testWidgets('server sign-in', (tester) async {
        await stream(
          tester,
          streamView(player: StreamPlayer(), tab: StreamTab.plex),
        );
        await expectScrollEnds(tester, 'sign-in', mustScroll: false);
      });

      testWidgets('server songs', (tester) async {
        await stream(
          tester,
          streamView(
            player: StreamPlayer(),
            jellyfin: FakeServer(connected: true, tracks: tracks),
            tab: StreamTab.jellyfin,
          ),
        );
        await expectScrollEnds(tester, 'songs');
      });

      testWidgets('server albums and an album', (tester) async {
        await stream(
          tester,
          streamView(
            player: StreamPlayer(),
            plex: FakeServer(
              kind: ServerKind.plex,
              connected: true,
              albums: albums,
              albumTracks: {'0': tracks},
            ),
            tab: StreamTab.plex,
          ),
        );
        await tester.tap(find.text('Albums'));
        // The grid shows a spinner at its end until it asks for the next
        // page, scrolled near it: no settling before the scroll.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await expectScrollEnds(tester, 'album grid');
        await tester.drag(find.text('Album 0'), const Offset(0, 3000));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Album 0'));
        await tester.pumpAndSettle();
        await expectScrollEnds(tester, 'album tracks');
      });

      testWidgets('samba folder', (tester) async {
        final player = StreamPlayer();
        final share = FakeShare({
          '': [
            for (var i = 0; i < 30; i++)
              SambaEntry(
                name: 'Song $i.flac',
                isDirectory: false,
                size: 1000000,
              ),
          ],
        });
        await stream(
          tester,
          streamView(
            player: player,
            tab: StreamTab.samba,
            samba: SambaTab(
              actions: actionsFor(player),
              connector: (_) async => share,
              store: _SavedShare(),
            ),
          ),
        );
        await expectScrollEnds(tester, 'samba');
      });
    });

    group('Effects at $size', () {
      Future<RackController> rack(WidgetTester tester) async {
        final rack = RackController(
          FakeEngine([
            for (var i = 0; i < 14; i++) BassEffect(gain: i.toDouble()),
            const AcompressorEffect(ratio: 4),
            const EqualizerEffect(frequency: 1000, gain: 3),
          ]),
        );
        addTearDown(rack.dispose);
        await pumpPage(
          tester,
          size,
          Section.effects,
          Scaffold(
            body: RackEnvironment(
              taps: (_, _, _) => const Stream.empty(),
              pcm: const Stream.empty(),
              spectrum: const SpectrumSettings(),
              loudness: const Stream.empty(),
              child: SignalChainView(rack: rack),
            ),
          ),
        );
        return rack;
      }

      testWidgets('chain', (tester) async {
        await rack(tester);
        await expectScrollEnds(tester, 'chain');
      });

      testWidgets('stage editor', (tester) async {
        final r = await rack(tester);
        r.open(r.chain.stages.last.id);
        await tester.pumpAndSettle();
        await expectScrollEnds(tester, 'stage editor');
      });
    });

    testWidgets('Engine at $size', (tester) async {
      await pumpPage(
        tester,
        size,
        Section.engine,
        Scaffold(
          body: EnginePanel(
            player: FakePlayer(
              const PlayerState(
                playlist: Playlist([Media('https://example.test/one.flac')]),
                audioEffects: [BassEffect(gain: 4), LoudnormEffect()],
              ),
            ),
            interval: const Duration(hours: 1),
          ),
        ),
      );
      await expectScrollEnds(tester, 'engine');
    });

    group('Settings at $size', () {
      Future<void> settings(WidgetTester tester) async {
        final h = await SettingsHarness.create();
        await pumpPage(
          tester,
          size,
          Section.settings,
          h.wrap(const Scaffold(body: SettingsPage())),
        );
      }

      testWidgets('groups', (tester) async {
        await settings(tester);
        // The list fits; beside it the open group scrolls.
        await expectScrollEnds(tester, 'groups', mustScroll: false);
        await tester.pump(const Duration(seconds: 1));
      });

      for (final group in ['Listening', 'Output', 'Network', 'Advanced']) {
        testWidgets(group, (tester) async {
          await settings(tester);
          await tester.tap(find.text(group).first);
          await tester.pumpAndSettle();
          await expectScrollEnds(tester, group);
          await tester.pump(const Duration(seconds: 1));
        });
      }

      testWidgets('search results', (tester) async {
        await settings(tester);
        await tester.enterText(find.byType(TextField).first, 'a');
        await tester.pumpAndSettle();
        await expectScrollEnds(tester, 'search');
        await tester.pump(const Duration(seconds: 1));
      });
    });

    testWidgets('Console at $size', (tester) async {
      final player = consolePlayer();
      final log = consoleLog(player);
      await pumpPage(
        tester,
        size,
        Section.console,
        Scaffold(
          body: ConsoleView(player: player, log: log),
        ),
      );
      for (var i = 0; i < 200; i++) {
        player.log.add(
          MpvLogEntry(prefix: 'demux', level: LogLevel.info, text: 'line $i'),
        );
      }
      await tester.pumpAndSettle();
      // The command line ends the page, the gutter above the edge.
      expectPageEnds(tester, 'console');
      // Following the tail, the newest line sits inside the card, above
      // its padding, not under the edge.
      final card = find.byType(ConsoleLogView);
      final list = tester.state<ScrollableState>(
        find.descendant(of: card, matching: find.byType(Scrollable)),
      );
      expect(list.position.pixels, list.position.maxScrollExtent);
      final last = tester.getRect(find.textContaining('line 199'));
      expect(
        tester.getRect(card).bottom - last.bottom,
        moreOrLessEquals(16 + 1, epsilon: 1),
      );
      await expectScrollEnds(
        tester,
        'console',
        mustScroll: false,
        except: card,
      );
    });

    testWidgets('Onboarding at $size', (tester) async {
      final s = studioSize(size);
      final input = inputFor(s);
      final insets = input == InputMode.touch
          ? phoneInsets(s.size)
          : EdgeInsets.zero;
      final card = input == InputMode.pointer;
      await pumpStudio(
        tester,
        OnboardingView(
          card: card,
          actions: OnboardingActions(
            player: StudioFakePlayer(),
            guard: <T>(call) async => call(),
          ),
        ),
        size: s.size,
        input: input,
        padding: insets,
        // Large text, so the page has to scroll.
        textScale: 2,
      );
      final gutter = tester.element(find.byType(OnboardingView)).layout.gutter;
      final scrollable = find.descendant(
        of: find.byType(OnboardingView),
        matching: find.byType(Scrollable),
      );
      final scroll = tester.state<ScrollableState>(scrollable);
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      await scrollToEnd(tester, scroll);
      final gap = s.height - insets.bottom - contentBottom(tester, scrollable);
      // The card has its own padding inside; the full page ends on the
      // Skip button.
      expect(gap, moreOrLessEquals(gutter, epsilon: 1));
    });
  }
}

class _SavedShare extends NoSambaLogin {
  @override
  Future<SambaLogin?> load() async =>
      const SambaLogin(host: 'nas.local', share: 'Music');
}
