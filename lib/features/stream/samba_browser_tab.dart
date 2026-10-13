import 'dart:async';
import 'dart:math' as math;

import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../studio/player_scope.dart';
import '../../ui/tokens.dart';

/// The Samba (SMB2/3) tab: a connect form until authenticated, then a
/// **folder browser** — navigate the share's directory tree and tap a track to
/// play it. Unlike the Jellyfin / Plex tabs (flat searchable song lists), an
/// SMB share is a raw filesystem, so this is a path-walking view: directories
/// first, then audio files, with a breadcrumb + up button.
///
/// Playback hands mpv an `smb2://user:pass@host/share/path` URL — the bundled
/// libmpv links libsmb2, so it opens these directly (and the waveform analyzer
/// treats them as ordinary seekable files → full envelope up-front).
class SambaBrowserTab extends StatefulWidget {
  const SambaBrowserTab({super.key});

  @override
  State<SambaBrowserTab> createState() => _SambaBrowserTabState();
}

class _SambaBrowserTabState extends State<SambaBrowserTab> {
  static const _kHost = 'samba.host';
  static const _kShare = 'samba.share';
  static const _kUser = 'samba.user';
  static const _kPass = 'samba.pass';
  static const _kDomain = 'samba.domain';

  static const int _queueMax = 200;

  /// Extensions mpv can decode that we surface as playable tracks.
  static const _audioExts = {
    'flac',
    'mp3',
    'm4a',
    'm4b',
    'aac',
    'ogg',
    'oga',
    'opus',
    'wav',
    'aif',
    'aiff',
    'alac',
    'wma',
    'ape',
    'wv',
    'mka',
    'mp2',
    'caf',
    'dsf',
    'dff',
    'mpc',
  };

  final _host = TextEditingController();
  final _share = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _domain = TextEditingController();

  Player? _player;
  Smb2Pool? _pool;

  StreamSubscription<Playlist>? _plSub;

  /// URI of the currently-playing track, to light up its row in the browser.
  String _currentUri = '';

  // The credentials behind the live [_pool], kept so playback URLs can embed
  // them (mpv opens `smb2://user:pass@host/share/...` itself).
  String _connHost = '';
  String _connShare = '';
  String _connUser = '';
  String _connPass = '';
  String _connDomain = '';

  bool _restoring = true;
  bool _connecting = false;
  bool _loading = false;
  String? _error;

  /// Current directory, relative to the share root ('' = root).
  String _path = '';
  List<Smb2DirEntry> _entries = const [];

