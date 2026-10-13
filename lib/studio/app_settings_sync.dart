part of 'app_settings.dart';

/// A persisted setting the player refused on launch, with what it threw.
@immutable
class SettingFailure {
  const SettingFailure(this.setting, this.error);

  /// What the user calls the setting, e.g. "Output driver".
  final String setting;
  final Object error;

  @override
  String toString() => '$setting: $error';
}

/// The notice for the settings the player refused on launch.
String describeSettingFailures(List<SettingFailure> failures) {
  final names = [for (final f in failures) f.setting];
  final list = names.length <= 3
      ? names.join(', ')
      : '${names.take(3).join(', ')} and ${names.length - 3} more';
  return names.length == 1
      ? 'The setting $list could not be applied. The Console has the details.'
      : '${names.length} settings could not be applied: $list. '
            'The Console has the details.';
}

/// The settings the [Player] reads only when it is created: changing one
/// takes a player restart.
enum RestartSetting {
  resumePlayback('Resume from last position'),
  watchLaterDir('Resume folder'),
  normalizeDownmix('Normalize downmix'),
  demuxerCacheDir('Disk cache folder'),
  forceSeekable('Force seeking');

  const RestartSetting(this.label);

  /// The setting's title in Settings.
  final String label;

  /// Whether [settings] holds another value than the [running] player
  /// was created with.
  bool differs(AppSettings settings, PlayerConfiguration running) {
    final wanted = settings.playerConfiguration;
    return switch (this) {
      resumePlayback => wanted.resumePlayback != running.resumePlayback,
      watchLaterDir => wanted.watchLaterDir != running.watchLaterDir,
      normalizeDownmix => wanted.normalizeDownmix != running.normalizeDownmix,
      demuxerCacheDir => wanted.demuxerCacheDir != running.demuxerCacheDir,
      forceSeekable => wanted.forceSeekable != running.forceSeekable,
    };
  }

  /// The settings changed since the [running] player was created.
  static List<RestartSetting> pending(
    AppSettings settings,
    PlayerConfiguration running,
  ) => [
    for (final s in values)
      if (s.differs(settings, running)) s,
  ];
}

/// Seeding the player from the persisted values, and recording what the
/// player changes.
extension AppSettingsSync on AppSettings {
  /// Seeds the live player from the persisted values on launch. Each
  /// setter runs on its own: one the player refuses is collected in the
  /// result and the others still apply, so a stale value never stops the
  /// app from starting. Effects are applied separately by the caller.
  Future<List<SettingFailure>> applyTo(PlayerApi p) async {
    final failures = <SettingFailure>[];
    Future<void> step(String setting, FutureOr<void> Function() call) async {
      try {
        await call();
      } on Object catch (e) {
        failures.add(SettingFailure(setting, e));
      }
    }

    // The ceiling first, so a volume above 100 is accepted.
    await step('Volume limit', () => p.setVolumeMax(volumeMax));
    await step('Volume', () => p.setVolume(volume));
    await step('Mute', () => p.setMute(mute));
    await step('Speed', () => p.setRate(rate));
    await step('Pitch', () => p.setPitch(pitch));
    await step('Gain clamp', () async {
      await p.setVolumeGainMin(volumeGainMin);
      await p.setVolumeGainMax(volumeGainMax);
    });
    await step('Volume gain', () => p.setVolumeGain(volumeGain));
    await step('Pitch correction', () => p.setPitchCorrection(pitchCorrection));
    await step('Repeat', () => p.setLoop(loop));
    await step('Shuffle', () => p.setShuffle(shuffle));
    await step('Gapless', () => p.setGapless(gapless));
    await step('Prefetch', () => p.setPrefetchPlaylist(prefetchPlaylist));
    await step('ReplayGain', () => p.setReplayGain(replayGainSettings));
    // Only force a specific driver; empty means let mpv probe.
    if (audioDriver.isNotEmpty) {
      await step('Output driver', () => p.setAudioDriver(audioDriver));
    }
    await step('Exclusive mode', () => p.setAudioExclusive(audioExclusive));
    await step('Sample format', () => p.setAudioFormat(audioFormat));
    await step(
      'Channels',
      () => p.setAudioChannels(Channels.fromMpv(audioChannels)),
    );
    if (audioSampleRate > 0) {
      await step('Sample rate', () => p.setAudioSampleRate(audioSampleRate));
    }
    await step(
      'Output buffer',
      () => p.setAudioBuffer(Duration(milliseconds: audioBufferMs)),
    );
    await step(
      'Audio delay',
      () => p.setAudioDelay(Duration(microseconds: audioDelayUs)),
    );
    await step('Music media role', () => p.setAudioMediaRole(audioMediaRole));
    await step(
      'Null output fallback',
      () => p.setAudioNullUntimed(audioNullUntimed),
    );
    await step(
      'Stream silence',
      () => p.setAudioStreamSilence(audioStreamSilence),
    );
    if (audioClientName.isNotEmpty) {
      await step('Client name', () => p.setAudioClientName(audioClientName));
    }
    final spdif = audioSpdif;
    if (spdif.isNotEmpty) {
      await step(
        'S/PDIF passthrough',
        () => p.setAudioSpdif({for (final name in spdif) ?Spdif.fromMpv(name)}),
      );
    }
    await step('Cache', () => p.setCache(cacheSettings));
    final demuxer = demuxerSettings;
    if (demuxer != null) {
      await step('Demuxer', () => p.setDemuxer(demuxer));
    }
    await step(
      'Network timeout',
      () => p.setNetworkTimeout(Duration(seconds: networkTimeoutSecs)),
    );
    await step('Verify TLS certificates', () => p.setTlsVerify(tlsVerify));
    if (tlsCaFile.isNotEmpty) {
      await step('TLS CA file', () => p.setTlsCaFile(tlsCaFile));
    }
    if (httpProxy.isNotEmpty) {
      await step('HTTP proxy', () => p.setHttpProxy(httpProxy));
    }
    await step('Cookies', () => p.setCookies(cookies));
    await step('HLS variant', () => p.setHlsBitrate(hlsBitrate));
    if (userAgent.isNotEmpty) {
      await step('User agent', () => p.setRawProperty('user-agent', userAgent));
    }
    await step('Cover art', () => p.setCoverArtAuto(coverArtAuto));
    await step('Visualizer', () => p.setSpectrum(spectrumSettings));
    await step('Log level', () => p.setLogLevel(logLevel));
    for (final (name, value) in rawOptions) {
      await step('Engine option $name', () => p.setRawProperty(name, value));
    }
    return failures;
  }

