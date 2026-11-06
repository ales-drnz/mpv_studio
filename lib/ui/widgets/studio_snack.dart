import 'package:flutter/material.dart';

/// Shows a toast, with an optional action: [showStudioSnack] bound to a
/// context, for code that has none of its own.
typedef StudioToast =
    void Function(
      String message, {
      String? actionLabel,
      VoidCallback? onAction,
    });

/// The app's toast: a floating snack bar in the theme's snack bar colours
/// (`AppTheme`'s `snackBarTheme`), with an optional action. Every toast of
/// the app goes through here, so they all look and behave alike.
/// The toast with an action each messenger shows, while it is up.
final _actionToast = Expando<Object>('action toast');

extension StudioSnack on ScaffoldMessengerState {
  /// Shows [message] for [duration]. With [replace] (the default) the
  /// toast on screen goes first, so a burst shows the latest only;
  /// without, toasts queue. A toast without an action never replaces one
  /// with an action (an Undo): it waits for it instead. [actionLabel] and
  /// [onAction] add a button; a toast with one still goes after
  /// [duration], unless a screen reader is on, where it stays until it is
  /// used or dismissed.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showStudioSnack(
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    bool replace = true,
  }) {
    final hasAction = actionLabel != null && onAction != null;
    final behindAction = !hasAction && _actionToast[this] != null;
    if (replace && !behindAction) hideCurrentSnackBar();
    final reader = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    final shown = showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        // Every toast times out, an action or not (Flutter keeps one with
        // an action up until it is dismissed by default); a swipe still
        // dismisses it sooner. A screen reader user needs the time to
        // reach the action.
        persist: hasAction && reader,
        action: hasAction
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
    if (hasAction) {
      final token = Object();
      _actionToast[this] = token;
      shown.closed.whenComplete(() {
        if (identical(_actionToast[this], token)) _actionToast[this] = null;
      });
    }
    return shown;
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

/// A [StudioToast] on the messenger above [context].
StudioToast studioToastFor(BuildContext context) =>
    (message, {actionLabel, onAction}) => showStudioSnack(
      context,
      message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
