import 'package:flutter/material.dart';

/// The four groups Settings is organised in, by purpose.
enum SettingsGroupId {
  listening(
    'Listening',
    Icons.headphones_rounded,
    'Playback, volume, normalization, tracks, visuals and theme',
  ),
  output(
    'Output',
    Icons.speaker_rounded,
    'Device, driver, sample format and buffer',
  ),
  network(
    'Network',
    Icons.cloud_outlined,
    'Cache, streaming, proxy and certificates',
  ),
  advanced(
    'Advanced',
    Icons.build_outlined,
    'Logging, engine options, restart, reset and about',
  );

  const SettingsGroupId(this.title, this.icon, this.summary);

  final String title;
  final IconData icon;

  /// One line naming what the group holds, under its title in the list.
  final String summary;
}

/// One searchable setting: where it lives ([group], [section]), what it is
/// called and what it does, and other words people may search it by. The
/// rows take their title and description from here, so search and page
/// always agree.
@immutable
class SettingEntry {
  const SettingEntry(
    this.id,
    this.group,
    this.section,
    this.title,
    this.description, {
    this.keywords = const [],
  });

  /// Unique, stable: the anchor search jumps to.
  final String id;
  final SettingsGroupId group;

  /// The card the row sits in.
  final String section;
  final String title;
  final String description;
  final List<String> keywords;

  /// How well this entry matches [query], 0 for not at all. Every word of
  /// the query must appear in the title, the description, the keywords,
  /// the section or the group; a match in the title ranks first.
  int score(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return 0;
    final title = this.title.toLowerCase();
    final rest = [
      description,
      section,
      group.title,
      ...keywords,
    ].join(' ').toLowerCase();
    var total = 0;
    for (final w in words) {
      if (title.startsWith(w)) {
        total += 4;
      } else if (title.contains(w)) {
        total += 3;
      } else if (rest.contains(w)) {
        total += 1;
      } else {
        return 0;
      }
    }
    return total;
  }

  @override
  String toString() => 'SettingEntry($id)';
}

/// The settings matching [query], best first, then in page order.
List<SettingEntry> searchSettings(String query) {
  final scored = [
    for (final (i, e) in SettingsCatalog.all.indexed)
      if (e.score(query) case final s when s > 0) (e, s, i),
  ]..sort((a, b) => a.$2 != b.$2 ? b.$2 - a.$2 : a.$3 - b.$3);
  return [for (final (e, _, _) in scored) e];
}

/// The section cards, by title.
abstract final class SettingsSections {
  static const playback = 'Playback';
  static const volume = 'Volume';
  static const resume = 'Resume';
  static const loudness = 'Loudness normalization';
  static const replayGain = 'ReplayGain';
  static const downmix = 'Downmix';
  static const audioTrack = 'Audio track';
  static const visualizer = 'Visualizer';
  static const coverArt = 'Cover art';
  static const session = 'Lock screen and media keys';
  static const appearance = 'Appearance';
  static const device = 'Device';
  static const driver = 'Driver';
  static const passthrough = 'Passthrough and identity';
  static const cache = 'Cache';
  static const demuxer = 'Demuxer';
  static const streaming = 'Streaming';
  static const connection = 'Connection';
  static const logging = 'Logging';
  static const engineOptions = 'Engine options';
  static const player = 'Player';
  static const about = 'About';
}

/// Every searchable setting, in page order.
abstract final class SettingsCatalog {
  static const _l = SettingsGroupId.listening;
  static const _o = SettingsGroupId.output;
  static const _n = SettingsGroupId.network;
  static const _a = SettingsGroupId.advanced;

