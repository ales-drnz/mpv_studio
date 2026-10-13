import 'package:flutter/widgets.dart';

import 'sections/advanced_sections.dart';
import 'sections/audio_track_section.dart';
import 'sections/cache_sections.dart';
import 'sections/connection_section.dart';
import 'sections/device_section.dart';
import 'sections/driver_section.dart';
import 'sections/normalization_section.dart';
import 'sections/output_status_section.dart';
import 'sections/playback_section.dart';
import 'sections/resume_section.dart';
import 'sections/session_section.dart';
import 'sections/visuals_section.dart';
import 'settings_catalog.dart';

/// The section cards of [group], top to bottom.
List<Widget> settingsSections(SettingsGroupId group) => switch (group) {
  SettingsGroupId.listening => const [
    PlaybackSection(),
    VolumeSection(),
    LoudnessSection(),
    ReplayGainSection(),
    DownmixSection(),
    ResumeSection(),
    AudioTrackSection(),
    VisualizerSection(),
    CoverArtSection(),
    AppearanceSection(),
    SessionSection(),
  ],
  SettingsGroupId.output => const [
    DeviceSection(),
    DriverSection(),
    PassthroughSection(),
    OutputStatusSection(),
  ],
  SettingsGroupId.network => const [
    ConnectionSection(),
    StreamingSection(),
    CacheSection(),
    DemuxerSection(),
  ],
  SettingsGroupId.advanced => const [
    LoggingSection(),
    EngineOptionsSection(),
    PlayerSection(),
    AboutSection(),
  ],
};
