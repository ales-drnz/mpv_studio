import 'dart:async';
import 'dart:io';

import 'media_server.dart' show NotConnectedException;

/// Why talking to a library source (Jellyfin, Plex, Samba) failed, as far as
/// the user can act on it.
enum FailureKind {
  /// Wrong or expired credentials: sign in again.
  auth,

  /// The source could not be reached: check the address or the network,
  /// then retry.
  network,

  /// Anything else.
  other,
}

/// The [FailureKind] of the errors every source can throw: socket and
/// timeout errors are network failures. Each source adds its own client's
/// exception types on top.
FailureKind? commonFailureKind(Object error) => switch (error) {
  NotConnectedException() => FailureKind.auth,
  SocketException() ||
  TimeoutException() ||
  HttpException() => FailureKind.network,
  _ => null,
};

/// The sentence to show for a failure of [kind]. [signingIn] words an
/// auth failure as a refused sign-in rather than an expired session.
String describeFailure(
  FailureKind kind,
  Object error, {
  bool signingIn = false,
}) => switch (kind) {
  FailureKind.auth =>
    signingIn
        ? 'The server refused the username or password.'
        : 'The session expired. Sign in again.',
  FailureKind.network =>
    'Could not reach the server. Check the address and the network.',
  FailureKind.other => 'Something went wrong: ${_detail(error)}',
};

String _detail(Object error) {
  final text = switch (error) {
    StateError(:final message) => message,
    _ => error.toString(),
  };
  final t = text.trim();
  if (t.isEmpty) return 'unknown error.';
  return RegExp(r'[.!?]$').hasMatch(t) ? t : '$t.';
}