  /// Subscribes to the player's streams and snapshots every relevant
  /// value as it changes. Call once, after [applyTo].
  void attach(PlayerApi p) {
    final s = p.stream;
    _subs.addAll([
      s.volume.listen((v) => _snap('volume', v)),
      s.volumeMax.listen((v) => _snap('volumeMax', v)),
      s.mute.listen((v) => _snap('mute', v)),
      s.rate.listen((v) => _snap('rate', v)),
      s.pitch.listen((v) => _snap('pitch', v)),
      // Skip persisting volume-gain while loudness normalization owns the
      // stage: the LoudnessNormalizer drives `volume-gain` per track, so
      // persisting it here would overwrite the user's MANUAL gain slider and
      // re-seed a stale normalizer value on the next launch (before the scan
      // re-runs). When normalization is off, the slider owns the value again.
      s.volumeGain.listen((v) {
        if (!loudnessNormalization) _snap('volumeGain', v);
      }),
      s.volumeGainMin.listen((v) => _snap('volumeGainMin', v)),
      s.volumeGainMax.listen((v) => _snap('volumeGainMax', v)),
      s.pitchCorrection.listen((v) => _snap('pitchCorrection', v)),
      s.loop.listen((v) => _snap('loop', v.name)),
      s.shuffle.listen((v) => _snap('shuffle', v)),
      s.gapless.listen((v) => _snap('gapless', v.name)),
      s.prefetchPlaylist.listen((v) => _snap('prefetchPlaylist', v)),
      s.replayGain.listen(
        (v) => _store.writeAll({
          'rgMode': v.mode.name,
          'rgPreamp': v.preamp,
          'rgClip': v.clip,
          'rgFallback': v.fallback,
        }),
      ),
      s.audioDriver.listen((v) => _snap('audioDriver', v)),
      s.audioExclusive.listen((v) => _snap('audioExclusive', v)),
      s.audioFormat.listen((v) => _snap('audioFormat', v.name)),
      s.audioChannels.listen((v) => _snap('audioChannels', v.mpvValue)),
      s.audioSampleRate.listen((v) => _snap('audioSampleRate', v)),
      s.audioBuffer.listen((v) => _snap('audioBufferMs', v.inMilliseconds)),
      s.audioDelay.listen((v) => _snap('audioDelayUs', v.inMicroseconds)),
      s.audioMediaRole.listen((v) => _snap('audioMediaRole', v)),
      s.audioNullUntimed.listen((v) => _snap('audioNullUntimed', v)),
      s.audioStreamSilence.listen((v) => _snap('audioStreamSilence', v)),
      s.audioClientName.listen((v) => _snap('audioClientName', v)),
      s.audioSpdif.listen(
        (v) => _snap('audioSpdif', [for (final c in v) c.mpvValue]),
      ),
      s.cache.listen(
        (v) => _store.writeAll({
          'cacheMode': v.mode.name,
          'cacheSecs': v.secs.inSeconds,
          'cacheOnDisk': v.onDisk,
          'cachePause': v.pause,
          'cachePauseWaitMs': v.pauseWait.inMilliseconds,
          'cachePauseInitial': v.pauseInitial,
        }),
      ),
      s.demuxer.listen(
        (v) => _store.writeAll({
          'demuxerMaxBytes': v.maxBytes,
          'demuxerMaxBackBytes': v.maxBackBytes,
          'demuxerReadaheadMs': v.readahead.inMilliseconds,
        }),
      ),
      s.networkTimeout.listen((v) => _snap('networkTimeoutSecs', v.inSeconds)),
      s.tlsVerify.listen((v) => _snap('tlsVerify', v)),
      s.httpProxy.listen((v) => _snap('httpProxy', v)),
      s.cookies.listen((v) => _snap('cookies', v)),
      s.hlsBitrate.listen((v) => _snap('hlsBitrate', v.name)),
      s.coverArtAuto.listen((v) => _snap('coverArtAuto', v.name)),
      s.spectrum.listen(
        (v) => _store.writeAll({
          'specWindow': v.window.name,
          'specFft': v.fftSize,
          'specBands': v.bandCount,
        }),
      ),
      s.audioEffects.listen((v) {
        if (!holdEffects) recordEffects(v);
      }),
    ]);
  }
}