  bool get _connected => _pool != null;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_player != null) return;
    _player = PlayerScope.of(context);
    _currentUri = _uriOf(_player!.state.playlist);
    _plSub = _player!.stream.playlist.listen((pl) {
      final u = _uriOf(pl);
      if (mounted && u != _currentUri) setState(() => _currentUri = u);
    });
  }

  static String _uriOf(Playlist pl) {
    if (pl.items.isEmpty || pl.index < 0 || pl.index >= pl.items.length) {
      return '';
    }
    return pl.items[pl.index].uri;
  }

  @override
  void dispose() {
    _plSub?.cancel();
    _host.dispose();
    _share.dispose();
    _user.dispose();
    _pass.dispose();
    _domain.dispose();
    _pool?.disconnect();
    super.dispose();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final host = p.getString(_kHost);
    final share = p.getString(_kShare);
    if (host == null || share == null) {
      if (mounted) setState(() => _restoring = false);
      return;
    }
    _host.text = host;
    _share.text = share;
    _user.text = p.getString(_kUser) ?? '';
    _pass.text = p.getString(_kPass) ?? '';
    _domain.text = p.getString(_kDomain) ?? '';
    await _connect(persist: false);
    if (mounted) setState(() => _restoring = false);
  }

  Future<void> _connect({bool persist = true}) async {
    final host = _host.text.trim();
    final share = _share.text.trim();
    if (host.isEmpty || share.isEmpty) {
      setState(() => _error = 'Host and share are required.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final pool = await Smb2Pool.connect(
        host: host,
        share: share,
        user: _user.text.isEmpty ? null : _user.text,
        password: _pass.text.isEmpty ? null : _pass.text,
        domain: _domain.text.trim().isEmpty ? null : _domain.text.trim(),
      );
      _pool = pool;
      _connHost = host;
      _connShare = share;
      _connUser = _user.text;
      _connPass = _pass.text;
      _connDomain = _domain.text.trim();
      if (persist) {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kHost, host);
        await p.setString(_kShare, share);
        await p.setString(_kUser, _connUser);
        await p.setString(_kPass, _connPass);
        await p.setString(_kDomain, _connDomain);
      }
      if (!mounted) return;
      setState(() => _connecting = false);
      await _open('');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _disconnect() async {
    final pool = _pool;
    _pool = null;
    await pool?.disconnect();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kHost);
    await p.remove(_kShare);
    await p.remove(_kUser);
    await p.remove(_kPass);
    await p.remove(_kDomain);
    if (!mounted) return;
    setState(() {
      _path = '';
      _entries = const [];
      _error = null;
    });
  }

  /// List [path] and show it. Directories sort first, then audio files; both
  /// alphabetical (case-insensitive). Non-audio files are hidden.
  Future<void> _open(String path) async {
    final pool = _pool;
    if (pool == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await pool.listDirectory(path);
      final dirs =
          all
              .where((e) => e.isDirectory && e.name != '.' && e.name != '..')
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      final files =
          all
              .where((e) => e.isFile && _audioExts.contains(_ext(e.name)))
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = [...dirs, ...files];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  static String _ext(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  String _join(String base, String name) => base.isEmpty ? name : '$base/$name';

  void _up() {
    if (_path.isEmpty) return;
    final i = _path.lastIndexOf('/');
    _open(i < 0 ? '' : _path.substring(0, i));
  }

  /// `smb2://[domain;]user:password@host/share/path`, properly percent-encoded.
  ///
  /// The bundled libmpv's libsmb2 decodes the domain / user / share / path (and
  /// password), so this sends a standards-correct URL — spaces, accents and
  /// reserved chars (`#`, `?`, `&`, …) in folder/file names all survive. The
  /// host is left verbatim (it's an IP / hostname). Path and share are encoded
  /// per segment so the `/` separators stay literal.
  ///
  /// NOTE: needs the libsmb2 path-decode patch (libmpv-scripts
  /// patches/ffmpeg/libsmb2.c) — i.e. a libmpv rebuilt after that change. An
  /// older libmpv decodes only the password, so it would see the encoded path
  /// literally; the two must ship together.
  String _smbUrl(String filePath) {
    String enc(String s) => Uri.encodeComponent(s);
    String encPath(String p) =>
        p.split('/').where((s) => s.isNotEmpty).map(enc).join('/');
    final dom = _connDomain.isEmpty ? '' : '${enc(_connDomain)};';
    final auth = _connUser.isEmpty
        ? ''
        : (_connPass.isEmpty
              ? '$dom${enc(_connUser)}@'
              : '$dom${enc(_connUser)}:${enc(_connPass)}@');
    return 'smb2://$auth$_connHost/${encPath(_connShare)}/${encPath(filePath)}';
  }

  /// Queue the current folder's audio files starting at the tapped one (capped
  /// at [_queueMax]) and play.
  Future<void> _play(Smb2DirEntry tapped) async {
    final files = _entries.where((e) => e.isFile).toList();
    final start = files.indexOf(tapped);
    if (start < 0) return;
    final window = files.sublist(
      start,
      math.min(start + _queueMax, files.length),
    );
    final album = _path.isEmpty
        ? _connShare
        : _path.substring(_path.lastIndexOf('/') + 1);
    final medias = [
      for (final f in window)
        Media(
          _smbUrl(_join(_path, f.name)),
          extras: {'title': _stripExt(f.name), 'album': album},
        ),
    ];
    final player = _player;
    if (player == null) return;
    await PlayerScope.issuesOf(
      context,
    ).guard(() => player.openAll(medias, play: true, index: 0));
  }

  static String _stripExt(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) return const _Spinner();
    return _connected ? _browser() : _connectForm();
  }

  // ── Connect form ────────────────────────────────────────────────────

  Widget _connectForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Tokens.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Connect to Samba',
                style: Tokens.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.s4),
              Text(
                'Enter the host, share, and credentials',
                style: Tokens.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.s20),
              _Field(
                controller: _host,
                hint: '192.168.1.10',
                icon: Icons.dns_outlined,
              ),
              const SizedBox(height: Tokens.s8),
              _Field(
                controller: _share,
                hint: 'Share (e.g. Music)',
                icon: Icons.folder_shared_outlined,
              ),
              const SizedBox(height: Tokens.s8),
              _Field(
                controller: _user,
                hint: 'Username',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: Tokens.s8),
              _Field(
                controller: _pass,
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: Tokens.s8),
              _Field(
                controller: _domain,
                hint: 'Domain (optional)',
                icon: Icons.workspaces_outline,
              ),
              if (_error != null) ...[
                const SizedBox(height: Tokens.s12),
                Text(
                  _error!,
                  style: Tokens.caption.copyWith(color: Tokens.red),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: Tokens.s16),
              _ConnectButton(busy: _connecting, onTap: _connect),
            ],
          ),
        ),
      ),
    );
  }

  // ── Folder browser ──────────────────────────────────────────────────

  Widget _browser() {
    return Column(
      children: [
        // Path bar: up button + breadcrumb + disconnect.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.s16,
            Tokens.s8,
            Tokens.s16,
            Tokens.s8,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _path.isEmpty ? null : _up,
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                color: _path.isEmpty ? Tokens.fgFaint : Tokens.fgDim,
                splashRadius: 18,
                tooltip: 'Up',
              ),
              Expanded(
                child: Text(
                  '$_connShare${_path.isEmpty ? '' : '/$_path'}',
                  style: Tokens.body.copyWith(fontFamily: Tokens.mono),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _disconnect,
                icon: const Icon(Icons.logout_rounded, size: 18),
                color: Tokens.fgDim,
                splashRadius: 18,
                tooltip: 'Disconnect',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const _Spinner()
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Tokens.s24),
                    child: Text(
                      _error!,
                      style: Tokens.caption.copyWith(color: Tokens.red),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : _entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(Tokens.s24),
                    child: Text('Empty folder.', style: Tokens.caption),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.s16,
                    Tokens.s8,
                    Tokens.s16,
                    Tokens.s12,
                  ),
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    return _EntryTile(
                      entry: e,
                      current:
                          !e.isDirectory &&
                          _currentUri.isNotEmpty &&
                          _smbUrl(_join(_path, e.name)) == _currentUri,
                      onTap: () => e.isDirectory
                          ? _open(_join(_path, e.name))
                          : _play(e),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A directory or file row in the Queue's squircle-card style: a folder glyph
/// for directories, the file size for audio files. The currently-playing file
/// lights up (accent wash + speaker glyph), like the Jellyfin/Plex rows.
class _EntryTile extends StatelessWidget {
  final Smb2DirEntry entry;
  final bool current;
  final VoidCallback onTap;
  const _EntryTile({
    required this.entry,
    required this.onTap,
    this.current = false,
  });

  static String _size(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var b = bytes.toDouble();
    var u = 0;
    while (b >= 1024 && u < units.length - 1) {
      b /= 1024;
      u++;
    }
    return '${b.toStringAsFixed(b >= 10 || u == 0 ? 0 : 1)} ${units[u]}';
  }

  @override
  Widget build(BuildContext context) {
    final dir = entry.isDirectory;
    // Leading: folder glyph for dirs, a speaker glyph for the playing file, and
    // a music-note glyph for every other (track) file.
    final Widget leading = dir
        ? const Icon(Icons.folder_rounded, size: 18, color: Tokens.accent)
        : current
        ? const Icon(Icons.volume_up_rounded, size: 18, color: Tokens.accent)
        : const Icon(Icons.music_note_rounded, size: 18, color: Tokens.fgFaint);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s6),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.squircle(Tokens.rSm),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(
              Tokens.s12,
              Tokens.s8,
              Tokens.s12,
              Tokens.s8,
            ),
            decoration: ShapeDecoration(
              color: current ? Tokens.accentWash : Tokens.surface,
              shape: Tokens.squircle(Tokens.rSm),
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: Tokens.s12),
                Expanded(
                  child: Text(
                    dir
                        ? entry.name
                        : _SambaBrowserTabState._stripExt(entry.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tokens.body.copyWith(
                      color: current ? Tokens.accent : Tokens.fg,
                      fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: Tokens.s8),
                Text(dir ? '' : _size(entry.size), style: Tokens.numeric),
                if (dir)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Tokens.fgFaint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Form pieces (match the Jellyfin / Plex connect form) ───────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Tokens.controlH,
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.squircle(Tokens.rSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Tokens.fgFaint),
          const SizedBox(width: Tokens.s8),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                fontFamily: Tokens.mono,
                fontSize: 12.5,
                color: Tokens.fg,
              ),
              cursorColor: Tokens.accent,
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: Tokens.caption,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  const _ConnectButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: busy ? null : onTap,
        customBorder: Tokens.squircle(Tokens.rSm),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: busy ? Tokens.surface3 : Tokens.accent,
            shape: Tokens.squircle(Tokens.rSm),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Tokens.fgDim,
                  ),
                )
              : const Text(
                  'Connect',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Tokens.onAccent,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(Tokens.s16),
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Tokens.accentDim,
        ),
      ),
    ),
  );
}
