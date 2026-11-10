import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';
import '../setting_anchor.dart';
import '../settings_catalog.dart';
import '../settings_scope.dart';
import '../../../ui/tokens.dart';
import 'anchored_rows.dart';
import 'pickers.dart';

/// How the engine talks to servers: timeout, TLS, proxy, cookies and the
/// user agent. All apply from the next stream that opens.
class ConnectionSection extends StatelessWidget {
  const ConnectionSection({super.key, this.web = kIsWeb});

  /// Whether the app runs in a browser, where TLS, the certificates,
  /// proxies and cookies are the browser's and the engine's settings for
  /// them have no effect.
  final bool web;

  /// mpv's built-in user agent, restored when the field is emptied.
  static const engineUserAgent = 'libmpv';

  /// Whether [url] is empty (no proxy) or an http URL with a host.
  static bool validProxy(String url) {
    if (url.isEmpty) return true;
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'http' && uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    final settings = scope.settings;
    return SettingsGroup(
      label: SettingsSections.connection,
      children: [
        Live<Duration>(
          stream: p.stream.networkTimeout,
          initial: p.state.settings.networkTimeout,
          builder: (context, v) => anchoredSlider(
            scope,
            SettingsCatalog.networkTimeout,
            value: v.inSeconds.toDouble(),
            min: 5,
            max: 120,
            resetTo: 60,
            format: (x) => '${x.round()} s',
            set: (x) => p.setNetworkTimeout(Duration(seconds: x.round())),
          ),
        ),
        if (web)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.s16),
            child: Text(
              'In a browser, TLS, certificates, proxies and cookies are the '
              'browser\'s: the engine\'s settings for them have no effect.',
              style: Tokens.label,
            ),
          )
        else ...[
          Live<bool>(
            stream: p.stream.tlsVerify,
            initial: p.state.settings.tlsVerify,
            builder: (context, v) => anchoredSwitch(
              scope,
              SettingsCatalog.tlsVerify,
              value: v,
              set: p.setTlsVerify,
            ),
          ),
          ListenableBuilder(
            listenable: settings.changes,
            builder: (context, _) => anchoredPath(
              SettingsCatalog.tlsCaFile,
              path: settings.tlsCaFile,
              unset: 'The system certificates are used.',
              pick: pickCertificateFile,
              onChanged: (path) {
                settings.recordTlsCaFile(path);
                scope.run(() => p.setTlsCaFile(path));
              },
            ),
          ),
          Live<String>(
            stream: p.stream.httpProxy,
            initial: p.state.settings.httpProxy,
            builder: (context, v) => SettingAnchor(
              entry: SettingsCatalog.httpProxy,
              child: TextRow(
                label: SettingsCatalog.httpProxy.title,
                description:
                    '${SettingsCatalog.httpProxy.description}. Empty for none; '
                    'press Enter to apply.',
                value: v,
                hint: 'http://host:8080',
                onSubmitted: (url) {
                  final value = url.trim();
                  if (!validProxy(value)) {
                    showSettingsMessage(
                      context,
                      'Enter a proxy as http://host:port, or leave it empty.',
                    );
                    return;
                  }
                  scope.run(() => p.setHttpProxy(value));
                },
              ),
            ),
          ),
          Live<bool>(
            stream: p.stream.cookies,
            initial: p.state.settings.cookies,
            builder: (context, v) => anchoredSwitch(
              scope,
              SettingsCatalog.cookies,
              value: v,
              set: p.setCookies,
            ),
          ),
        ],
        ListenableBuilder(
          listenable: settings.changes,
          builder: (context, _) => SettingAnchor(
            entry: SettingsCatalog.userAgent,
            child: TextRow(
              label: SettingsCatalog.userAgent.title,
              description:
                  '${SettingsCatalog.userAgent.description} '
                  'Press Enter to apply.',
              value: settings.userAgent,
              hint: engineUserAgent,
              onSubmitted: (agent) {
                final value = agent.trim();
                settings.recordUserAgent(value);
                scope.run(
                  () => p.setRawProperty(
                    'user-agent',
                    value.isEmpty ? engineUserAgent : value,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
