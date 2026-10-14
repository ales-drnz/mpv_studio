import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' show LogLevel;

import '../../../studio/studio_log.dart';
import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../source_failure.dart';
import '../stream_actions.dart';
import '../widgets/reference_list.dart';
import '../widgets/stream_form.dart';
import '../widgets/stream_row.dart';
import '../widgets/stream_states.dart';
import '../widgets/stream_tab_scope.dart';
import 'samba_login_store.dart';
import 'samba_share.dart';

/// The Samba (SMB2 and SMB3) tab: a sign-in form until connected, then a
/// folder browser over the share. Unlike the Jellyfin and Plex libraries an
/// SMB share is a plain file tree, so this walks folders: folders first,
/// then audio files, with the path and an up button on top. The system back
/// goes up a folder before it leaves the page.
///
/// Playback hands mpv an `smb2://` URL (see [sambaUrl]): the bundled libmpv
/// links libsmb2 and opens it directly.
class SambaTab extends StatefulWidget {
  const SambaTab({
    super.key,
    required this.actions,
    this.connector = connectSmb2,
    this.store,
  });

  final StreamActions actions;

  /// Opens a share; the real one by default, a fake in tests.
  final SambaConnector connector;

  /// Keeps the login across launches; [SambaLoginStore.shared] when null.
  final SambaLoginStore? store;

  @override
  State<SambaTab> createState() => _SambaTabState();
}

class _SambaTabState extends State<SambaTab> {
  /// How many files a tap queues, from the tapped one on.
  static const _queueWindow = 200;

  final _form = GlobalKey<FormState>();
  final _host = TextEditingController();
  final _share = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _domain = TextEditingController();

  SambaShare? _connection;
  SambaLogin? _login;

  SambaLoginStore get _store => widget.store ?? SambaLoginStore.shared;

  bool _restoring = true;
  bool _connecting = false;
  String? _signInError;

