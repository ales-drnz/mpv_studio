import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' show LogLevel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../studio/studio_log.dart';

/// How this install introduces itself to Jellyfin and Plex: the app name,
/// version, a readable device name for their "Now Playing", and a stable
/// per-install id.
abstract final class DeviceIdentity {
  /// The client name both servers show.
  static const product = 'MPV Studio';

  /// The client version both servers show.
  static const version = '0.3.0';

  static const _kDeviceIdPref = 'media.deviceId';

  /// Human-readable device name shown in the servers' "Now Playing" (for
  /// example "Living-room Mac"). The app name until [resolve] runs.
  static String get deviceName => _deviceName;
  static String _deviceName = product;

  /// Stable, per-install unique device identifier. Jellyfin binds each
  /// access token to the DeviceId and treats a device as a single session,
  /// so an id shared across installs makes the server invalidate the
  /// restored token ("session expired" on nearly every launch). Plex's
  /// clientIdentifier reuses it: one stable, unique id per install.
  static String get deviceId => _deviceId;
  static String _deviceId = 'mpv-studio';

  /// Resolves the device name and loads (or creates and stores) the device
  /// id. Call once at startup, before the servers build their credentials.
  static Future<void> resolve() async {
    await Future.wait([_resolveName(), _resolveId()]);
  }

  static Future<void> _resolveId() async {
    try {
      final p = await SharedPreferences.getInstance();
      var id = p.getString(_kDeviceIdPref);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await p.setString(_kDeviceIdPref, id);
      }
      _deviceId = id;
    } catch (e) {
      StudioLog.write(
        'DeviceIdentity: device id unavailable: $e',
        level: LogLevel.warn,
      );
    }
  }

  static Future<void> _resolveName() async {
    final name = sanitizeDeviceName(await _platformName());
    if (name.isNotEmpty) _deviceName = name;
  }

  /// The machine name on desktop, the device name on mobile; empty when
  /// the platform does not tell.
  static Future<String> _platformName() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) return '';
      if (Platform.isMacOS) return (await info.macOsInfo).computerName;
      if (Platform.isIOS) return (await info.iosInfo).name;
      if (Platform.isWindows) return (await info.windowsInfo).computerName;
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}';
      }
      if (Platform.isLinux) return (await info.linuxInfo).name;
    } catch (e) {
      StudioLog.write(
        'DeviceIdentity: device name unavailable: $e',
        level: LogLevel.warn,
      );
    }
    return '';
  }
}

/// [name] made safe for the X-Plex-* and Jellyfin auth headers: smart quotes
/// become plain ones, double quotes go, and only printable ASCII is kept.
@visibleForTesting
String sanitizeDeviceName(String name) => name
    .replaceAll('’', "'")
    .replaceAll('‘', "'")
    .replaceAll('"', '')
    .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
    .trim();
