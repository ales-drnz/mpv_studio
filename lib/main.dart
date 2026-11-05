import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'app.dart';
import 'studio/app_licenses.dart';
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
  registerAppLicenses();

  // Installed first, so even an error during the launch is reported.
  await _start(UncaughtErrors.install());
}

/// Launches the studio and runs the app on it; when the engine does not
/// start, runs a screen that says why and tries again.
Future<void> _start(UncaughtErrors errors) async {
  // A browser that cannot run libmpv says why before a player is made;
  // trying again would fail the same way.
  if (MpvAudioKit.unsupportedReason case final reason?) {
    _runError(reason, unsupported: true);
    return;
  }
  try {
    final studio = await MpvStudio.launch();
    errors.target = studio;
    runApp(MpvStudioApp(studio: studio, errors: errors));
  } on Object catch (error) {
    debugPrint('MPV Studio did not start: ${redactSecrets('$error')}');
    _runError(error, onRetry: () => _start(errors));
  }
}

/// Runs the screen that says why the engine did not start.
void _runError(
  Object error, {
  VoidCallback? onRetry,
  bool unsupported = false,
}) => runApp(
  MaterialApp(
    title: 'MPV Studio',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.of(Palette.dark, input: InputMode.platformDefault),
    builder: (context, child) => LayoutScope(child: child!),
    home: StartupErrorView(
      error: error,
      onRetry: onRetry,
      unsupported: unsupported,
    ),
  ),
);
