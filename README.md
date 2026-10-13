# MPV Studio

#### Cross-platform audio player built on mpv_audio_kit.

[![](https://img.shields.io/badge/built%20with-mpv__audio__kit-orange.svg?style=for-the-badge)](https://pub.dev/packages/mpv_audio_kit)
[![](https://img.shields.io/badge/Flutter-3.38+-blue.svg?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![](https://img.shields.io/github/stars/ales-drnz/mpv_studio?style=for-the-badge&logo=github&logoColor=white)](https://github.com/ales-drnz/mpv_studio)
[![](https://img.shields.io/discord/1485588004029333516?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/g2Qf4Mq9MP)
[![](https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white)](https://www.patreon.com/cw/ales_drnz)
[![](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/ales.drnz)

<table>
<tr>
<td valign="middle" width="90"><img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/assets/mpv_studio.png" width="70" alt="logo"></td>
<td valign="middle"><b>MPV Studio</b> is the standalone reference client for the <a href="https://pub.dev/packages/mpv_audio_kit"><code>mpv_audio_kit</code></a> engine: a cross-platform audio player with a signal chain rack, real-time visualizers, Jellyfin, Plex and Samba streaming, an engine inspector and a built-in mpv command console. It adapts to every window, from a phone in portrait to an ultrawide desktop, in a dark and a light theme.</td>
</tr>
</table>

---

## Platforms

| Platform  | Minimum | Architectures |
| :--- | :--- | :--- |
| **Android** | 7.0 (SDK 24) | arm64-v8a, armeabi-v7a, x86_64 |
| **iOS** | 15.0 | arm64, x86_64 |
| **macOS** | 12.0 | arm64, x86_64 |
| **Windows**| 10 | arm64, x86_64 |
| **Linux** | glibc 2.31 (Ubuntu 20.04, Debian 11) | aarch64, x86_64 |

---

## Contents

*   [Guide](#guide)
    <details>
    <summary><a href="#1-playback"><b>1. Playback</b></a></summary>

    * [1.1 Now playing](#11-now-playing)
    * [1.2 Visualizers](#12-visualizers)

    </details>

    <details>
    <summary><a href="#2-queue"><b>2. Queue</b></a></summary>
    </details>

    <details>
    <summary><a href="#3-stream"><b>3. Stream</b></a></summary>

    * [3.1 Lab and chapters](#31-lab-and-chapters)
    * [3.2 Source resolver](#32-source-resolver)
    * [3.3 Jellyfin, Plex and Samba](#33-jellyfin-plex-and-samba)

    </details>

    <details>
    <summary><a href="#4-effects"><b>4. Effects</b></a></summary>

    * [4.1 The signal chain rack](#41-the-signal-chain-rack)
    * [4.2 Interactive editors](#42-interactive-editors)

    </details>

    <details>
    <summary><a href="#5-engine"><b>5. Engine</b></a></summary>
    </details>

    <details>
    <summary><a href="#6-settings"><b>6. Settings</b></a></summary>
    </details>

    <details>
    <summary><a href="#7-console"><b>7. Console</b></a></summary>
    </details>

    <details>
    <summary><a href="#8-desktop-and-mobile"><b>8. Desktop and mobile</b></a></summary>
    </details>

    <details>
    <summary><a href="#9-building-from-source"><b>9. Building from source</b></a></summary>

    * [9.1 Requirements](#91-requirements)
    * [9.2 Run](#92-run)
    * [9.3 Continuous integration](#93-continuous-integration)

    </details>
*   [Project background](#project-background)

---

## Guide

### 1. Playback

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/playback.gif" width="100%">
</p>

The home screen: cover art, metadata and transport bound to mpv_audio_kit's play-pause **intent**, so the controls never flicker while you scrub.


#### 1.1 Now playing

Cover art, track info, a scrubbable waveform, chapters with their titles, an A-B loop with a repeat count, speed and volume, driven entirely by the engine's reactive streams. Next and previous say so when there is nowhere to go.

#### 1.2 Visualizers

Three real-time meters fed by mpv_audio_kit's FFT and PCM streams: a log-spaced **spectrum** curve, a **VU** meter, and a progressive **waveform** seekbar that fills in as network tracks decode.

---

### 2. Queue

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/queue.gif" width="100%">
</p>

A reorderable queue with gapless transitions. Each row shows the tags as soon as the engine reads them, where the track comes from, and whether it played, was skipped or failed and why. On desktop a details pane sits beside the list, rows have a right-click menu and the keyboard moves and plays the selection; on phones a long press opens the actions and a swipe removes a row.

---

### 3. Stream

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/stream.gif" width="100%">
</p>

Network sources, one tab each.

#### 3.1 Lab and chapters

Reference streams in every common codec, and any URL with its own HTTP options: a user agent, custom headers and a chunk size, sent through `Media.httpHeaders` and `Media.httpChunkSize`. The Chapters tab plays streams with embedded chapters.

#### 3.2 Source resolver

The Resolver tab shows `setSourceResolver` at work: it plays signed links that expire, and with Simulate expiry the first link fails, so the retry (`isRetry`) gets a fresh one. A live log shows every call. Any resolver plugs in the same way, a YouTube one included:

```dart
// Entries carry the page URL; the resolver turns it into a direct audio URL
// right before mpv opens it, and again when that URL has expired.
final cache = <String, String>{};

await player.setSourceResolver((request) async {
  final page = request.media.extras?['pageUrl'] as String?;
  if (page == null) return null; // not ours: keep the URL as is
  if (!request.isRetry && cache[page] != null) return cache[page];
  // Your extractor of choice: a web API, a script, a library.
  final direct = await myExtractor.audioUrlFor(page);
  return cache[page] = direct; // a fresh link on every retry
});

await player.open(Media('yt:dQw4w9WgXcQ', extras: {
  'pageUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  'title': 'My video',
}));
```

#### 3.3 Jellyfin, Plex and Samba

Sign in to a Jellyfin or Plex server and browse its songs and albums, or walk a Samba share. Plex transcode sessions open through the same source resolver, and playback progress is reported back to the server. The Samba password is kept in the system keychain.

---

### 4. Effects

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/effects.gif" width="100%">
</p>

A live signal chain on top of mpv_audio_kit's effects: stages in play order that you add, drag, duplicate, switch off and edit while the music plays.

#### 4.1 The signal chain rack

Quick editors for an 18-band equalizer, compressor, bass, treble, sub boost, stereo width, crossfeed, clarity and loudness, the whole lavfi catalog, and raw lavfi stages. A global bypass compares the chain on and off, and the chain is saved in order.

#### 4.2 Interactive editors

Each stage draws its own live diagram (a compressor curve, a frequency response curve, a crossfeed diagram, a stereo scope, a loudness gauge) with before and after meters fed by per-stage taps, so the picture follows the actual signal.

---

### 5. Engine

What the engine is doing right now: play request and audio state, the demuxer cache around the playhead, prefetch, the waveform and loudness scans, the decoder and device formats, the effects chain and the library builds.

---

### 6. Settings

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/settings.gif" width="100%">
</p>

Every setting grouped by purpose: Listening, Output, Network (cache, streaming, proxy, cookies, certificates, user agent) and Advanced. A search finds any setting and jumps to it. Settings the player reads only at startup apply with a Restart player button that keeps the queue and the position. Choices persist across launches.

---

### 7. Console

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/console.gif" width="100%">
</p>

A built-in mpv command console with a command catalog, autocomplete, history, mpv's own quoting and the live engine log, captured from boot. Commands that change what plays go through the Player API, so the controls stay in step, and credentials in URLs never show in the log.

---

### 8. Desktop and mobile

Phones get bottom tabs, sheets, gestures and the Android back button; tablets and phones in landscape get a navigation rail; desktop gets a collapsible sidebar, hover, right-click menus and keyboard shortcuts (press ? or F1 for the list). The theme follows the logo's graphite, ring grey and white, in dark, light or the system's choice. A welcome screen on first launch helps you start.

---

### 9. Building from source

#### 9.1 Requirements

- **Flutter** 3.38 or newer (Dart 3.10). Building for iOS needs Flutter 3.47.4 or newer.
- **Android** SDK 24 (Android 7.0) or newer on the device.
- **Linux** glibc 2.31 or newer, with ALSA; PipeWire or PulseAudio when installed. Building needs libsecret (`libsecret-1-dev` on Debian and Ubuntu), and saving the Samba password needs a secret service such as GNOME Keyring or KWallet; without one the password is kept for the session only.
- The native toolchain for your target platform (Xcode for Apple, Android SDK and NDK for Android, the desktop build tools for Linux and Windows).

#### 9.2 Run

```bash
flutter pub get
flutter run -d macos        # or windows, linux, <android-device>, <ios-device>
```

To build a release artifact, use the standard `flutter build <platform>`.

#### 9.3 Continuous integration

GitHub Actions analyzes the code on the oldest supported Flutter and on the current stable, checks formatting, runs the widget and golden tests, and builds the Linux app and an Android APK on every push and pull request. Pushes to main also build Windows, macOS and iOS. Nothing is published: each run keeps its builds as artifacts for a week.

---

## Project background

The app was implemented through the use of Claude Code.

---

*Developed by Alessandro Di Ronza*