  // ---- Listening ------------------------------------------------------
  static const speed = SettingEntry(
    'speed',
    _l,
    SettingsSections.playback,
    'Speed',
    'Playback rate without changing pitch',
    keywords: ['rate', 'tempo', 'faster', 'slower'],
  );
  static const pitch = SettingEntry(
    'pitch',
    _l,
    SettingsSections.playback,
    'Pitch',
    'Shift pitch without changing speed',
    keywords: ['key', 'transpose'],
  );
  static const pitchCorrection = SettingEntry(
    'pitchCorrection',
    _l,
    SettingsSections.playback,
    'Pitch correction',
    'Keep pitch constant when changing speed',
    keywords: ['scaletempo', 'chipmunk'],
  );
  static const repeat = SettingEntry(
    'repeat',
    _l,
    SettingsSections.playback,
    'Repeat',
    'Loop the current track or the whole queue',
    keywords: ['loop'],
  );
  static const shuffle = SettingEntry(
    'shuffle',
    _l,
    SettingsSections.playback,
    'Shuffle',
    'Play the queue in random order',
    keywords: ['random'],
  );
  static const gapless = SettingEntry(
    'gapless',
    _l,
    SettingsSections.playback,
    'Gapless',
    'Remove the silence between consecutive tracks',
    keywords: ['gap', 'silence', 'album'],
  );
  static const volumeLimit = SettingEntry(
    'volumeLimit',
    _l,
    SettingsSections.volume,
    'Volume limit',
    'Ceiling for the soft volume control',
    keywords: ['maximum', 'boost', 'loud'],
  );
  static const volumeGain = SettingEntry(
    'volumeGain',
    _l,
    SettingsSections.volume,
    'Volume gain',
    'Decoder-side gain applied before output',
    keywords: ['preamp', 'db', 'louder'],
  );
  static const gainFloor = SettingEntry(
    'gainFloor',
    _l,
    SettingsSections.volume,
    'Lowest gain',
    'Floor for the applied volume gain',
    keywords: ['clamp', 'minimum'],
  );
  static const gainCeiling = SettingEntry(
    'gainCeiling',
    _l,
    SettingsSections.volume,
    'Highest gain',
    'Ceiling for the applied volume gain',
    keywords: ['clamp', 'maximum'],
  );
  static const systemVolume = SettingEntry(
    'systemVolume',
    _l,
    SettingsSections.volume,
    'System volume',
    'The OS mixer level of this app, separate from the player volume',
    keywords: ['mixer', 'ao-volume'],
  );
  static const systemMute = SettingEntry(
    'systemMute',
    _l,
    SettingsSections.volume,
    'System mute',
    'The OS mixer mute of this app',
    keywords: ['mixer', 'silence'],
  );
  static const resume = SettingEntry(
    'resume',
    _l,
    SettingsSections.resume,
    'Resume from last position',
    'Restore position, speed, volume and track on reopen, ideal for '
        'audiobooks and podcasts',
    keywords: ['watch later', 'bookmark', 'audiobook', 'podcast'],
  );
  static const resumeFolder = SettingEntry(
    'resumeFolder',
    _l,
    SettingsSections.resume,
    'Resume folder',
    'Where resume points are stored',
    keywords: ['watch later', 'directory', 'path'],
  );
  static const saveResume = SettingEntry(
    'saveResume',
    _l,
    SettingsSections.resume,
    'Save resume point now',
    'Write the position of the current file',
    keywords: ['watch later', 'bookmark'],
  );
  static const clearResume = SettingEntry(
    'clearResume',
    _l,
    SettingsSections.resume,
    'Clear resume point',
    'Delete the saved position of the current file',
    keywords: ['watch later', 'forget'],
  );
  static const normalize = SettingEntry(
    'normalize',
    _l,
    SettingsSections.loudness,
    'Normalize volume',
    'Measure each track on load and steer it to the target loudness. '
        'Works without ReplayGain tags.',
    keywords: ['ebu', 'r128', 'lufs', 'loudness', 'level'],
  );
  static const normalizeTarget = SettingEntry(
    'normalizeTarget',
    _l,
    SettingsSections.loudness,
    'Target loudness',
    'Integrated loudness target. -18 LUFS is the ReplayGain 2.0 '
        'reference; streaming services sit around -14',
    keywords: ['lufs', 'level'],
  );
  static const replayGainMode = SettingEntry(
    'replayGainMode',
    _l,
    SettingsSections.replayGain,
    'ReplayGain mode',
    'Match loudness per track or per album',
    keywords: ['normalization', 'tags', 'album', 'track'],
  );
  static const replayGainPreamp = SettingEntry(
    'replayGainPreamp',
    _l,
    SettingsSections.replayGain,
    'ReplayGain pre-amp',
    'Extra gain applied on top of ReplayGain',
    keywords: ['preamp', 'db'],
  );
  static const replayGainFallback = SettingEntry(
    'replayGainFallback',
    _l,
    SettingsSections.replayGain,
    'Fallback gain',
    'Gain used when a track has no ReplayGain tags',
    keywords: ['untagged', 'db'],
  );
  static const replayGainClip = SettingEntry(
    'replayGainClip',
    _l,
    SettingsSections.replayGain,
    'Allow clipping',
    'Permit output clipping on loud tracks',
    keywords: ['distortion', 'peak'],
  );
  static const normalizeDownmix = SettingEntry(
    'normalizeDownmix',
    _l,
    SettingsSections.downmix,
    'Normalize downmix',
    'Scale surround down when it is mixed to fewer channels, so 5.1 '
        'played on stereo does not clip',
    keywords: ['surround', '5.1', 'stereo', 'clipping'],
  );
  static const audioTrack = SettingEntry(
    'audioTrack',
    _l,
    SettingsSections.audioTrack,
    'Audio track',
    'Which audio track of the file plays',
    keywords: ['aid', 'language', 'dub', 'stream'],
  );
  static const addExternal = SettingEntry(
    'addExternal',
    _l,
    SettingsSections.audioTrack,
    'Add external audio file',
    'Load a separate dub or commentary as a selectable track',
    keywords: ['dub', 'commentary', 'file'],
  );
  static const rescanExternal = SettingEntry(
    'rescanExternal',
    _l,
    SettingsSections.audioTrack,
    'Rescan external files',
    'Look again for audio files next to the current file',
    keywords: ['refresh', 'dub'],
  );
  static const fftWindow = SettingEntry(
    'fftWindow',
    _l,
    SettingsSections.visualizer,
    'FFT window',
    'Window function applied before the transform',
    keywords: ['spectrum', 'hann', 'blackman'],
  );
  static const fftSize = SettingEntry(
    'fftSize',
    _l,
    SettingsSections.visualizer,
    'FFT size',
    'Samples per frame; higher resolves finer detail',
    keywords: ['spectrum', 'resolution'],
  );
  static const spectrumBands = SettingEntry(
    'spectrumBands',
    _l,
    SettingsSections.visualizer,
    'Spectrum bands',
    'Number of bars drawn in the spectrum',
    keywords: ['bars', 'visualizer'],
  );
  static const coverArt = SettingEntry(
    'coverArt',
    _l,
    SettingsSections.coverArt,
    'Load external art',
    'Look for cover images next to the audio file',
    keywords: ['artwork', 'cover', 'image', 'folder.jpg'],
  );
  static const sessionPublish = SettingEntry(
    'sessionPublish',
    _l,
    SettingsSections.session,
    'Publish to the OS',
    'Lock screen, Control Center, Bluetooth, headset and MPRIS',
    keywords: ['media session', 'notification', 'smtc', 'mpris', 'keys'],
  );
  static const sessionInterruption = SettingEntry(
    'sessionInterruption',
    _l,
    SettingsSections.session,
    'When interrupted',
    'How playback reacts to a call, Siri or an alarm',
    keywords: ['call', 'phone', 'ducking', 'audio focus'],
  );
  static const sessionControls = SettingEntry(
    'sessionControls',
    _l,
    SettingsSections.session,
    'Shown controls',
    'The buttons advertised to the system, in order',
    keywords: ['media session', 'buttons', 'skip', 'like'],
  );
  static const theme = SettingEntry(
    'theme',
    _l,
    SettingsSections.appearance,
    'Theme',
    'Dark, light, or the same as the system',
    keywords: ['dark mode', 'light mode', 'colors', 'appearance'],
  );

