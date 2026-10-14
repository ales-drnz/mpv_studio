import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'app.dart';
import 'studio/mpv_studio.dart';
import 'studio/startup_error_view.dart';
import 'studio/uncaught_errors.dart';
import 'ui/layout/layout.dart';
import 'ui/palette.dart';
import 'ui/theme.dart';
import 'util/redact.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MpvAudioKit.ensureInitialized();

  // Installed first, so even an error during the launch is reported.
  await _start(UncaughtErrors.install());
}

/// Launches the studio and runs the app on it; when the engine does not
/// start, runs a screen that says why and tries again.
Future<void> _start(UncaughtErrors errors) async {
  try {
    final studio = await MpvStudio.launch();
    errors.target = studio;
    runApp(MpvStudioApp(studio: studio, errors: errors));
  } on Object catch (error) {
    debugPrint('MPV Studio did not start: ${redactSecrets('$error')}');
    runApp(
      MaterialApp(
        title: 'MPV Studio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(Palette.dark, input: InputMode.platformDefault),
        builder: (context, child) => LayoutScope(child: child!),
        home: StartupErrorView(error: error, onRetry: () => _start(errors)),
      ),
    );
  }
}
