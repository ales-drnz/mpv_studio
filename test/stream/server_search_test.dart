import 'dart:convert';

import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:dart_plex/dart_plex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mpv_studio/features/stream/jellyfin_server.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/plex_server.dart';

/// Answers each request with what [route] returns, and records the requests.
class _Fake {
  _Fake(this.route);

  final Object? Function(String path, Map<String, dynamic> query) route;
  final requests = <http.BaseRequest>[];

  late final client = MockClient((request) async {
    requests.add(request);
    final data = route(request.url.path, _query(request.url));
    if (data == null) throw http.ClientException('unexpected', request.url);
    return http.Response(
      jsonEncode(data),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// The query of [url], a list for a key given more than once.
Map<String, dynamic> _query(Uri url) => {
  for (final e in url.queryParametersAll.entries)
    e.key: e.value.length == 1 ? e.value.single : e.value,
};

// A tiny Jellyfin library: Lantern Coast has two songs on one album,
// neither with "Lantern Coast" in its title; "Amber Road" is by someone else.
const _songs = [
  {
    'Id': 's1',
    'Name': 'Amber',
    'Artists': ['Lantern Coast'],
    'Album': 'Harbour Lights',
  },
  {
    'Id': 's2',
    'Name': 'Low Tide',
    'Artists': ['Lantern Coast'],
    'Album': 'Harbour Lights',
  },
  {
    'Id': 's3',
    'Name': 'Amber Road',
    'Artists': ['The Weavers'],
    'Album': 'Loom',
  },
];

Map<String, dynamic> _jfPage(List<Map<String, Object>> items) => {
  'Items': items,
  'TotalRecordCount': items.length,
};

/// A list query value, sent repeated or comma-separated.
List<String> _list(Object? v) => [
  if (v is List) ...v.map((e) => '$e') else if (v != null) ...'$v'.split(','),
];

Object? _jellyfin(String path, Map<String, dynamic> q) {
  final term = (q['searchTerm'] as String?)?.toLowerCase();
  if (path.endsWith('/Artists')) {
    return _jfPage([
      if (term != null && 'lantern coast'.contains(term))
        {'Id': 'a1', 'Name': 'Lantern Coast', 'Type': 'MusicArtist'},
    ]);
  }
  if (!path.endsWith('/Items')) return null;
  final types = _list(q['includeItemTypes']);
  if (types.contains('MusicAlbum')) {
    final albums = [
      {'Id': 'al1', 'Name': 'Harbour Lights', 'AlbumArtist': 'Lantern Coast'},
      {'Id': 'al2', 'Name': 'Loom', 'AlbumArtist': 'The Weavers'},
    ];
    if (_list(q['artistIds']).contains('a1')) return _jfPage([albums[0]]);
    return _jfPage([
      for (final a in albums)
        if (term == null || (a['Name']!).toLowerCase().contains(term)) a,
    ]);
  }
  final artistIds = _list(q['artistIds']);
  final albumIds = _list(q['albumIds']);
  return _jfPage([
    for (final s in _songs)
      if (artistIds.isNotEmpty)
        if (artistIds.contains('a1') &&
            (s['Artists'] as List).contains('Lantern Coast'))
          s
        else
          ...[]
      else if (albumIds.isNotEmpty)
        if (albumIds.contains('al2') && s['Album'] == 'Loom') s else ...[]
      else if (term == null ||
          (s['Name'] as String).toLowerCase().contains(term))
        s,
  ]);
}

JellyfinServer _jellyfinServer(_Fake fake) {
  final client = JellyfinClient(
    baseUrl: 'http://jf.test:8096',
    credentials: const JellyfinCredentials(
      client: 'MPV Studio',
      device: 'test',
      deviceId: 'test-device',
      version: '0.3.0',
    ),
    httpClient: fake.client,
  );
  client.setSession(token: 'token', userId: 'user');
  return JellyfinServer.withClient(client);
}

// The same library as a Plex section: artist 8, album 9, tracks 10.
Map<String, dynamic> _plexPage(List<Map<String, Object>> items) => {
  'MediaContainer': {
    'Metadata': items,
    'totalSize': items.length,
    'size': items.length,
  },
};

const _plexTracks = [
  {
    'ratingKey': '11',
    'type': 'track',
    'title': 'Amber',
    'grandparentTitle': 'Lantern Coast',
    'parentTitle': 'Harbour Lights',
  },
  {
    'ratingKey': '12',
    'type': 'track',
    'title': 'Low Tide',
    'grandparentTitle': 'Lantern Coast',
    'parentTitle': 'Harbour Lights',
  },
  {
    'ratingKey': '13',
    'type': 'track',
    'title': 'Amber Road',
    'grandparentTitle': 'The Weavers',
    'parentTitle': 'Loom',
  },
];
const _plexAlbums = [
  {
    'ratingKey': '21',
    'type': 'album',
    'title': 'Harbour Lights',
    'parentTitle': 'Lantern Coast',
  },
  {
    'ratingKey': '22',
    'type': 'album',
    'title': 'Loom',
    'parentTitle': 'The Weavers',
  },
];

Object? _plex(String path, Map<String, dynamic> q) {
  if (path == '/library/metadata/1/allLeaves') {
    return _plexPage(_plexTracks.sublist(0, 2));
  }
  if (path == '/library/metadata/1/children') {
    return _plexPage([_plexAlbums[0]]);
  }
  if (path == '/library/metadata/22/children') {
    return _plexPage([_plexTracks[2]]);
  }
  if (path != '/library/sections/7/all') return null;
  final title = (q['title'] as String?)?.toLowerCase() ?? '';
  final pool = switch ('${q['type']}') {
    '8' => [
      {'ratingKey': '1', 'type': 'artist', 'title': 'Lantern Coast'},
    ],
    '9' => _plexAlbums,
    _ => _plexTracks,
  };
  return _plexPage([
    for (final m in pool)
      if (m['title']!.toLowerCase().contains(title)) m,
  ]);
}

PlexServer _plexServer(_Fake fake) {
  final client = PlexClient(
    credentials: const PlexCredentials(
      clientIdentifier: 'test-client',
      product: 'MPV Studio',
      version: '0.3.0',
      device: 'test',
      deviceName: 'test',
      platform: 'Generic',
    ),
    httpClient: fake.client,
  );
  client.setToken('token');
  client.connect('http://plex.test:32400', accessToken: 'token');
  return PlexServer.withClient(client, '7');
}

List<String> _titles(LibraryPage<ServerTrack> page) => [
  for (final t in page.items) t.title,
];

void main() {
  group('Jellyfin search', () {
    test('an artist name finds that artist\'s songs', () async {
      final server = _jellyfinServer(_Fake(_jellyfin));
      final page = await server.fetchTracks(
        startIndex: 0,
        pageSize: 50,
        query: 'Lantern Coast',
      );
      expect(_titles(page), ['Amber', 'Low Tide']);
      expect(page.total, 2);
    });

    test('title matches and album matches both count', () async {
      final server = _jellyfinServer(_Fake(_jellyfin));
      final amber = await server.fetchTracks(
        startIndex: 0,
        pageSize: 50,
        query: 'amber',
      );
      expect(_titles(amber), ['Amber', 'Amber Road']);
      final loom = await server.fetchTracks(
        startIndex: 0,
        pageSize: 50,
        query: 'loom',
      );
      expect(_titles(loom), ['Amber Road']);
    });

    test('an artist name finds that artist\'s albums', () async {
      final server = _jellyfinServer(_Fake(_jellyfin));
      final page = await server.fetchAlbums(
        startIndex: 0,
        pageSize: 50,
        query: 'Lantern Coast',
      );
      expect([for (final a in page.items) a.title], ['Harbour Lights']);
    });

    test('later pages of a search read the merged list', () async {
      final fake = _Fake(_jellyfin);
      final server = _jellyfinServer(fake);
      final first = await server.fetchTracks(
        startIndex: 0,
        pageSize: 1,
        query: 'Lantern Coast',
      );
      final calls = fake.requests.length;
      final second = await server.fetchTracks(
        startIndex: 1,
        pageSize: 1,
        query: 'Lantern Coast',
      );
      expect(_titles(first), ['Amber']);
      expect(_titles(second), ['Low Tide']);
      expect(second.total, 2);
      expect(fake.requests.length, calls, reason: 'no new server query');
    });

    test('browsing without a query stays one paged server query', () async {
      final fake = _Fake(_jellyfin);
      final server = _jellyfinServer(fake);
      final page = await server.fetchTracks(startIndex: 0, pageSize: 50);
      expect(page.items, hasLength(3));
      expect(fake.requests, hasLength(1));
      expect(fake.requests.single.url.queryParameters['searchTerm'], isNull);
    });
  });

  group('Plex search', () {
    test('an artist name finds that artist\'s songs', () async {
      final server = _plexServer(_Fake(_plex));
      addTearDown(server.dispose);
      final page = await server.fetchTracks(
        startIndex: 0,
        pageSize: 50,
        query: 'Lantern Coast',
      );
      expect(_titles(page), ['Amber', 'Low Tide']);
    });

    test('an album name finds its songs after the title matches', () async {
      final server = _plexServer(_Fake(_plex));
      addTearDown(server.dispose);
      final page = await server.fetchTracks(
        startIndex: 0,
        pageSize: 50,
        query: 'loom',
      );
      expect(_titles(page), ['Amber Road']);
    });

    test('an artist name finds that artist\'s albums', () async {
      final server = _plexServer(_Fake(_plex));
      addTearDown(server.dispose);
      final page = await server.fetchAlbums(
        startIndex: 0,
        pageSize: 50,
        query: 'Lantern Coast',
      );
      expect([for (final a in page.items) a.title], ['Harbour Lights']);
    });
  });

  group('MergedSearch', () {
    test('drops repeats, keeps order and caps the list', () {
      final search = MergedSearch<String>((s) => s);
      expect(
        search.merge([
          ['a', 'b'],
          ['b', 'c'],
        ]),
        ['a', 'b', 'c'],
      );
      final many = [for (var i = 0; i < 600; i++) '$i'];
      expect(search.merge([many]), hasLength(MergedSearch.maxResults));
    });

    test('a failed search is not cached', () async {
      final search = MergedSearch<String>((s) => s);
      var fail = true;
      Future<List<Iterable<String>>> load() async {
        if (fail) throw StateError('offline');
        return [
          ['a', 'b'],
        ];
      }

      await expectLater(
        search.page('q', startIndex: 0, pageSize: 1, load: load),
        throwsStateError,
      );
      fail = false;
      final page = await search.page(
        'q',
        startIndex: 1,
        pageSize: 1,
        load: load,
      );
      expect(page.items, ['b']);
    });
  });
}