  /// The folder shown, relative to the share root ('' for the root).
  String _path = '';
  List<SambaEntry>? _entries;
  Object? _listError;
  bool _listing = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    for (final c in [_host, _share, _user, _pass, _domain]) {
      c.dispose();
    }
    _connection?.disconnect().catchError((Object e) {
      StudioLog.write('Samba: disconnect failed: $e', level: LogLevel.warn);
    });
    super.dispose();
  }

  Future<void> _restore() async {
    SambaLogin? saved;
    try {
      saved = await _store.load();
    } catch (e) {
      StudioLog.write(
        'Samba: saved login unreadable: $e',
        level: LogLevel.warn,
      );
    }
    if (!mounted) return;
    if (saved == null) {
      setState(() => _restoring = false);
      return;
    }
    _host.text = saved.host;
    _share.text = saved.share;
    _user.text = saved.user;
    _pass.text = saved.password;
    _domain.text = saved.domain;
    await _connect(saved, persist: false);
    if (mounted) setState(() => _restoring = false);
  }

  void _submit() {
    if (_connecting || !(_form.currentState?.validate() ?? false)) return;
    _connect(
      SambaLogin(
        host: _host.text.trim(),
        share: _share.text.trim(),
        user: _user.text.trim(),
        password: _pass.text,
        domain: _domain.text.trim(),
      ),
      persist: true,
    );
  }

  Future<void> _connect(SambaLogin login, {required bool persist}) async {
    setState(() {
      _connecting = true;
      _signInError = null;
    });
    try {
      final share = await widget.connector(login);
      if (persist) {
        try {
          await _store.save(login);
        } catch (e) {
          StudioLog.write('Samba: login not saved: $e', level: LogLevel.warn);
        }
      }
      if (!mounted) {
        await share.disconnect();
        return;
      }
      setState(() {
        _connection = share;
        _login = login;
        _connecting = false;
      });
      await _open('');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _signInError = describeFailure(
          classifySambaError(e),
          e,
          signingIn: true,
        );
      });
    }
  }

  Future<void> _disconnect() async {
    final share = _connection;
    setState(() {
      _connection = null;
      _login = null;
      _path = '';
      _entries = null;
      _listError = null;
    });
    // A dead connection (the usual reason to sign in again) may refuse to
    // close; the saved login goes either way.
    try {
      await share?.disconnect();
    } catch (e) {
      StudioLog.write('Samba: disconnect failed: $e', level: LogLevel.warn);
    }
    try {
      await _store.clear();
    } catch (e) {
      StudioLog.write(
        'Samba: saved login not cleared: $e',
        level: LogLevel.warn,
      );
    }
  }

  /// Counts [_open] calls, so only the latest listing is shown.
  int _listRequest = 0;

  /// Lists [path] and shows it, unless another folder was opened (or the
  /// share left) while it loaded.
  Future<void> _open(String path) async {
    final share = _connection;
    if (share == null) return;
    final request = ++_listRequest;
    bool stale() => !mounted || request != _listRequest || share != _connection;
    setState(() {
      _listing = true;
      _listError = null;
    });
    try {
      final entries = sortSambaEntries(await share.list(path));
      if (stale()) return;
      setState(() {
        _path = path;
        _entries = entries;
        _listing = false;
      });
    } catch (e) {
      if (stale()) return;
      setState(() {
        _listing = false;
        _listError = e;
      });
    }
  }

  void _up() {
    if (_path.isNotEmpty) _open(parentSambaPath(_path));
  }

  List<SambaEntry> get _files =>
      (_entries ?? const []).where((e) => !e.isDirectory).toList();

  void _play(SambaEntry tapped) {
    final login = _login;
    if (login == null) return;
    final files = _files;
    final start = files.indexOf(tapped);
    if (start < 0) return;
    final end = math.min(start + _queueWindow, files.length);
    widget.actions.playAll([
      for (final f in files.sublist(start, end))
        sambaMedia(login, _path, f.name),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const StreamLoading(label: 'Reconnecting to the share');
    }
    if (_connection == null) return _signIn();
    return PopScope(
      canPop: _path.isEmpty || !StreamTabScope.isActive(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _up();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pathBar(),
          Expanded(child: _folder()),
        ],
      ),
    );
  }

  Widget _signIn() => ValueListenableBuilder<bool>(
    valueListenable: _store.keychainUnavailable,
    builder: (context, _, _) => SignInCard(
      formKey: _form,
      icon: Icons.folder_shared_rounded,
      title: 'Connect to Samba',
      subtitle:
          'The host, the share and, unless it is open to guests, your '
          'credentials.',
      busy: _connecting,
      error: _signInError,
      onSubmit: _submit,
      fields: [
        StreamTextField(
          controller: _host,
          label: 'Host',
          hint: '192.168.1.10',
          icon: Icons.dns_outlined,
          keyboardType: TextInputType.url,
          validator: requiredField('The host'),
        ),
        StreamTextField(
          controller: _share,
          label: 'Share',
          hint: 'Music',
          icon: Icons.folder_shared_outlined,
          validator: requiredField('The share'),
        ),
        StreamTextField(
          controller: _user,
          label: 'Username (optional)',
          icon: Icons.person_outline_rounded,
          autofillHints: const [AutofillHints.username],
        ),
        StreamTextField(
          controller: _pass,
          label: 'Password (optional)',
          icon: Icons.lock_outline_rounded,
          obscure: true,
        ),
        if (_store.keychainUnavailable.value)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
            child: Text(
              'Password not saved: no system keychain.',
              style: Tokens.label.copyWith(color: Tokens.amber),
            ),
          ),
        StreamTextField(
          controller: _domain,
          label: 'Domain (optional)',
          icon: Icons.workspaces_outline,
          last: true,
          onSubmitted: _submit,
        ),
      ],
    ),
  );

  Widget _pathBar() {
    final share = _login?.share ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.s8, bottom: Tokens.s12),
      child: Row(
        children: [
          RowButton(
            icon: Icons.arrow_upward_rounded,
            tooltip: 'Up one folder',
            onPressed: _path.isEmpty ? null : _up,
          ),
          const SizedBox(width: Tokens.s8),
          Expanded(
            child: Container(
              height: controlHeightOf(context),
              padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
              decoration: ShapeDecoration(
                color: Tokens.surface3,
                shape: Tokens.pill,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 20,
                    color: Tokens.fgDim,
                  ),
                  const SizedBox(width: Tokens.s8),
                  Expanded(
                    child: Text(
                      _path.isEmpty ? share : '$share/$_path',
                      style: Tokens.body.copyWith(fontFamily: Tokens.mono),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Tokens.s8),
          RowButton(
            icon: Icons.logout_rounded,
            tooltip: 'Disconnect from the share',
            onPressed: _disconnect,
          ),
        ],
      ),
    );
  }

  Widget _folder() {
    if (_listing && _entries == null) {
      return const StreamLoading(label: 'Reading the folder');
    }
    final error = _listError;
    if (error != null) {
      final kind = classifySambaError(error);
      return StreamMessage(
        icon: kind == FailureKind.network
            ? Icons.wifi_off_rounded
            : Icons.error_outline_rounded,
        error: true,
        title: 'Could not read this folder',
        message: describeFailure(kind, error),
        actionLabel: kind == FailureKind.auth ? 'Sign in again' : 'Retry',
        onAction: kind == FailureKind.auth ? _disconnect : () => _open(_path),
      );
    }
    final entries = _entries ?? const <SambaEntry>[];
    if (entries.isEmpty) {
      return const StreamMessage(
        icon: Icons.folder_off_outlined,
        title: 'Nothing to play here',
        message: 'This folder has no subfolders and no audio files.',
      );
    }
    final login = _login!;
    return PlaylistBuilder(
      player: widget.actions.player,
      builder: (context, pl) {
        final playing = currentMedia(pl)?.uri ?? '';
        return Stack(
          children: [
            ListView.separated(
              padding: PageEnd.padding(context),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: StreamRow.gap),
              itemBuilder: (context, i) {
                final e = entries[i];
                if (e.isDirectory) {
                  return StreamRow(
                    title: e.name,
                    icon: Icons.folder_rounded,
                    onTap: () => _open(joinSambaPath(_path, e.name)),
                    trailing: [
                      Padding(
                        padding: const EdgeInsets.only(right: Tokens.s8),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 24,
                          color: Tokens.fgDim,
                        ),
                      ),
                    ],
                  );
                }
                final media = sambaMedia(login, _path, e.name);
                return StreamRow(
                  title: withoutExtension(e.name),
                  subtitle: formatFileSize(e.size),
                  icon: Icons.music_note_rounded,
                  current: media.uri == playing,
                  onTap: () => _play(e),
                  menu: () => [for (final a in RowAction.queueActions) a.item],
                  onMenu: (a) => a == RowAction.playNow
                      ? _play(e)
                      : widget.actions.run(a, [media]),
                );
              },
            ),
            if (_listing)
              LinearProgressIndicator(
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
                color: Tokens.accent,
                backgroundColor: Colors.transparent,
              ),
          ],
        );
      },
    );
  }
}

/// [bytes] as a short size, e.g. `4.2 MB`; '' for 0.
String formatFileSize(int bytes) {
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
