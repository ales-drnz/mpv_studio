import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' show LogLevel;

import '../../../studio/studio_log.dart';
import '../../../util/mixed_content.dart';
import '../favorites_controller.dart';
import '../media_server.dart';
import '../stream_actions.dart';
import '../widgets/stream_form.dart';
import 'library_browser.dart';

/// One media server tab (Jellyfin or Plex): the sign-in form until a
/// session exists, then the [LibraryBrowser]. The app restores a saved
/// session at launch, so a signed-in server opens straight on its library;
/// a session that turns out expired, or a sign out, comes back here.
class ServerLibraryTab extends StatefulWidget {
  const ServerLibraryTab({
    super.key,
    required this.server,
    required this.actions,
    required this.favorites,
  });

  final MediaServer server;
  final StreamActions actions;
  final FavoritesController favorites;

  @override
  State<ServerLibraryTab> createState() => _ServerLibraryTabState();
}

class _ServerLibraryTabState extends State<ServerLibraryTab> {
  final _form = GlobalKey<FormState>();
  final _host = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();

  late bool _connected = widget.server.isConnected;
  bool _connecting = false;
  String? _error;

  MediaServer get _server => widget.server;

  @override
  void dispose() {
    _host.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_connecting || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _server.connect(
        host: _host.text,
        username: _user.text.trim(),
        password: _pass.text,
      );
      if (!mounted) return;
      _pass.clear();
      setState(() {
        _connecting = false;
        _connected = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = describeFailure(_server.classify(e), e, signingIn: true);
      });
    }
  }

  Future<void> _leave({String? note}) async {
    try {
      await _server.logout();
    } catch (e) {
      StudioLog.write(
        '${_server.name}: sign out failed: $e',
        level: LogLevel.warn,
      );
    }
    if (!mounted) return;
    setState(() {
      _connected = false;
      _error = note;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_connected) {
      return LibraryBrowser(
        server: _server,
        actions: widget.actions,
        favorites: widget.favorites,
        onSignOut: _leave,
        onSessionExpired: () =>
            _leave(note: 'The session expired. Sign in again.'),
      );
    }
    final plex = _server.kind == ServerKind.plex;
    return ServerSignInForm(
      formKey: _form,
      icon: plex ? Icons.library_music_rounded : Icons.dns_rounded,
      title: 'Connect to ${_server.name}',
      subtitle: plex
          ? 'Your Plex account signs in through plex.tv; the server plays '
                'from your network.'
          : 'Sign in with your Jellyfin user.',
      hostHint: _server.hostHint,
      userLabel: plex ? 'Plex account email or username' : 'Username',
      host: _host,
      user: _user,
      pass: _pass,
      busy: _connecting,
      error: _error,
      onSubmit: _connect,
    );
  }
}

/// The sign-in form of a media server: address, user and password.
class ServerSignInForm extends StatelessWidget {
  const ServerSignInForm({
    super.key,
    required this.formKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.hostHint,
    required this.userLabel,
    required this.host,
    required this.user,
    required this.pass,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;

  /// The server's glyph.
  final IconData icon;
  final String title;
  final String subtitle;
  final String hostHint;
  final String userLabel;
  final TextEditingController host;
  final TextEditingController user;
  final TextEditingController pass;
  final bool busy;
  final String? error;
  final VoidCallback onSubmit;

  static String? _validHost(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'The server address is required.';
    try {
      final uri = Uri.parse(normalizeServerBase(v, 1));
      if (isBlockedMixedContent(uri)) return mixedContentMessage;
      if (uri.host.isNotEmpty) return null;
    } on FormatException {
      // Falls through to the message below.
    }
    return 'This is not a valid address.';
  }

  @override
  Widget build(BuildContext context) {
    return SignInCard(
      formKey: formKey,
      icon: icon,
      title: title,
      subtitle: subtitle,
      busy: busy,
      error: error,
      onSubmit: onSubmit,
      fields: [
        StreamTextField(
          controller: host,
          label: 'Server address',
          hint: hostHint,
          icon: Icons.dns_outlined,
          keyboardType: TextInputType.url,
          autofillHints: const [AutofillHints.url],
          validator: _validHost,
        ),
        StreamTextField(
          controller: user,
          label: userLabel,
          icon: Icons.person_outline_rounded,
          autofillHints: const [AutofillHints.username],
          validator: requiredField('The username'),
        ),
        StreamTextField(
          controller: pass,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: true,
          last: true,
          onSubmitted: onSubmit,
        ),
      ],
    );
  }
}
