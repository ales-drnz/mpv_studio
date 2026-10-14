## [0.3.0] - unreleased

### Added
- A new design built on the logo's colours: graphite, ring grey and white, with tonal surfaces, pill controls and round buttons.
- A light theme next to the dark one, plus a System choice. The theme switches live and is saved.
- A layout that adapts to every window: bottom tabs on phones, a navigation rail on tablets and phones in landscape, a sidebar on desktop that collapses to a rail.
- A welcome screen on first launch to open files, play a demo stream or connect a server. Settings can show it again.
- A signal chain rack on the Effects page: stages in play order that you can drag, switch on and off, duplicate, remove and add from the catalog or as raw lavfi.
- Live editing in the rack, with before and after meters on the open stages and a readable message when mpv refuses a chain.
- A global FX bypass to compare the chain on and off. It keeps the loudness meter on and saves your chain, not the muted copy.
- A live loudness gauge and panel with momentary, short-term and integrated loudness, LRA, the track scan and the applied normalization gain.
- An Engine section with playback state, demuxer cache, prefetch, waveform and loudness scan, audio output, effects chain and library builds.
- A mini-player on every section but Playback, with previous, next, swipes on phones and a context menu on desktop.
- A Resolver tab that shows `setSourceResolver` renewing a signed link that expired, with a live log of every call.
- HTTP options for a URL in the Lab tab: user agent, custom headers and chunk size.
- Network settings for a TLS CA file, an HTTP proxy, cookies and a global user agent.
- Settings grouped by purpose (Listening, Output, Network, Advanced) with a search that jumps to the setting.
- A Restart player action for the settings the player only reads at startup. The queue, track and position come back.
- An A-B loop repeat count with the loops left, and chapter titles with previous and next chapter.
- Feedback when next or previous has nowhere to go, at the ends of the queue.
- Album views for Jellyfin and Plex, and states for wrong credentials, an unreachable server, an expired session and an empty library.
- Song and album search on Jellyfin and Plex also finds them by artist and album name.
- Keyboard shortcuts on desktop for playback, volume, chapters, A-B loop and speed, listed with ? or F1.
- The speed keys follow the character typed, so [ and ] work on every keyboard layout, and - and + change the speed too.
- Right-click menus on desktop and long-press sheets on touch for queue rows, stream rows and rack stages.
- The Android back button closes sheets and details first, then returns to Playback.
- Screen reader labels and values on the waveform, meters, curves and queue rows.
- Readable toasts for failed tracks and player calls, and a badge with the count of new mpv errors on the Console entry.
- Queue rows show title, artist, source, length and cover, and mark the tracks that played, were skipped or failed. Wide windows add a details pane.
- A GitHub Actions workflow that analyzes, tests and builds the app without publishing anything.

### Changed
- Updated `mpv_audio_kit` to version `0.5.0`.
- The window title and the launcher read MPV Studio, and the logo is the app icon on every platform.
- The YouTube tab is removed. The Resolver tab shows how any resolver, a YouTube one included, plugs into the library.
- The Samba password is kept in the system keychain. A password saved by an older version moves there on first launch.
- Console commands that change what plays, such as `loadfile` and `pause`, go through the Player API, so the play button stays right.
- The Console reads quotes, escapes and comments like mpv, and expands `${property}` in `print-text` and `show-text`.
- Sliders on effect options that mpv cannot change live apply on release instead of rebuilding the chain while you drag.
- In low windows an open effect fills the page under a compact header, with its first controls on screen.
- The whole effects chain is saved in order, raw stages and duplicates included. Settings from version 0.2 are read and converted.
- The waveform draws its body from the RMS level with a lighter peak outline and starts on the whole track.
- Plex transcoded streams open through the player's source resolver and survive a player restart.
- Building the app requires Flutter 3.38 and Dart 3.10. Linux builds need libsecret.
- On phones the pages scroll behind the mini-player, and the Playback spectrum runs to the edges of the page.
- The output device list shows each device's id under its name, so two devices with the same name can be told apart.

### Fixed
- A server address typed with `https://` got the default port added.
- Signing out of Samba with a dead connection left the login saved.
- The Console, the resolver log and the app log no longer show credentials typed into a URL or server tokens such as `ApiKey` and `X-Plex-Token`.
- A damaged settings value no longer blocks the launch, and a failed launch no longer leaves a player running.
- Player calls that fail, such as a seek with nothing loaded, show a message instead of failing silently.

## [0.2.18] - 24-09-2026

### Changed
- Updated `mpv_audio_kit` to version `0.4.8`.
- Updated `dart_jellyfin` to version `0.2.1`.
- Updated `dart_plex` to version `0.1.3`.

## [0.2.17] - 19-09-2026

### Changed
- Updated `mpv_audio_kit` to version `0.4.6`.
- Updated `dart_smb2` to version `0.1.3`.

## [0.2.16] - 9-09-2026

### Changed
- Updated `dart_plex` to version `0.1.2`.

## [0.2.15] - 9-09-2026

### Changed
- Updated `dart_jellyfin` to version `0.2.0`.

## [0.2.14] - 24-08-2026

### Changed
- Updated `dart_smb2` to version `0.1.2`.

## [0.2.13] - 22-08-2026

### Changed
- Updated `mpv_audio_kit` to version `0.4.5`.

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
