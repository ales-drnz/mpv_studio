## [0.2.12] - 12-08-2026

### Changed
- Updated `dart_plex`, `dart_jellyfin` and `dart_smb2` to version `0.1.1`.

## [0.2.11] - 3-08-2026

### Changed
- Updated `mpv_audio_kit` to version `0.4.4`.

## [0.2.10] - 3-08-2026

### Changed
- Updated `mpv_audio_kit` to version `0.4.3`.

## [0.2.9] - 30-06-2026

### Changed
- Updated `dart_plex` and `dart_jellyfin` to version `0.1.0`.

## [0.2.8] - 29-06-2026

### Fixed
- On macOS, shutting down or restarting the computer no longer triggers the system warning message.

## [0.2.7] - 18-06-2026

### Changed
- Updated `mpv_audio_kit` to version `0.4.2`.

## [0.2.6] - 17-06-2026

### Changed
- Updated `mpv_audio_kit` to version `0.4.1`.

## [0.2.5] - 16-06-2026

### Added
- Loudness normalization (EBU R128) in the Normalization settings: a "Normalize volume" toggle and a target-LUFS slider that measure each track on load and steer it to the target loudness, works on any track, ReplayGain tags or not.
- A Loudness (EBU R128) section on the Now Playing info sheet: integrated loudness, loudness range, true peak and sample peak.

### Changed
- Updated `mpv_audio_kit` to version `0.4.0`.

### Fixed
- Play and pause state reported to a media server (Jellyfin or Plex) no longer flickers while seeking or buffering.

## [0.2.4] - 9-06-2026

### Changed
- Updated `mpv_audio_kit` to version `0.3.6`.

## [0.2.3] - 9-06-2026

### Added
- A per-category Enable-all toggle, above each category's list (separate from it), that turns every filter in the category on or off at once.
- Text inputs for the string-valued filter parameters.

### Changed
- Reorganized the Effects catalog: the required-param filters (`chorus`, `pan`, `channelmap`, `aeval`, `arnndn`) moved to their own dedicated pages.
- Added new `aintegral` and `asetrate`.
- Updated `mpv_audio_kit` to version `0.3.5` (libmpv-r9).

### Removed
- Dead filter `headphone`.

## [0.2.2] - 8-06-2026

### Changed
- Updated `mpv_audio_kit` to version `0.3.4`.

### Fixed
- The app no longer hangs on quit: the player is now shut down gracefully when the app exits.

## [0.2.1] - 7-06-2026

### Fixed
- Minor UI fixes.

## [0.2.0] - 7-06-2026

### Added
- Resume playback (watch later): a Resume settings category to toggle resume-on-reopen, choose the watch-later directory, and save or clear the current file's resume point.
- Playback volume surface: decoder-gain clamps (min and max) and the OS per-app mixer (system volume and mute), shown as "unavailable" when the audio backend doesn't expose them.
- Streaming settings: force-seekable and HLS variant selection (off, min, max).
- Normalization: loudness-normalize surround content downmixed to fewer channels.
- Demuxer settings: an on-disk cache directory picker and a live network cache-state readout (buffered ranges, raw input rate, EOF and BOF-cached, underrun).
- "Music" media role toggle in Audio output settings (Linux PulseAudio and PipeWire routing).
- 64-bit integer (s64) sample format in the format picker.
- Cache pre-buffer-on-start toggle.
- Queue: load a playlist file or URL (.m3u, .m3u8, .pls, .cue), and a source-playlist banner with cross-playlist navigation.
- Audio track: load or remove an external audio file as a selectable track, plus per-track source, filename, codec-profile details.
- Now Playing: long-press previous or next to force past the queue ends, an undo-last-seek control, and sample-accurate scrubbing on the waveform.

### Changed
- Updated `mpv_audio_kit` to version `0.3.3`.

## [0.1.2] - 5-06-2026

### Changed
- Bumped `mpv_audio_kit` to version `0.3.2`.

## [0.1.1] - 5-06-2026

### Fixed
- Minor fix.

## [0.1.0] - 5-06-2026

### Added
- Initial release of MPV Studio, the standalone reference player built on `mpv_audio_kit`, for macOS, iOS, Android, Windows and Linux.
- Playback with now-playing, real-time visualizers, and a reorderable queue with gapless transitions.
- Jellyfin and Plex streaming.
- A live DSP rack to toggle and tune audio effects, each with its own interactive diagram.
- A built-in mpv command console with autocomplete and the live engine log.
- Settings to configure the player.