  // ---- Output ---------------------------------------------------------
  static const device = SettingEntry(
    'device',
    _o,
    SettingsSections.device,
    'Device',
    'Hardware output the audio is sent to',
    keywords: ['speaker', 'headphones', 'sound card', 'dac'],
  );
  static const exclusive = SettingEntry(
    'exclusive',
    _o,
    SettingsSections.device,
    'Exclusive mode',
    'Take exclusive control of the output device',
    keywords: ['bit perfect', 'wasapi', 'hog'],
  );
  static const sampleFormat = SettingEntry(
    'sampleFormat',
    _o,
    SettingsSections.device,
    'Sample format',
    'Bit depth and number type sent to the device',
    keywords: ['bit depth', '16-bit', '24-bit', 'float'],
  );
  static const channels = SettingEntry(
    'channels',
    _o,
    SettingsSections.device,
    'Channels',
    'Speaker layout requested from the output',
    keywords: ['stereo', 'mono', 'surround', '5.1'],
  );
  static const sampleRate = SettingEntry(
    'sampleRate',
    _o,
    SettingsSections.device,
    'Sample rate',
    'Output sampling frequency',
    keywords: ['khz', '44.1', '48', 'resample'],
  );
  static const outputBuffer = SettingEntry(
    'outputBuffer',
    _o,
    SettingsSections.device,
    'Output buffer',
    'Audio queued at the device; higher hides dropouts',
    keywords: ['latency', 'dropouts', 'stutter'],
  );
  static const audioDelay = SettingEntry(
    'audioDelay',
    _o,
    SettingsSections.device,
    'Audio delay',
    'Shift audio earlier or later to fix sync',
    keywords: ['sync', 'latency', 'offset'],
  );
  static const mediaRole = SettingEntry(
    'mediaRole',
    _o,
    SettingsSections.device,
    'Music media role',
    'Tag the stream as music for the OS audio server',
    keywords: ['pulseaudio', 'pipewire', 'routing'],
  );
  static const driver = SettingEntry(
    'driver',
    _o,
    SettingsSections.driver,
    'Output driver',
    'Backend mpv uses to reach the audio device',
    keywords: ['ao', 'pulse', 'pipewire', 'alsa', 'wasapi', 'coreaudio'],
  );
  static const nullFallback = SettingEntry(
    'nullFallback',
    _o,
    SettingsSections.driver,
    'Fallback to null output',
    'Keep playing silently when no output is available',
    keywords: ['null', 'headless'],
  );
  static const streamSilence = SettingEntry(
    'streamSilence',
    _o,
    SettingsSections.driver,
    'Stream silence',
    'Keep the device open by feeding silence between tracks',
    keywords: ['pop', 'click', 'wake'],
  );
  static const reloadOutput = SettingEntry(
    'reloadOutput',
    _o,
    SettingsSections.driver,
    'Reload audio output',
    'Reopen the output driver and device',
    keywords: ['reset', 'reconnect'],
  );
  static const spdif = SettingEntry(
    'spdif',
    _o,
    SettingsSections.passthrough,
    'S/PDIF passthrough',
    'Send compressed audio untouched to a receiver',
    keywords: ['passthrough', 'ac3', 'dts', 'receiver', 'hdmi'],
  );
  static const clientName = SettingEntry(
    'clientName',
    _o,
    SettingsSections.passthrough,
    'Client name',
    'Name shown for this app in the OS mixer',
    keywords: ['mixer', 'name'],
  );

