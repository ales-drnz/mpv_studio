import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' show LogLevel;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../studio/studio_log.dart';
import 'samba_share.dart';

/// Key and value secrets, kept by the system: the small surface of the
/// keychain the app uses, so tests can stand in for it.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The system keychain through `flutter_secure_storage`: the Keychain on
/// iOS and macOS, the Android Keystore, the Windows credential store and
/// the Secret Service (libsecret) on Linux.
class KeychainSecretStore implements SecretStore {
  KeychainSecretStore()
    : _storage = FlutterSecureStorage(
        // The legacy macOS keychain needs no keychain-access-groups
        // entitlement, so the existing signing setup keeps working.
        mOptions: Platform.isMacOS
            ? const MacOsOptions(usesDataProtectionKeychain: false)
            : MacOsOptions.defaultOptions,
      );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Saves the Samba login across launches: the host, share, user and domain
/// in the preferences, the password in the system keychain only.
///
/// When the keychain fails (Linux without a running secret service, for
/// one) the password is kept in memory for this session and never written
/// in plain text; [keychainUnavailable] then turns on, for the sign-in form
/// to say so.
class SambaLoginStore {
  SambaLoginStore({SecretStore? secrets})
    : _secrets = secrets ?? KeychainSecretStore();

  /// The store the app uses.
  static final shared = SambaLoginStore();

  final SecretStore _secrets;

  /// The password when the keychain could not keep it, for this session.
  String? _sessionPassword;

  /// Whether the last keychain access failed.
  final keychainUnavailable = ValueNotifier<bool>(false);

  static const _kHost = 'samba.host';
  static const _kShare = 'samba.share';
  static const _kUser = 'samba.user';
  static const _kDomain = 'samba.domain';

  /// Where versions before 0.3.0 kept the password, in plain text.
  static const _kOldPass = 'samba.pass';

  /// The keychain entry of the password.
  static const passwordKey = 'samba.password';

  /// The saved login, or null when there is none. A password still in the
  /// old plain preference moves to the keychain (or to memory, when the
  /// keychain fails) and leaves the preferences either way.
  Future<SambaLogin?> load() async {
    final p = await SharedPreferences.getInstance();
    final host = p.getString(_kHost);
    final share = p.getString(_kShare);
    final old = p.getString(_kOldPass);
    if (old != null) {
      if (old.isNotEmpty) await _keep(old);
      await p.remove(_kOldPass);
    }
    if (host == null || share == null) return null;
    return SambaLogin(
      host: host,
      share: share,
      user: p.getString(_kUser) ?? '',
      password: await _password(),
      domain: p.getString(_kDomain) ?? '',
    );
  }

  /// Saves [login], so the tab reconnects on the next launch.
  Future<void> save(SambaLogin login) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHost, login.host);
    await p.setString(_kShare, login.share);
    await p.setString(_kUser, login.user);
    await p.setString(_kDomain, login.domain);
    if (login.password.isEmpty) {
      _sessionPassword = null;
      await _delete();
    } else {
      await _keep(login.password);
    }
  }

  /// Forgets the saved login, the password included.
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [_kHost, _kShare, _kUser, _kDomain, _kOldPass]) {
      await p.remove(k);
    }
    _sessionPassword = null;
    await _delete();
  }

  Future<void> _keep(String password) async {
    try {
      await _secrets.write(passwordKey, password);
      _sessionPassword = null;
      keychainUnavailable.value = false;
    } catch (e) {
      _sessionPassword = password;
      _failed('saved for this session only', e);
    }
  }

  Future<String> _password() async {
    try {
      final stored = await _secrets.read(passwordKey);
      return stored ?? _sessionPassword ?? '';
    } catch (e) {
      _failed('not read', e);
      return _sessionPassword ?? '';
    }
  }

  Future<void> _delete() async {
    try {
      await _secrets.delete(passwordKey);
    } catch (e) {
      _failed('not deleted', e);
    }
  }

  void _failed(String what, Object error) {
    keychainUnavailable.value = true;
    StudioLog.write(
      'Samba: password $what, the system keychain failed: $error',
      level: LogLevel.warn,
    );
  }
}
