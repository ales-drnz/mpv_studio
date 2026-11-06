import 'package:flutter/material.dart';

/// Shows a toast, with an optional action: [showStudioSnack] bound to a
/// context, for code that has none of its own.
typedef StudioToast =
    void Function(
      String message, {
      String? actionLabel,
      VoidCallback? onAction,
    });

/// The label of the action that takes back what a toast reports.
const undoLabel = 'Undo';

/// The Undo toast each messenger shows, while it is up.
final _undoToast = Expando<Object>('undo toast');

/// The latest toast held back behind an Undo, shown when it goes.
final _held = Expando<VoidCallback>('held toast');

/// The app's toast: a floating snack bar in the theme's snack bar colours
/// (`AppTheme`'s `snackBarTheme`), with an optional action. Every toast of
/// the app goes through here, so they all look and behave alike.
extension StudioSnack on ScaffoldMessengerState {
  /// Shows [message] for [duration]. With [replace] (the default) the
  /// toast on screen goes first, so a burst shows the latest only;
  /// without, toasts queue. [actionLabel] and [onAction] add a button.
  ///
  /// An Undo is never pushed away: while one is up, a later toast that is
  /// not an Undo waits for it, the latest only, and the call returns null.
  /// Toasts time out, an Undo too, unless a screen reader is on: then an
  /// Undo stays until it is used or dismissed.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showStudioSnack(
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    bool replace = true,
  }) {
    final hasAction = actionLabel != null && onAction != null;
    final undo = hasAction && actionLabel == undoLabel;
    if (!undo && _undoToast[this] != null) {
      _held[this] = () => showStudioSnack(
        message,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        replace: replace,
      );
      return null;
    }
    if (replace) hideCurrentSnackBar();
    final reader = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    final shown = showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        // Every toast times out, an action or not (Flutter keeps one with
        // an action up until it is dismissed by default); a swipe still
        // dismisses it sooner. A screen reader user needs the time to
        // reach an Undo.
        persist: undo && reader,
        action: hasAction
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
    if (undo) {
      final token = Object();
      _undoToast[this] = token;
      shown.closed.whenComplete(() {
        if (!identical(_undoToast[this], token)) return;
        _undoToast[this] = null;
        final held = _held[this];
        _held[this] = null;
        if (mounted) held?.call();
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