  // ---- Network --------------------------------------------------------
  static const cacheMode = SettingEntry(
    'cacheMode',
    _n,
    SettingsSections.cache,
    'Cache',
    'Buffer the stream ahead of playback',
    keywords: ['buffer', 'network'],
  );
  static const cacheDuration = SettingEntry(
    'cacheDuration',
    _n,
    SettingsSections.cache,
    'Cache duration',
    'How much audio to keep buffered ahead',
    keywords: ['buffer', 'seconds'],
  );
  static const cacheOnDisk = SettingEntry(
    'cacheOnDisk',
    _n,
    SettingsSections.cache,
    'Cache on disk',
    'Spill the cache to disk instead of memory',
    keywords: ['disk', 'storage'],
  );
  static const pauseOnBuffer = SettingEntry(
    'pauseOnBuffer',
    _n,
    SettingsSections.cache,
    'Pause on buffer',
    'Pause playback while the cache refills',
    keywords: ['stall', 'buffering'],
  );
  static const prebuffer = SettingEntry(
    'prebuffer',
    _n,
    SettingsSections.cache,
    'Pre-buffer on start',
    'Buffer before playback starts, and again after a seek',
    keywords: ['buffering', 'start'],
  );
  static const bufferWait = SettingEntry(
    'bufferWait',
    _n,
    SettingsSections.cache,
    'Buffer wait',
    'How much audio to gather before playing on after a stall',
    keywords: ['stall', 'seconds'],
  );
  static const readaheadMemory = SettingEntry(
    'readaheadMemory',
    _n,
    SettingsSections.demuxer,
    'Read-ahead memory',
    'Memory the demuxer may use to read ahead',
    keywords: ['demuxer', 'cache size', 'mib'],
  );
  static const readaheadTime = SettingEntry(
    'readaheadTime',
    _n,
    SettingsSections.demuxer,
    'Read-ahead time',
    'How far ahead of playback the demuxer reads',
    keywords: ['demuxer', 'seconds'],
  );
  static const seekback = SettingEntry(
    'seekback',
    _n,
    SettingsSections.demuxer,
    'Seekback pool',
    'Recent audio kept so seeking back is instant',
    keywords: ['demuxer', 'rewind'],
  );
  static const diskCacheFolder = SettingEntry(
    'diskCacheFolder',
    _n,
    SettingsSections.demuxer,
    'Disk cache folder',
    'Where the cache goes when it is kept on disk',
    keywords: ['directory', 'path', 'storage'],
  );
  static const prefetch = SettingEntry(
    'prefetch',
    _n,
    SettingsSections.streaming,
    'Prefetch next track',
    'Open the next queue entry ahead of time',
    keywords: ['preload', 'gapless'],
  );
  static const forceSeeking = SettingEntry(
    'forceSeeking',
    _n,
    SettingsSections.streaming,
    'Force seeking',
    'Allow seeking in the cache on streams mpv reports as not seekable '
        '(direct HTTP or HLS audio)',
    keywords: ['seekable', 'scrub', 'hls'],
  );
  static const hlsVariant = SettingEntry(
    'hlsVariant',
    _n,
    SettingsSections.streaming,
    'HLS variant',
    'Which rendition to pick from an adaptive HLS playlist, from the next '
        'stream that opens',
    keywords: ['bitrate', 'quality', 'adaptive', 'm3u8'],
  );
  static const networkTimeout = SettingEntry(
    'networkTimeout',
    _n,
    SettingsSections.connection,
    'Network timeout',
    'Give up on a stalled connection after this',
    keywords: ['seconds', 'stall'],
  );
  static const tlsVerify = SettingEntry(
    'tlsVerify',
    _n,
    SettingsSections.connection,
    'Verify TLS certificates',
    'Reject servers with an untrusted certificate',
    keywords: ['https', 'ssl', 'security', 'certificate'],
  );
  static const tlsCaFile = SettingEntry(
    'tlsCaFile',
    _n,
    SettingsSections.connection,
    'TLS CA file',
    'A certificate bundle to trust, for servers with a private '
        'certificate authority',
    keywords: ['https', 'ssl', 'certificate', 'pem', 'self-signed'],
  );
  static const httpProxy = SettingEntry(
    'httpProxy',
    _n,
    SettingsSections.connection,
    'HTTP proxy',
    'Send stream requests through a proxy, such as http://host:8080',
    keywords: ['proxy', 'vpn', 'firewall'],
  );
  static const cookies = SettingEntry(
    'cookies',
    _n,
    SettingsSections.connection,
    'Cookies',
    'Keep the cookies servers set while a stream plays',
    keywords: ['http', 'session'],
  );
  static const userAgent = SettingEntry(
    'userAgent',
    _n,
    SettingsSections.connection,
    'User agent',
    'The name sent to servers as User-Agent, for every stream without its '
        'own header. Empty keeps the engine default.',
    keywords: ['http', 'header', 'browser'],
  );

