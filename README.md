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
<td valign="middle"><b>MPV Studio</b> is the standalone reference client for the <a href="https://pub.dev/packages/mpv_audio_kit"><code>mpv_audio_kit</code></a> engine: a cross-platform audio player with a full DSP rack, real-time visualizers, Jellyfin, Plex and Samba streaming, and a built-in mpv command console.</td>
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

    * [3.1 Jellyfin](#31-jellyfin)
    * [3.2 Plex](#32-plex)

    </details>

    <details>
    <summary><a href="#4-effects"><b>4. Effects</b></a></summary>

    * [4.1 The DSP rack](#41-the-dsp-rack)
    * [4.2 Interactive controls](#42-interactive-controls)

    </details>

    <details>
    <summary><a href="#5-settings"><b>5. Settings</b></a></summary>
    </details>

    <details>
    <summary><a href="#6-console"><b>6. Console</b></a></summary>
    </details>

    <details>
    <summary><a href="#7-building-from-source"><b>7. Building from source</b></a></summary>

    * [7.1 Requirements](#71-requirements)
    * [7.2 Run](#72-run)

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

Cover art, track info, a scrubbable seekbar, and a volume control, driven entirely by the engine's reactive streams.

#### 1.2 Visualizers

Three real-time meters fed by mpv_audio_kit's FFT and PCM streams: a log-spaced **spectrum** curve, a **VU** meter, and a progressive **waveform** seekbar that fills in as network tracks decode.

---

### 2. Queue

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/queue.gif" width="100%">
</p>

A reorderable playlist with drag-and-drop, gapless transitions, and a determinate prefetch indicator for the next track.

---

### 3. Stream

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/stream.gif" width="100%">
</p>

Browse and play from self-hosted media servers. Each library tab pages lazily as you scroll.

#### 3.1 Jellyfin

Connects to a Jellyfin server and streams its libraries directly (HLS), seeking through transcoded sources.

#### 3.2 Plex

Resolves Plex transcode URLs lazily through an `on_load` hook and a `/decision` session manager, and reports playback progress back to the server.

---

### 4. Effects

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/effects.gif" width="100%">
</p>

A live DSP rack on top of mpv_audio_kit's `AudioEffects` bundle: toggle and tune effects and hear the change immediately.

#### 4.1 The DSP rack

18-band graphic EQ, compressor, loudness normalization, headphone crossfeed, crystalizer, stereo tools, bass and treble, and more.

#### 4.2 Interactive controls

Each effect renders its own live diagram (a compressor curve, a frequency response curve, a crossfeed diagram, a stereo scope, a loudness gauge), driven by per-filter PCM taps so the visualization tracks the actual signal.

---

### 5. Settings

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/settings.gif" width="100%">
</p>

Every mpv subsystem grouped into one screen: audio engine and output, audio track, A-B loop, chapters, demuxer cache, hooks, OS media session, and streaming. Choices persist across launches.

---

### 6. Console

<p align="center">
  <img src="https://raw.githubusercontent.com/ales-drnz/mpv_studio/main/imgs/console.gif" width="100%">
</p>

A built-in mpv command console with a command catalog, autocomplete suggestions, and the live engine log, captured from boot, so it's never empty when you open it.

---

### 7. Building from source

#### 7.1 Requirements

- **Flutter** 3.38 or newer (Dart 3.10). Building for iOS needs Flutter 3.47.4 or newer.
- **Android** SDK 24 (Android 7.0) or newer on the device.
- **Linux** glibc 2.31 or newer, with ALSA; PipeWire or PulseAudio when installed.
- The native toolchain for your target platform (Xcode for Apple, Android SDK and NDK for Android, the desktop build tools for Linux and Windows).

#### 7.2 Run

```bash
flutter pub get
flutter run -d macos        # or windows, linux, <android-device>, <ios-device>
```

To build a release artifact, use the standard `flutter build <platform>`.

---

## Project background

The app was implemented through the use of Claude Code.

---

*Developed by Alessandro Di Ronza*
