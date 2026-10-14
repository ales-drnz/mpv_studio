import 'package:flutter/material.dart';

/// The app's toast: a floating snack bar in the theme's snack bar colours
/// (`AppTheme`'s `snackBarTheme`), with an optional action. Every toast of
/// the app goes through here, so they all look and behave alike.
extension StudioSnack on ScaffoldMessengerState {
  /// Shows [message] for [duration]. With [replace] (the default) the
  /// toast on screen goes first, so a burst shows the latest only;
  /// without, toasts queue. [actionLabel] and [onAction] add a button;
  /// a toast with one still goes after [duration].
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showStudioSnack(
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    bool replace = true,
  }) {
    if (replace) hideCurrentSnackBar();
    return showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        // Every toast times out, an action or not (Flutter keeps one with
        // an action up until it is dismissed by default); a swipe still
        // dismisses it sooner.
        persist: false,
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
  }
}

/// Shows [message] as the app's toast on the messenger above [context]
/// (see [StudioSnack.showStudioSnack]). Does nothing without a messenger
/// or once [context] is gone.
void showStudioSnack(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
  bool replace = true,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showStudioSnack(
    message,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    replace: replace,
  );
}
