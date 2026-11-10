## [0.4.8] - 10-11-2026

### Changed
- Updated `mpv_audio_kit` to version `0.7.0`, with libmpv-r24: the app reads the player's state through its groups, and a track on loop keeps its waveform instead of drawing it again at every pass.

## [0.4.7] - 8-11-2026

### Changed
- Updated `dart_smb2` to version `0.3.0`, with libsmb2-r11: Samba seals SMB 3.1.1 sessions with AES-GCM through OpenSSL's libcrypto, and refuses a libsmb2 of another release.
- Updated `dart_plex` to version `0.3.0` and `dart_jellyfin` to version `0.4.0`.
- Jellyfin search finds artists among the people credited as artist, as Jellyfin 12 lists them.
- When Plex cannot name the file of a track played without transcoding, the track is transcoded to AAC over HLS instead of opening a URL a recent server refuses.
- The license page lists OpenSSL, with its license text.

## [0.4.6] - 8-11-2026

### Changed
- Updated `mpv_audio_kit` to version `0.6.4`, with libmpv-r23: a queue that comes back on launch, or a stream opened at one of its tracks, shows its list at once; a pause in the last moments of a track keeps the rest; on the web, closing a player no longer holds the page.

## [0.4.5] - 7-11-2026

### All platforms
**Added**
- Removing a queue entry, clearing the queue, replacing it and removing or resetting an effect stage show Undo.
- Named effect chains: save, load with Undo, copy and paste as text, delete.
- The queue comes back on launch, paused on the track it was on, when Resume is on.
- The app reopens the section, the sidebar, the Stream tab, the waveform height and the Settings group as you left them.
- Live streams show LIVE instead of a length; Live also brings playback back to the present.
- A live stream that drops says so, with Play again.
- Zoom the waveform with a pinch or with Ctrl and the wheel.
- A narrow waveform keeps a button back to the live end.
- Ctrl+1 to Ctrl+7 open the sections; B toggles the effects bypass; F1 lists every key.
- The Menu key and Shift+F10 open the menu of stream rows and albums.
- Alt and the arrows move the selected queue entry or effect stage; Delete removes the focused stage.
- A Command history button in the Console, also on a phone.
- In the Console Up and Down recall the history and keep the line you were typing; Clear has Undo.
- Enter in Add stage adds the first match; a stage waiting for an option says which.

**Changed**
- Stop stops playback and keeps the queue on the same track.
- Open files on Playback adds to the queue instead of replacing it.
- Page Up and Page Down scroll the page; Shift with them steps through chapters.
- Errors in playback and in the Console say what to do next.
- Settings search opens the first result with Enter, says which word found a result and suggests a close word.
- The Console and Settings share one log level.
- Add to queue and Play next say what they did.
- Escape closes a detail; switching sections puts the focus in the page.
- Restart and Reset all say when they are done.
- The light theme's selection is a step darker, apart from the buttons beside it.
- Cards in sheets, dialogs and the welcome screen show in the light theme.
- One empty state, one loading spinner and one inline notice across the app.
- Missing values read as a dash everywhere.
- Chart labels, scales and gutters follow the text size; the EQ, response, compressor, gauge, scope and Engine charts no longer overlap their labels.
- The waveform draws whole pixel columns, without moire, and labels its ruler about every 120 px.
- Chapter buttons use chevrons, apart from the track's skip buttons.
- On a phone the waveform is taller and the volume fits above the tab bar.
- At a large text size the playback deck scrolls with a fade, and buttons and fields grow with the text.
- In three columns the queue list takes the room past a readable detail card.
- A stage editor stops at 880 px wide.
- Console commands are bold, and wrapped log lines hang under their first line.
- The Engine state pills are lower case, like the mpv values; the prefetch legend shows each colour.
- A dragged row stands out from the rows it passes.

**Fixed**
- Enter and Delete in the queue act on the focused button, not on the selected row.
- An Undo is no longer pushed away by other notices, and stays while a screen reader is on.
- Folders load without freezing the window; empty folders and non audio files say why nothing was added.
- Files can be dropped anywhere on the window.
- Notices no longer cover the sidebar.
- Focus rings on stream rows, albums, pills and sheet rows; the focused control gets a fill where it has no ring.
- Dialog titles are announced; the tab bar says each tab's position.
- The tab bar and the sidebar name keep their labels apart at a large text size.
- Shortcuts work on any device with a keyboard.
- On the web the browser menu no longer opens over the app's menu.
- Jellyfin and Plex search keep their results while loading.
- An expired session keeps the server address.
- The welcome screen no longer closes on a tap outside.
- Settings are saved when the app goes to the background.
- A chapter dot takes a whole tap target on touch, and close dots open their own chapter.
- "channels" no longer touches its value in Engine.
- Reduced motion also stops the Effects reveal and the Lab options panel.
- The short rail keeps the mini player off the window's foot.

## [0.4.4] - 5-11-2026

### Changed
- Updated `mpv_audio_kit` to version `0.6.3`, with libmpv-r22: a pause in the last buffer of a track keeps the rest, and play plays it instead of starting the track again.

## [0.4.3] - 5-11-2026

