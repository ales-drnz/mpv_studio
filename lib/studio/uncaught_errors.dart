import 'package:flutter/foundation.dart';

import '../util/redact.dart';
import 'mpv_studio.dart';

/// Catches the errors nothing else handled (framework errors, async
/// errors that escaped a handler) and hands them to the running studio,
/// which logs them in the Console and shows a notice, instead of letting
/// them pass silently. Installed once by `main`; the app points [target]
/// at each new studio after a restart.
class UncaughtErrors {
  UncaughtErrors._();

  /// Installs the handlers on [FlutterError.onError] and
  /// [PlatformDispatcher.onError], keeping the framework's own console
  /// report.
  factory UncaughtErrors.install() {
    final errors = UncaughtErrors._();
    final present = FlutterError.onError;
    FlutterError.onError = (details) {
      present?.call(details);
      errors._report(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Uncaught error: ${redactSecrets('$error')}\n$stack');
      errors._report(error, stack);
      return true;
    };
    return errors;
  }

  /// The studio errors are reported to; null before the first launch.
  MpvStudio? target;

  bool _reporting = false;

  void _report(Object error, StackTrace? stack) {
    // An error raised while reporting would loop.
    if (_reporting) return;
    _reporting = true;
    try {
      target?.reportUncaught(error, stack);
    } on Object catch (e) {
      debugPrint('Could not report an uncaught error: ${redactSecrets('$e')}');
    } finally {
      _reporting = false;
    }
  }
}