  // ---- Advanced -------------------------------------------------------
  static const logLevel = SettingEntry(
    'logLevel',
    _a,
    SettingsSections.logging,
    'Engine log level',
    'How much of the engine log reaches the Console',
    keywords: ['debug', 'verbose', 'console', 'trace'],
  );
  static const rawOptions = SettingEntry(
    'rawOptions',
    _a,
    SettingsSections.engineOptions,
    'Raw engine options',
    'mpv options set on every launch, one name=value per line. '
        'Experimental: a wrong value can stop playback.',
    keywords: ['mpv', 'property', 'experimental', 'conf'],
  );
  static const restartPlayer = SettingEntry(
    'restartPlayer',
    _a,
    SettingsSections.player,
    'Restart player',
    'Start the audio engine again with the current settings, keeping '
        'the queue',
    keywords: ['reload', 'reboot', 'apply'],
  );
  static const welcome = SettingEntry(
    'welcome',
    _a,
    SettingsSections.player,
    'Welcome screen',
    'Show the first launch choices again',
    keywords: ['onboarding', 'intro', 'getting started', 'demo'],
  );
  static const reset = SettingEntry(
    'reset',
    _a,
    SettingsSections.player,
    'Reset all settings',
    'Restore every engine, effect and network setting to its default. '
        'The theme is kept.',
    keywords: ['defaults', 'factory', 'clear'],
  );
  static const about = SettingEntry(
    'about',
    _a,
    SettingsSections.about,
    'Versions',
    'The app, engine and FFmpeg versions',
    keywords: ['about', 'version', 'mpv', 'ffmpeg', 'build'],
  );