### All platforms
**Added**
- Wide windows use three columns: Settings shows a group's cards in two columns beside the groups, Effects puts loudness beside the stage editor, Queue adds what plays and what comes next, and the Console lists the commands run beside the log.
- Engine shows its cards in four columns on a wide window.
- A Live chip brings a live waveform back to its newest audio.

**Changed**
- The Lab and Chapters streams stand in two columns when there is room.
- Track info and the stage catalog open wider, with their sections side by side.

**Fixed**
- Menu items light a pill on hover, instead of a square across the menu.
- A live waveform follows its newest audio, where it showed the oldest part of the cache.
- The welcome screen's choices light a rounded row on hover.
- A disabled menu item dims its icon.

## [0.4.2] - 5-11-2026

### All platforms
**Added**
- A Live PCM tab in Stream plays test signals made in Dart through `openPcmStream`: a sine, a sweep, pink noise or pulses.
- A Speed and pitch dialog from the speed menu, with the pitch in semitones.
- The spectrum on Playback names itself, marks 100 Hz, 1 kHz and 10 kHz, and opens its own settings.
- The waveform marks what the cache holds on a network source.
- Each effect slider says whether a change applies live or rebuilds the filter.
- A banner when no audio device opens and the sound plays on the null output, with a button to reopen the output.
- A stream cut by its connection shows as cut short in the queue and in Engine.
- The Lab radios reconnect when their connection drops, and the HTTP options add Reconnect and Fail fast.
- A focus ring shows the control the keyboard is on.

**Changed**
- One scale for spacing, icons, type and motion across the app, and Roboto Mono for figures and the log.
- Frequency, time and ratio sliders use a log scale, as do speed and pitch, and the arrow keys step by round values.
- The desktop mini-player sits under the page, next to the sidebar.
- Stream libraries use the whole width: the album grid fills the page until an album opens.
- Empty and error states share one design, with the technical cause under Details.
- Queue labels its actions when there is room and folds the rest into a menu.
- Engine shows the position in one unit over a bar, and its flags as named states.
- The Stream tabs come in two groups, tools and sources, and the account sits in a button with a menu.
- With reduced motion on in the system, the app does not animate.
- Large text no longer clips the mini-player, the A-B pill, the queue details or the chart labels.

**Fixed**
- The Console error badge is readable and says its count to screen readers.
- With Cover art on, an image in the file's folder shows as the cover.
- Slider tracks, switches that are off and the reference lines of the charts stand out from their background.

### Web
**Added**
- A browser that cannot run the engine says why, instead of offering to try again.
- A note while the browser holds the sound until a click or a key.
- The Lab radios ask for their titles across origins.

**Changed**
- Settings leave out what the browser decides: TLS, certificates, proxies and cookies, the driver, passthrough and folders.

## [0.4.1] - 5-11-2026

### All platforms
**Changed**
- Updated `mpv_audio_kit` to version `0.6.2`.
- The compensationdelay stage changes live.

## [0.4.0] - 2-11-2026

### Added
- The app runs in the browser through `mpv_audio_kit` 0.6.0, with a live demo on GitHub Pages: https://ales-drnz.github.io/mpv_studio/.
- In the browser, picked and dropped files play with their file names as titles, and the OS media controls come from the browser.
- In the browser, an `http://` server or stream says that the HTTPS page cannot open it, instead of failing as a server that cannot be found.
- **Open source licenses**, under About in Settings, lists the license texts of the Dart packages and of the bundled libmpv.
- The license page lists the libsmb2 of `dart_smb2`, with where the source of that build is.
- A LICENSE (BSD 3-Clause) and a License section in the README.

### Changed
- Updated `mpv_audio_kit` to version `0.6.0`, `dart_jellyfin` to `0.3.1`, `dart_plex` to `0.2.1`, `dart_smb2` to `0.2.3` and `go_router` to `18`.
- Jellyfin and Plex use `package:http` instead of Dio.
- The Console describes each mpv command in a line written for the app, instead of one cut from mpv's manual.
- Samba is not available in the browser, which cannot open an SMB connection: its tab says so.
- The rubberband stage is gone from the rack, as libmpv-r20 is LGPL and leaves out Rubber Band. A saved rack loads without it; speed, pitch and the `atempo` and `asetrate` stages remain.

### Fixed
- Plex counts the plays the app reports: each report carries the track's length, and none is sent before it is known.

## [0.3.2] - 22-10-2026

### Changed
- Updated `mpv_audio_kit` to version `0.5.3` and `dart_smb2` to version `0.2.2`.
- Building the app requires Flutter 3.47, which `dart_smb2` 0.2 needs.

### Fixed
- A Samba user with an empty password signs in as that user, not anonymously.

## [0.3.1] - 19-10-2026

### Changed
- Updated `mpv_audio_kit` to version `0.5.2`.
- On Linux the taskbar shows the logo, through a desktop entry and a themed icon.

### Fixed
- The meters no longer throw when a page closes before they ran, and reordering lists works on Flutter 3.38.

## [0.3.0] - 14-10-2026

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
- The YouTube tab is removed. The Resolver tab shows how any resolver plugs into the library.
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
