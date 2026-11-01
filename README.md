# MPV Studio

#### Cross-platform audio player built on mpv_audio_kit.

[![](https://img.shields.io/badge/built%20with-mpv__audio__kit-orange.svg?style=for-the-badge)](https://pub.dev/packages/mpv_audio_kit)
[![](https://img.shields.io/badge/Flutter-3.47+-blue.svg?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![](https://img.shields.io/github/stars/ales-drnz/mpv_studio?style=for-the-badge&logo=github&logoColor=white)](https://github.com/ales-drnz/mpv_studio)
[![](https://img.shields.io/discord/1485588004029333516?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/g2Qf4Mq9MP)
[![](https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white)](https://www.patreon.com/cw/ales_drnz)
[![](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/ales.drnz)

<table>
<tr>
<td valign="middle" width="90"><img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/assets/mpv_studio.png" width="70" alt="logo"></td>
<td valign="middle"><b>MPV Studio</b> is the reference app for the <a href="https://pub.dev/packages/mpv_audio_kit"><code>mpv_audio_kit</code></a> engine: an audio player with an effects rack, live visualizers, Jellyfin, Plex and Samba streaming, an engine inspector and an mpv console. It fits any window, from a phone to an ultrawide desktop, in dark or light.</td>
</tr>
</table>

**[Try it in your browser](https://ales-drnz.github.io/mpv_studio/)**: the full app, with libmpv running as WebAssembly. Best in Chrome or Edge.

---

## Platforms

| Platform  | Minimum | Architectures |
| :--- | :--- | :--- |
| **Android** | 7.0 (SDK 24) | arm64-v8a, armeabi-v7a, x86_64 |
| **iOS** | 15.6 | arm64, x86_64 |
| **macOS** | 12.0 | arm64, x86_64 |
| **Windows**| 10 | arm64, x86_64 |
| **Linux** | glibc 2.31 (Ubuntu 20.04, Debian 11) | aarch64, x86_64 |
| **Web** | Chrome or Edge 137 (WebAssembly) | wasm32 |

In the browser a few things are not available:

- **Samba**: a web page cannot open an SMB connection.
- **`http://` addresses**: the HTTPS page blocks them as mixed content (only the machine itself is allowed: `localhost`, `127.0.0.1`, `::1`). Use the server's `https://` address.
- **Add folder**: pick or drop the files instead.

---

## Contents

- [Guide](#guide)
  - [1. Playback](#1-playback)
  - [2. Queue](#2-queue)
  - [3. Stream](#3-stream)
  - [4. Effects](#4-effects)
  - [5. Engine](#5-engine)
  - [6. Settings](#6-settings)
  - [7. Console](#7-console)
  - [8. Desktop and mobile](#8-desktop-and-mobile)
  - [9. Building from source](#9-building-from-source)
- [License](#license)
- [Project background](#project-background)

---

## Guide

### 1. Playback

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/playback.gif" width="100%">
</p>

The home screen: cover art, track info and transport controls that stay steady while you scrub.

#### 1.1 Now playing

- A scrubbable waveform with chapters and their titles.
- An A-B loop with a repeat count.
- Speed and volume.
- Next and previous tell you when there is nowhere to go.

#### 1.2 Visualizers

- **Spectrum**: a smooth real-time curve.
- **VU meter**: the live level.
- **Waveform**: the seekbar, which fills in as a network track decodes.

---

### 2. Queue

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/queue.gif" width="100%">
</p>

A reorderable queue. Each row shows the track's tags and source, and whether it played, was skipped or failed (and why).

- **Desktop**: a details pane beside the list, right-click menus, and the keyboard to move and play the selection.
- **Phones**: long press for actions, swipe to remove (with undo).

---

### 3. Stream

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/stream.gif" width="100%">
</p>

Network sources, one tab each: Lab, Chapters, Resolver, Jellyfin, Plex and Samba.

#### 3.1 Lab and chapters

**Lab** has reference streams in every common codec, and plays any URL with its own user agent, headers and chunk size (`Media.httpHeaders`, `Media.httpChunkSize`).

**Chapters** plays streams with embedded chapters.

#### 3.2 Source resolver

The **Resolver** tab shows `setSourceResolver` renewing signed links that expire. Turn on Simulate expiry and the first link fails, so the retry (`isRetry`) fetches a fresh one. A live log shows every call.

Any resolver plugs in the same way, for example one that finds the audio behind a web page:

```dart
final cache = <String, String>{};

await player.setSourceResolver((request) async {
  final page = request.media.extras?['pageUrl'] as String?;
  if (page == null) return null; // not ours: keep the URL
  if (!request.isRetry && cache[page] != null) return cache[page];
  final direct = await myExtractor.audioUrlFor(page); // your extractor
  return cache[page] = direct;
});

await player.open(Media('page:track-42', extras: {
  'pageUrl': 'https://media.example/watch/track-42',
  'title': 'My track',
}));
```

#### 3.3 Jellyfin, Plex and Samba

- **Jellyfin** and **Plex**: sign in, then browse and search songs and albums. Playback is reported back to the server.
- **Samba**: browse a share. The password is kept in the system keychain.

---

### 4. Effects

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/effects.gif" width="100%">
</p>

A signal chain you edit while the music plays: add, drag, duplicate, switch off and remove stages.

#### 4.1 The signal chain rack

Quick editors for:

- 18-band equalizer, compressor, bass, treble, sub boost
- stereo width, crossfeed, clarity, loudness

Beyond those, the whole lavfi catalog and raw lavfi stages. A global bypass compares the chain on and off, and the chain is saved in order.

#### 4.2 Interactive editors

Each stage draws its own live view: a compressor curve, a frequency response, a crossfeed diagram, a stereo scope or a loudness gauge. Before and after meters show what the stage does to the signal.

---

### 5. Engine

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/engine.gif" width="100%">
</p>

What the engine is doing right now:

- playback and audio state
- the cache around the playhead, and prefetch
- the waveform and loudness scans
- decoder and output formats
- the effects chain
- the library builds

---

### 6. Settings

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/settings.gif" width="100%">
</p>

| Group | What it holds |
| :--- | :--- |
| **Listening** | Playback, volume, normalization, tracks, visuals and theme |
| **Output** | Device, driver, sample format and buffer |
| **Network** | Cache, streaming, proxy, cookies, certificates and user agent |
| **Advanced** | Logging, engine options, restart, reset and about |

A search finds any setting and jumps to it. Settings read only at startup apply with **Restart player**, which keeps the queue and the position. Your choices are saved.

**Open source licenses**, under About, opens Flutter's license page: the license texts of every Dart package and, from libmpv-r20 on, those of the bundled libmpv, which `mpv_audio_kit` registers: mpv, FFmpeg and the libraries they link, each under its own license. libmpv as built by [libmpv-scripts](https://github.com/ales-drnz/libmpv-scripts) is LGPL, version 3 or later; the `README.txt` of its release's `licenses.zip` names the sources it was built from. The app also bundles libsmb2 (LGPL, version 2.1 or later) through `dart_smb2` on Android, iOS, macOS, Windows and Linux, whose texts the page does not list yet.

---

### 7. Console

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/console.gif" width="100%">
</p>

An mpv command console with the live engine log since launch.

- A command catalog with autocomplete and history.
- mpv's own quoting rules.
- Commands that change what plays keep the app's controls in step.
- Credentials in URLs never show in the log.

---

### 8. Desktop and mobile

<table>
<tr>
<td width="25%"><img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/mobile-playback.gif" width="100%" alt="Playback on a phone"></td>
<td width="25%"><img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/mobile-queue.gif" width="100%" alt="Queue on a phone"></td>
<td width="25%"><img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/mobile-effects.gif" width="100%" alt="Effects on a phone"></td>
<td width="25%"><img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/mobile-stream.gif" width="100%" alt="Stream on a phone"></td>
</tr>
</table>

| Window | Layout |
| :--- | :--- |
| **Phone** | Bottom tabs, sheets, gestures and the Android back button |
| **Tablet, phone in landscape** | A navigation rail |
| **Desktop** | A collapsible sidebar, right-click menus and keyboard shortcuts (press **?** or **F1** for the list) |

The theme is dark, light or follows the system. A welcome screen helps you start on first launch.

---

### 9. Building from source

#### 9.1 Requirements

- **Flutter** 3.47 or newer (3.47.4 or newer for iOS).
- The toolchain for your target: Xcode for Apple, the Android SDK and NDK, or the desktop build tools for Linux and Windows.
- **Linux**: `libsecret-1-dev` to build. At runtime, ALSA, plus PipeWire or PulseAudio when installed. To save the Samba password you need a secret service such as GNOME Keyring or KWallet; without one it is kept for the session only.

#### 9.2 Run

```bash
flutter pub get
flutter run -d macos        # or windows, linux, <android-device>, <ios-device>
```

Build a release with `flutter build <platform>`.

For the browser:

```bash
flutter run -d chrome --wasm --cross-origin-isolation
flutter build web --wasm --no-web-resources-cdn
```

The page must be cross-origin isolated. Where the server cannot send the COOP and COEP headers, as on GitHub Pages, `web/coi-serviceworker.js` adds them.

While the app depends on `mpv_audio_kit` by path, get the library's web files by running `scripts/update_libmpv.sh <release>` (for example `scripts/update_libmpv.sh r20`) in its checkout.

#### 9.3 Continuous integration

GitHub Actions analyzes the code on the oldest supported Flutter and on the current stable, checks formatting, runs the widget and golden tests, and builds the Linux app, an Android APK and the web app, checking with `tool/web_smoke.sh` that the web app boots in Chromium, on every push to main and every pull request. Pushes to main also build Windows, macOS and iOS. That workflow publishes nothing: each run keeps its Linux, Android, Windows and macOS builds as artifacts for a week. A separate workflow, `pages.yml`, makes the same web build and publishes it on GitHub Pages.

---

## License

The code of MPV Studio is BSD-3-Clause ([LICENSE](LICENSE)). The app bundles libmpv through `mpv_audio_kit` (LGPL, version 3 or later, from libmpv-r20 on) and libsmb2 through `dart_smb2` (LGPL, version 2.1 or later), each under its own license.

`web/coi-serviceworker.js` is coi-serviceworker v0.1.7 by Guido Zuidhof and contributors, under the MIT license (see [web/coi-serviceworker.LICENSE](web/coi-serviceworker.LICENSE)).

---

## Project background

The app was implemented through the use of Claude Code.

---

*Developed by Alessandro Di Ronza*
