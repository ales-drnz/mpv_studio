import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/studio/fx_bypass.dart';

import 'support/fake_player.dart';

void main() {
  const chain = <AudioEffect>[
    BassEffect(gain: 6),
    TrebleEffect(enabled: false),
    RawAudioEffect('lavfi-aeval=val(0)*0.5|val(1)*0.5'),
  ];

  late FakePlayer player;
  late List<(bool, List<AudioEffect>?)> holds;
  late FxBypass bypass;

  setUp(() {
    player = FakePlayer(const PlayerState(audioEffects: chain));
    holds = [];
    bypass = FxBypass(player, onHold: (h, c) => holds.add((h, c)));
  });

  tearDown(() => bypass.dispose());

  test('engage plays every stage switched off, release restores', () async {
    await bypass.engage();
    expect(bypass.active, isTrue);
    expect(bypass.savedChain, chain);
    final live = player.state.audioEffects;
    expect(live, hasLength(chain.length));
    expect(live.every((e) => !e.enabled), isTrue);
    expect((live.first as BassEffect).gain, 6, reason: 'settings are kept');
    expect(holds.single.$1, isTrue);

    await bypass.release();
    expect(bypass.active, isFalse);
    expect(player.state.audioEffects, chain);
    expect(holds.last.$1, isFalse);
    expect(holds.last.$2, chain);
  });

  test('toggle flips the bypass', () async {
    await bypass.toggle();
    expect(bypass.active, isTrue);
    await bypass.toggle();
    expect(bypass.active, isFalse);
    expect(player.state.audioEffects, chain);
  });

  test('a chain written by someone else ends the bypass and stays', () async {
    await bypass.engage();
    await Future<void>.delayed(Duration.zero);
    const edited = <AudioEffect>[BassEffect(gain: 3)];
    await player.setAudioEffects(edited);
    await Future<void>.delayed(Duration.zero);
    expect(bypass.active, isFalse);
    expect(player.state.audioEffects, edited);
    expect(holds.last.$1, isFalse);
    expect(holds.last.$2, edited);
  });

  test('hasActiveStages', () {
    expect(FxBypass.hasActiveStages(chain), isTrue);
    expect(
      FxBypass.hasActiveStages(const [TrebleEffect(enabled: false)]),
      isFalse,
    );
    expect(FxBypass.hasActiveStages(const []), isFalse);
  });
}
