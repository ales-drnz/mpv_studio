import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/now_playing/widgets/cover_art.dart';

import '../support/fake_player.dart';

/// The cover of a file without an embedded picture comes from an image
/// in its folder, which the engine loads as an external album art track
/// when Cover art is on (it never reaches stream.coverArt).
void main() {
  testWidgets('an image in the folder is the cover', (tester) async {
    final dir = Directory.systemTemp.createTempSync('cover_art_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/cover.png')..writeAsBytesSync(_png);
    final player = FakePlayer(
      PlayerState(
        playlist: const Playlist([Media('file:///music/a.flac')]),
        tracks: [
          const MpvTrack(id: 1, type: 'audio', selected: true),
          MpvTrack(
            id: 2,
            type: 'video',
            image: true,
            albumArt: true,
            external: true,
            externalFilename: file.path,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: CoverArtView(player: player, size: 120)),
    );
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    expect((image.image as FileImage).file.path, file.path);
    expect(find.bySemanticsLabel('Cover art'), findsOneWidget);
  });
}

/// A 1x1 transparent PNG.
const _png = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
