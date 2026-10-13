import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform/waveform_viewport.dart';

WaveformData _live({required int startSecs, required int spanSecs}) =>
    WaveformData(
      start: Duration(seconds: startSecs),
      duration: Duration(seconds: spanSecs),
      min: Float32List(4),
      max: Float32List(4),
      filled: Uint8List(4),
      live: true,
    );

void main() {
  const track = WaveformViewport(duration: Duration(minutes: 5));

  test('a track starts whole', () {
    expect(track.visibleSecs, 300);
    expect(track.canScroll, isFalse);
    expect(track.canZoomOut, isFalse);
    expect(track.canZoomIn, isTrue);
    expect(track.timeAtX(500, 1000), const Duration(seconds: 150));
  });

  test('nothing loaded shows a placeholder timeline', () {
    expect(const WaveformViewport().timelineSecs, 300);
  });

  test('zooming in centres on the playhead, zooming out fits again', () {
    final zoomed = track.zoomBy(0.1, around: const Duration(seconds: 200));
    expect(zoomed.visibleSecs, 30);
    expect(zoomed.leftRel, 185);
    expect(zoomed.canScroll, isTrue);
    final back = zoomed.zoomBy(100);
    expect(back.visibleSecs, 300);
    expect(back.canZoomOut, isFalse);
  });

  test('zooming stops at the narrowest window', () {
    expect(track.zoomBy(0.001).visibleSecs, WaveformViewport.minWindow);
  });

  test('a track shorter than the zoom floor zooms without throwing', () {
    const short = WaveformViewport(duration: Duration(seconds: 2));
    expect(short.zoomBy(0.5).visibleSecs, 2);
    expect(short.canZoomIn, isFalse);
  });

  test('scrolling stays within the track', () {
    final zoomed = track.zoomBy(0.1);
    expect(zoomed.scrollTo(-20).leftRel, 0);
    expect(zoomed.scrollTo(1000).leftRel, 270);
    expect(zoomed.scrollTo(0).scrollByPixels(100, 1000).leftRel, 3);
  });

  test('seek times clamp to the track and survive a zero width', () {
    expect(track.timeAtX(-50, 1000), Duration.zero);
    expect(track.timeAtX(5000, 1000), const Duration(minutes: 5));
    expect(track.timeAtX(10, 0), Duration.zero);
    expect(track.xOf(const Duration(seconds: 150), 1000), 500);
  });

  test('a new track resets the view; a new envelope keeps it', () {
    final zoomed = track.zoomBy(0.1).scrollTo(100);
    final sameTrack = zoomed.withSource(wave: _live(startSecs: 0, spanSecs: 1));
    expect(sameTrack.duration, zoomed.duration);
    final next = zoomed.withSource(duration: const Duration(minutes: 3));
    expect(next.visibleSecs, 180);
    expect(next.leftRel, 0);
  });

  test('a live window is anchored in media time and clamps seeks', () {
    final live = const WaveformViewport().withSource(
      wave: _live(startSecs: 100, spanSecs: 120),
    );
    expect(live.live, isTrue);
    expect(live.visibleSecs, WaveformViewport.liveWindow);
    expect(live.originSecs, 100);
    final panned = live.scrollTo(40);
    expect(panned.viewStartAbs, 140);
    // The cache slides on: the view holds its media time.
    final slid = panned.withSource(wave: _live(startSecs: 110, spanSecs: 120));
    expect(slid.viewStartAbs, 140);
    expect(slid.timeAtX(0, 300), const Duration(seconds: 140));
    expect(slid.timeAtX(-500, 300), const Duration(seconds: 110));
  });
}
