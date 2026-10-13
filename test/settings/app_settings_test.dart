import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/studio/app_settings.dart';
import 'package:mpv_studio/studio/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'studio_fakes.dart';

/// A settings blob as MPV Studio 0.2 wrote it (no schema key).
const _v02 = <String, Object?>{
  'volume': 72.0,
  'volumeMax': 150.0,
  'rate': 1.25,
  'loop': 'playlist',
  'audioDriver': 'auto',
  'audioExclusive': true,
  'hlsBitrate': 'min',
  'resumePlayback': false,
  'watchLaterDir': '/data/later',
  'normalizeDownmix': true,
  'demuxerCacheDir': '/data/cache',
  'forceSeekable': true,
  'tlsVerify': false,
  'networkTimeoutSecs': 30,
  'themeMode': 'light',
  'sessionActions': ['play', 'pause'],
};

Future<Map<String, Object?>> _savedBlob() async {
  final prefs = await SharedPreferences.getInstance();
  return (jsonDecode(prefs.getString(SettingsStore.key)!) as Map)
      .cast<String, Object?>();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('migration', () {
    test('every 0.2 value survives the load', () async {
      final s = await loadSettings(_v02);
      expect(s.volume, 72);
      expect(s.volumeMax, 150);
      expect(s.rate, 1.25);
      expect(s.loop, Loop.playlist);
      expect(s.audioExclusive, isTrue);
      expect(s.hlsBitrate, HlsBitrate.min);
      expect(s.resumePlayback, isFalse);
      expect(s.watchLaterDir, '/data/later');
      expect(s.normalizeDownmix, isTrue);
      expect(s.demuxerCacheDir, '/data/cache');
      expect(s.forceSeekable, isTrue);
      expect(s.tlsVerify, isFalse);
      expect(s.networkTimeoutSecs, 30);
      expect(s.themeMode, ThemeMode.light);
      expect(s.sessionActions, [MediaAction.play, MediaAction.pause]);
    });

    test('0.2 blobs move to schema 2 and an "auto" driver to empty', () {
      final m = migrateSettings(Map.of(_v02));
      expect(m[schemaKey], settingsSchema);
      expect(m['audioDriver'], '');
      expect(m['volume'], 72.0);
    });

    test('the new network values default sensibly', () async {
      final s = await loadSettings(_v02);
      expect(s.tlsCaFile, '');
      expect(s.httpProxy, '');
      expect(s.cookies, isFalse);
      expect(s.userAgent, '');
      expect(s.logLevel, LogLevel.info);
      expect(s.rawOptions, isEmpty);
    });

    test(
      'a 0.2 user skips the first-launch welcome, a new one does not',
      () async {
        expect((await loadSettings(_v02)).onboarded, isTrue);
        expect((await loadSettings()).onboarded, isFalse);
        // A 0.3 blob keeps its own answer.
        expect(
          (await loadSettings({
            schemaKey: settingsSchema,
            'volume': 3.0,
          })).onboarded,
          isFalse,
        );
      },
    );

    test('values of the wrong type fall back to their defaults', () async {
      final s = await loadSettings({
        schemaKey: 'two',
        'volume': '50',
        'audioBufferMs': 'big',
        'mute': 'yes',
        'audioDriver': 3,
        'loop': 7,
        'rawOptions': 'cache=yes',
        'sessionActions': 'play',
        'effects': [1, 2],
        'resumePlayback': 0,
      });
      expect(s.volume, 50);
      expect(s.audioBufferMs, 200);
      expect(s.mute, isFalse);
      expect(s.audioDriver, '');
      expect(s.loop, Loop.off);
      expect(s.rawOptions, isEmpty);
      expect(s.effects, isEmpty);
      expect(s.playerConfiguration.resumePlayback, isTrue);
      final failures = await s.applyTo(StudioFakePlayer());
      expect(failures, isEmpty);
    });

    test('a corrupt blob starts clean', () async {
      SharedPreferences.setMockInitialValues({SettingsStore.key: '{nope'});
      final s = await AppSettings.load();
      expect(s.volume, 50);
    });
  });

  group('persistence', () {
    test('the explicitly recorded values are saved and read back', () async {
      final s = await loadSettings();
      s
        ..recordTlsCaFile('/etc/ca.pem')
        ..recordUserAgent('Studio/1')
        ..recordLogLevel(LogLevel.debug)
        ..recordRawOptions([('demuxer-lavf-probesize', '2048')])
        ..recordOnboarded(true);
      await s.dispose();

      final blob = await _savedBlob();
      expect(blob['tlsCaFile'], '/etc/ca.pem');
      expect(blob[schemaKey], settingsSchema);

      final again = await AppSettings.load();
      expect(again.tlsCaFile, '/etc/ca.pem');
      expect(again.userAgent, 'Studio/1');
      expect(again.logLevel, LogLevel.debug);
      expect(again.rawOptions, [('demuxer-lavf-probesize', '2048')]);
      expect(again.onboarded, isTrue);
    });

    test('attach records what the player streams', () async {
      final s = await loadSettings();
      final p = StudioFakePlayer();
      s.attach(p);
      p.emit((st) => st.copyWith(mute: true));
      await pumpEventQueue();
      expect(s.mute, isTrue);
      await s.dispose();
      expect((await _savedBlob())['mute'], isTrue);
    });

    test('changes notify the listeners', () async {
      final s = await loadSettings();
      var ticks = 0;
      s.changes.addListener(() => ticks++);
      s.recordForceSeekable(true);
      s.recordForceSeekable(true);
      expect(ticks, 1);
      await s.dispose();
    });

    test('reset keeps only the theme and the welcome choice', () async {
      final s = await loadSettings({..._v02, 'onboarded': true});
      await s.resetToDefaults();
      final again = await AppSettings.load();
      expect(again.volume, 50);
      expect(again.resumePlayback, isTrue);
      expect(again.themeMode, ThemeMode.light);
      expect(again.onboarded, isTrue);
    });
  });

  group('applyTo', () {
    test('seeds the network values through their setters', () async {
      final s = await loadSettings({
        'tlsCaFile': '/etc/ca.pem',
        'httpProxy': 'http://proxy:8080',
        'cookies': true,
        'userAgent': 'Studio/1',
        'hlsBitrate': 'min',
        'rawOptions': [
          ['cache-secs', '20'],
        ],
      });
      final p = StudioFakePlayer();
      final failures = await s.applyTo(p);
      expect(failures, isEmpty);
      expect(
        p.calls,
        containsAll([
          'setTlsCaFile /etc/ca.pem',
          'setHttpProxy http://proxy:8080',
          'setCookies true',
          'setRawProperty user-agent Studio/1',
          'setHlsBitrate HlsBitrate.min',
          'setRawProperty cache-secs 20',
        ]),
      );
    });

    test('one refused setter is collected and the rest still apply', () async {
      final s = await loadSettings({'audioDriver': 'pipewire'});
      final p = StudioFakePlayer()
        ..refuse.addAll({'setAudioDriver', 'setCookies'});
      final failures = await s.applyTo(p);
      expect(
        [for (final f in failures) f.setting],
        ['Output driver', 'Cookies'],
      );
      expect(p.calls, contains('setHlsBitrate HlsBitrate.max'));
      expect(p.calls.last, startsWith('setLogLevel'));
      expect(
        describeSettingFailures(failures),
        '2 settings could not be applied: Output driver, Cookies. '
        'The Console has the details.',
      );
    });
  });

  group('restart settings', () {
    test('pending lists what differs from the running player', () async {
      final s = await loadSettings();
      const running = PlayerConfiguration();
      expect(RestartSetting.pending(s, running), isEmpty);
      s
        ..recordForceSeekable(true)
        ..recordWatchLaterDir('/later');
      expect(RestartSetting.pending(s, running), [
        RestartSetting.watchLaterDir,
        RestartSetting.forceSeekable,
      ]);
      expect(
        RestartSetting.pending(s, s.playerConfiguration),
        isEmpty,
        reason: 'a player created with the settings has nothing pending',
      );
      await s.dispose();
    });
  });
}
