import 'package:flutter/material.dart';

import '../studio/playback_issues.dart';
import '../studio/player_scope.dart';
import '../ui/tokens.dart';
import '../util/reactive.dart';

/// Shows the app's [PlaybackNotice]s as toasts with a "Show log" action, and
/// tells [PlaybackIssues] whether the Console is on screen so its badge
/// clears. Wraps the shell; draws nothing itself.
class PlaybackNoticeHost extends StatefulWidget {
  const PlaybackNoticeHost({
    super.key,
    required this.consoleVisible,
    required this.onShowLog,
    required this.child,
  });

  /// Whether the Console section is the one on screen.
  final bool consoleVisible;

  /// Opens the Console.
  final VoidCallback onShowLog;

  final Widget child;

  @override
  State<PlaybackNoticeHost> createState() => _PlaybackNoticeHostState();
}

class _PlaybackNoticeHostState extends State<PlaybackNoticeHost>
    with StreamListenerState<PlaybackNoticeHost> {
  late PlaybackIssues _issues;

  @override
  void onSubscribe() {
    _issues = PlayerScope.issuesOf(context);
    _issues.consoleVisible = widget.consoleVisible;
    listen(_issues.notices, _show);
  }

  @override
  void didUpdateWidget(PlaybackNoticeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consoleVisible != widget.consoleVisible) {
      _issues.consoleVisible = widget.consoleVisible;
    }
  }

  void _show(PlaybackNotice notice) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    // A burst of failures (a queue of dead links) shows the latest only.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(notice.message, style: const TextStyle(color: Tokens.fg)),
        backgroundColor: Tokens.surface3,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: widget.consoleVisible
            ? null
            : SnackBarAction(
                label: 'Show log',
                textColor: Tokens.accent,
                onPressed: widget.onShowLog,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
