import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// A made-up album for the showcase scenes. [cover] picks its cover
/// from `paintCover`.
class ShowcaseAlbum {
  const ShowcaseAlbum(
    this.title,
    this.artist,
    this.year,
    this.cover,
    this.tracks,
  );

  final String title;
  final String artist;
  final int year;
  final int cover;
  final List<(String, Duration)> tracks;

  /// The album's tracks as local files, the way a folder import names
  /// them.
  List<ShowcaseTrack> get files => [
    for (var i = 0; i < tracks.length; i++)
      ShowcaseTrack(
        title: tracks[i].$1,
        artist: artist,
        album: title,
        length: tracks[i].$2,
        cover: cover,
        number: i + 1,
      ),
  ];
}

/// One made-up track and where it would come from.
class ShowcaseTrack {
  const ShowcaseTrack({
    required this.title,
    required this.artist,
    required this.album,
    required this.length,
    required this.cover,
    required this.number,
    this.url,
  });

  final String title;
  final String artist;
  final String album;
  final Duration length;
  final int cover;
  final int number;

  /// Where it streams from, for a track off a server; null for a file.
  final String? url;

  /// The same track streamed from [address] instead.
  ShowcaseTrack streamedFrom(String address) => ShowcaseTrack(
    title: title,
    artist: artist,
    album: album,
    length: length,
    cover: cover,
    number: number,
    url: address,
  );

  String get fileName => '${number.toString().padLeft(2, '0')} $title.flac';

  /// A local file under a made-up music folder.
  String get path => '/music/$artist/$album/$fileName';

  /// The queue entry for the file, with its tags already read.
  Media get media => Media(
    url ?? 'file://$path',
    extras: {
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': length.inMilliseconds,
    },
  );
}

/// The shelf every showcase scene draws from: fictional artists, albums
/// and tracks only.
const List<ShowcaseAlbum> showcaseAlbums = [
  ShowcaseAlbum('Night Ferry', 'Juniper Avenue', 2024, 0, [
    ('Departures', Duration(minutes: 3, seconds: 12)),
    ('Paper Lanterns', Duration(minutes: 4, seconds: 21)),
    ('Harbour Lights', Duration(minutes: 4, seconds: 52)),
    ('Lowtide', Duration(minutes: 3, seconds: 58)),
    ('Salt and Cedar', Duration(minutes: 5, seconds: 7)),
    ('Northbound', Duration(minutes: 3, seconds: 44)),
  ]),
  ShowcaseAlbum('Glass Orchard', 'Mira Okafor', 2023, 5, [
    ('Sundial', Duration(minutes: 3, seconds: 31)),
    ('Orchard Light', Duration(minutes: 4, seconds: 12)),
    ('Tin Roof Rain', Duration(minutes: 3, seconds: 49)),
    ('Glasshouse', Duration(minutes: 4, seconds: 33)),
  ]),
  ShowcaseAlbum('Static Bloom', 'The Velvet Parallels', 2022, 2, [
    ('Static Bloom', Duration(minutes: 4, seconds: 5)),
    ('Satellite Hymn', Duration(minutes: 3, seconds: 37)),
    ('Afterimage', Duration(minutes: 4, seconds: 40)),
    ('Neon Psalm', Duration(minutes: 3, seconds: 26)),
  ]),
  ShowcaseAlbum('Fjord Sessions', 'Halvorsen Trio', 2021, 7, [
    ('Kveld', Duration(minutes: 6, seconds: 12)),
    ('Drift Ice', Duration(minutes: 5, seconds: 28)),
    ('Lantern Bay', Duration(minutes: 7, seconds: 3)),
  ]),
  ShowcaseAlbum('Quiet Machines', 'Lumen Hollow', 2025, 3, [
    ('Relay', Duration(minutes: 3, seconds: 22)),
    ('Copper Wire', Duration(minutes: 4, seconds: 1)),
    ('Low Orbit', Duration(minutes: 5, seconds: 15)),
  ]),
  ShowcaseAlbum('Casa Azul', 'Nadia Ferreira', 2020, 9, [
    ('Maré', Duration(minutes: 3, seconds: 55)),
    ('Azulejo', Duration(minutes: 4, seconds: 18)),
    ('Varanda', Duration(minutes: 3, seconds: 41)),
  ]),
  ShowcaseAlbum('Field Notes', 'Juniper Avenue', 2021, 6, [
    ('Overgrown', Duration(minutes: 3, seconds: 48)),
    ('Weathervane', Duration(minutes: 4, seconds: 9)),
  ]),
  ShowcaseAlbum('Slow Light', 'Mira Okafor', 2025, 10, [
    ('First Frost', Duration(minutes: 3, seconds: 27)),
    ('Amber Hours', Duration(minutes: 4, seconds: 44)),
  ]),
];

/// The album called [title].
ShowcaseAlbum showcaseAlbum(String title) =>
    showcaseAlbums.firstWhere((a) => a.title == title);
