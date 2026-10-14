@Tags(['showcase'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/settings/settings_page.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/widgets/controls/dropdown.dart';

import '../../tool/showcase/showcase.dart';
import '../settings/studio_fakes.dart';
import '../support/layout_harness.dart';
import 'showcase_app.dart';
import 'showcase_covers.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';

/// The Settings showcase (imgs/settings.gif): a search jumps to the
/// theme, which goes light and back to dark; the output device list
/// shows the devices with their ids; the Left key takes the track back
/// to where the scene began.
///
/// Rendered by `tool/showcase/render.sh settings`; skipped otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('settings scene', (tester) async {
    late final Uint8List cover;
    await tester.runAsync(() async => cover = await paintCover(5));
    final scene = Scene(tester, outDir: showcaseOut);
    final player = ShowcasePlayer.queue(
      showcaseAlbum('Glass Orchard').files,
      covers: {5: cover},
      index: 1,
      at: const Duration(minutes: 1, seconds: 4),
    );
    addTearDown(player.close);

    // The Settings services run on their own lenient fake, with a few
    // output devices to list.
    final h = await SettingsHarness.create();
    const builtIn = Device(
      name: 'pipewire/alsa_output.pci-0000_00_1f.3.analog-stereo',
      description: 'Built-in Audio Analog Stereo',
    );
    const devices = [
      Device.auto,
      builtIn,
      Device(
        name: 'pipewire/alsa_output.usb-Studio_Interface_2x2-00.analog-stereo',
        description: 'Studio Interface 2x2',
      ),
      Device(
        name: 'pipewire/bluez_output.studio_headphones.1',
        description: 'Studio Headphones',
      ),
      Device(
        name: 'pulse/alsa_output.pci-0000_00_1f.3.hdmi-stereo',
        description: 'HDMI Audio',
      ),
    ];
    h.player.emit(
      (s) => s.copyWith(audioDevices: devices, audioDevice: builtIn),
    );

    await pumpShowcaseApp(
      tester,
      player,
      scene: scene,
      size: desktopShowcaseSize,
      section: Section.settings,
      page: (s) => h.wrap(const SettingsPage()),
    );
    drivePlayer(scene, player);

    final search = find.byType(TextField).first;
    final rest = Offset(tester.getRect(search).right - 60, 600);

    // Searches [query] and opens the result titled [title].
    Future<void> jump(String query, String title) async {
      await scene.moveOnto(search, alignment: const Alignment(-0.7, 0));
      await scene.click();
      await scene.wait(200);
      await scene.type(query, msPerChar: 80);
      await scene.wait(600);
      await scene.moveOnto(find.text(title).last);
      await scene.click();
    }

    final control = find.descendant(
      of: find.ancestor(
        of: find.text('Device'),
        matching: find.byType(DropdownRow<Device>),
      ),
      matching: find.byType(AppDropdown<Device>),
    );

    // The warm-up ends as the scene does: the Output group open, a device
    // just picked from its list, the search cleared.
    await scene.showPointer(rest);
    await tester.tap(search);
    await tester.enterText(search, 'x');
    await scene.wait(200);
    await tester.tap(find.byTooltip('Clear search'));
    await scene.wait(200);
    await tester.tap(find.text('Output').first);
    await scene.wait(500);
    await tester.tap(control);
    await scene.wait(500);
    await tester.tap(find.text(builtIn.name).last);
    FocusManager.instance.primaryFocus?.unfocus();
    await scene.wait(1000);

    scene.record();
    final first = player.playhead + scene.step;
    await scene.wait(350);

    // A search jumps to the theme, which lights up: light, then dark.
    await jump('theme', 'Theme');
    await scene.wait(600);
    await scene.moveOnto(find.text('Light').last);
    await scene.click();
    await scene.wait(950);
    await scene.moveOnto(find.text('Dark').last);
    await scene.click();
    await scene.wait(350);
    await scene.moveOnto(find.byTooltip('Clear search'));
    await scene.click();
    await scene.wait(200);

    // The output devices, ids and all.
    await scene.moveOnto(find.text('Output').first);
    await scene.click();
    await scene.wait(450);
    await scene.moveOnto(control);
    await scene.click();
    await scene.wait(400);
    for (final d in devices.skip(2).take(2)) {
      await scene.moveOnto(find.text(d.name).last, ms: 300);
      await scene.wait(150);
    }
    await scene.moveOnto(find.text(builtIn.name).last);
    await scene.click();
    await scene.wait(300);
    await scene.moveTo(rest);
    await rewindToLoop(scene, player, first, tailMs: 300);
    await playUntilLoop(scene, player, first);

    final frames = scene.written;
    await scene.finish();
    debugPrint('showcase settings: $frames frames at ${scene.fps} fps');
  });
}
