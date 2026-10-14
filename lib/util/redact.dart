/// [text] with the user name and password taken out of every URL in it
/// (`smb2://user:password@host/...` becomes `smb2://host/...`, nested URLs
/// included), so a log line or a label never shows credentials.
String withoutCredentials(String text) => text.replaceAll(_userInfo, '://');

final _userInfo = RegExp(r'://[^/@\s]*@');

/// The query parameters and header fields that carry a secret: the
/// Jellyfin and Emby API key and token, the Plex token, OAuth access
/// tokens, URL signatures and passwords. Matched case-insensitively.
const sensitiveParameters = [
  'ApiKey',
  'api_key',
  'api-key',
  'X-Plex-Token',
  'X-Emby-Token',
  'X-MediaBrowser-Token',
  'token',
  'access_token',
  'sig',
  'signature',
  'password',
];

/// A secret's value in a query (`?ApiKey=abc&...`) or a header field
/// (`X-Emby-Token: abc`, `Token="abc"`), after a separator so a longer
/// name that ends in one of these (`PlaySessionToken`) is left alone.
final _secretValue = RegExp(
  '(^|[?&;,\\s])(${sensitiveParameters.map(RegExp.escape).join('|')})'
  r'''(=|:\s*)("[^"]*"|[^&\s,;"']+)''',
  caseSensitive: false,
);

/// The mask a secret's value is replaced with.
const redactedValue = 'REDACTED';

/// [text] safe to log or show: [withoutCredentials], and every
/// [sensitiveParameters] value masked as [redactedValue]
/// (`...&ApiKey=abc` becomes `...&ApiKey=REDACTED`). The Console, the
/// app's own log lines and the debug output all go through here.
String redactSecrets(String text) => withoutCredentials(
  text,
).replaceAllMapped(_secretValue, (m) => '${m[1]}${m[2]}${m[3]}$redactedValue');
