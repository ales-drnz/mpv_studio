import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../source_failure.dart';

/// What the Samba tab signs in with.
@immutable
class SambaLogin {
  const SambaLogin({
    required this.host,
    required this.share,
    this.user = '',
    this.password = '',
    this.domain = '',
  });

  final String host;
  final String share;
  final String user;
  final String password;
  final String domain;
}

/// One entry of a share folder.
@immutable
class SambaEntry {
  const SambaEntry({
    required this.name,
    required this.isDirectory,
    this.size = 0,
  });

  final String name;
  final bool isDirectory;

  /// The file size in bytes; 0 for folders.
  final int size;
}

/// A connected SMB2 or SMB3 share, reduced to what the tab needs.
abstract class SambaShare {
  /// The entries of [path] (relative to the share root, '' for the root).
  Future<List<SambaEntry>> list(String path);

  Future<void> disconnect();
}

/// Opens a [SambaShare] for a login.
typedef SambaConnector = Future<SambaShare> Function(SambaLogin login);

/// The real share, through `dart_smb2`.
Future<SambaShare> connectSmb2(SambaLogin login) async {
  final pool = await Smb2Pool.connect(
    host: login.host,
    share: login.share,
    // With a user, an empty password logs on as that user; without one,
    // the logon is anonymous.
    user: login.user.isEmpty ? null : login.user,
    password: login.user.isEmpty ? null : login.password,
    domain: login.domain.isEmpty ? null : login.domain,
  );
  return _Smb2Share(pool);
}

class _Smb2Share implements SambaShare {
  _Smb2Share(this._pool);

  final Smb2Pool _pool;

  @override
  Future<List<SambaEntry>> list(String path) async => [
    for (final e in await _pool.listDirectory(path))
      if (e.name != '.' && e.name != '..' && (e.isDirectory || e.isFile))
        SambaEntry(name: e.name, isDirectory: e.isDirectory, size: e.size),
  ];

  @override
  Future<void> disconnect() => _pool.disconnect();
}

/// The [FailureKind] of a Samba error.
FailureKind classifySambaError(Object error) {
  if (error is Smb2Exception) {
    if (error.type == Smb2ErrorType.auth ||
        error.type == Smb2ErrorType.accessDenied) {
      return FailureKind.auth;
    }
    if (error.isNetworkFailure) return FailureKind.network;
  }
  return commonFailureKind(error) ?? FailureKind.other;
}

/// Extensions mpv can decode that the browser lists as tracks.
const sambaAudioExtensions = {
  'flac', 'mp3', 'm4a', 'm4b', 'aac', 'ogg', 'oga', 'opus', 'wav', 'aif', //
  'aiff', 'alac', 'wma', 'ape', 'wv', 'mka', 'mp2', 'caf', 'dsf', 'dff',
  'mpc',
};

/// The lower-case extension of [name], '' when it has none.
String extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// [name] without its extension (a leading dot is part of the name).
String withoutExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/// [name] inside the folder [base] ('' for the root).
String joinSambaPath(String base, String name) =>
    base.isEmpty ? name : '$base/$name';

/// The folder above [path]; '' above a top-level folder.
String parentSambaPath(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '' : path.substring(0, i);
}

/// The folders first, then the audio files, each sorted by name ignoring
/// case. Other files are left out.
List<SambaEntry> sortSambaEntries(Iterable<SambaEntry> entries) {
  int byName(SambaEntry a, SambaEntry b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  final dirs = entries.where((e) => e.isDirectory).toList()..sort(byName);
  final files =
      entries
          .where(
            (e) =>
                !e.isDirectory &&
                sambaAudioExtensions.contains(extensionOf(e.name)),
          )
          .toList()
        ..sort(byName);
  return [...dirs, ...files];
}

/// `smb2://[domain;]user:password@host/share/path`, percent-encoded.
///
/// The bundled libmpv's libsmb2 decodes the domain, user, password, share
/// and path, so spaces, accents and reserved characters (`#`, `?`, `&`) in
/// folder and file names survive. The host is left verbatim (an IP or a
/// host name); share and path are encoded per segment so the `/`
/// separators stay literal. Needs the libsmb2 path-decode patch of the
/// bundled libmpv: an older libmpv decodes only the password.
String sambaUrl(SambaLogin login, String filePath) {
  String enc(String s) => Uri.encodeComponent(s);
  String encPath(String p) =>
      p.split('/').where((s) => s.isNotEmpty).map(enc).join('/');
  final dom = login.domain.isEmpty ? '' : '${enc(login.domain)};';
  final auth = login.user.isEmpty
      ? ''
      : login.password.isEmpty
      ? '$dom${enc(login.user)}@'
      : '$dom${enc(login.user)}:${enc(login.password)}@';
  return 'smb2://$auth${login.host}/${encPath(login.share)}/'
      '${encPath(filePath)}';
}

/// The audio file [name] in the folder [path] of [login]'s share as a queue
/// entry, its title the file name and its album the folder.
Media sambaMedia(SambaLogin login, String path, String name) => Media(
  sambaUrl(login, joinSambaPath(path, name)),
  extras: {
    'title': withoutExtension(name),
    'album': path.isEmpty ? login.share : path.split('/').last,
  },
);
