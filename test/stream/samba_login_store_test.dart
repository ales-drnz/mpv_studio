import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/samba/samba_login_store.dart';
import 'package:mpv_studio/features/stream/samba/samba_share.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stream_fakes.dart';

const _login = SambaLogin(
  host: 'nas.local',
  share: 'Music',
  user: 'alex',
  password: 'secret',
  domain: 'HOME',
);

Future<Map<String, Object>> _prefs() async {
  final p = await SharedPreferences.getInstance();
  return {for (final k in p.getKeys()) k: p.get(k)!};
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'the password goes to the keychain, the rest to the preferences',
    () async {
      final secrets = FakeSecretStore();
      final store = SambaLoginStore(secrets: secrets);
      await store.save(_login);
      expect(secrets.values, {SambaLoginStore.passwordKey: 'secret'});
      expect(await _prefs(), {
        'samba.host': 'nas.local',
        'samba.share': 'Music',
        'samba.user': 'alex',
        'samba.domain': 'HOME',
      });
      final loaded = (await SambaLoginStore(secrets: secrets).load())!;
      expect(loaded.password, 'secret');
      expect(loaded.domain, 'HOME');
    },
  );

  test(
    'a plain password from an older version moves to the keychain',
    () async {
      SharedPreferences.setMockInitialValues({
        'samba.host': 'nas.local',
        'samba.share': 'Music',
        'samba.pass': 'old-secret',
      });
      final secrets = FakeSecretStore();
      final loaded = (await SambaLoginStore(secrets: secrets).load())!;
      expect(loaded.password, 'old-secret');
      expect(secrets.values[SambaLoginStore.passwordKey], 'old-secret');
      expect((await _prefs()).containsKey('samba.pass'), isFalse);
    },
  );

  test('without a keychain the password stays in memory only', () async {
    SharedPreferences.setMockInitialValues({
      'samba.host': 'nas.local',
      'samba.share': 'Music',
      'samba.pass': 'old-secret',
    });
    final store = SambaLoginStore(secrets: FakeSecretStore(failing: true));
    final loaded = (await store.load())!;
    expect(loaded.password, 'old-secret');
    expect(store.keychainUnavailable.value, isTrue);
    expect((await _prefs()).containsKey('samba.pass'), isFalse);

    await store.save(_login);
    expect((await _prefs()).values, isNot(contains('secret')));
    expect((await store.load())!.password, 'secret');
  });

  test('clearing forgets the password too', () async {
    final secrets = FakeSecretStore();
    final store = SambaLoginStore(secrets: secrets);
    await store.save(_login);
    await store.clear();
    expect(secrets.values, isEmpty);
    expect(await _prefs(), isEmpty);
    expect(await store.load(), isNull);
  });
}