  /// Every entry, in page order.
  static const all = <SettingEntry>[
    speed,
    pitch,
    pitchCorrection,
    repeat,
    shuffle,
    gapless,
    volumeLimit,
    volumeGain,
    gainFloor,
    gainCeiling,
    systemVolume,
    systemMute,
    normalize,
    normalizeTarget,
    replayGainMode,
    replayGainPreamp,
    replayGainFallback,
    replayGainClip,
    normalizeDownmix,
    resume,
    resumeFolder,
    saveResume,
    clearResume,
    audioTrack,
    addExternal,
    rescanExternal,
    fftWindow,
    fftSize,
    spectrumBands,
    coverArt,
    theme,
    sessionPublish,
    sessionInterruption,
    sessionControls,
    device,
    exclusive,
    sampleFormat,
    channels,
    sampleRate,
    outputBuffer,
    audioDelay,
    mediaRole,
    driver,
    nullFallback,
    streamSilence,
    reloadOutput,
    spdif,
    clientName,
    networkTimeout,
    tlsVerify,
    tlsCaFile,
    httpProxy,
    cookies,
    userAgent,
    prefetch,
    forceSeeking,
    hlsVariant,
    cacheMode,
    cacheDuration,
    cacheOnDisk,
    pauseOnBuffer,
    prebuffer,
    bufferWait,
    readaheadMemory,
    readaheadTime,
    seekback,
    diskCacheFolder,
    logLevel,
    rawOptions,
    restartPlayer,
    welcome,
    reset,
    about,
  ];
}
