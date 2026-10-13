import 'package:flutter/widgets.dart';

/// What a [StudioHost] tells its builder about restarting.
@immutable
class StudioRestart {
  const StudioRestart({required this.run, required this.inProgress});

  /// Restarts the hosted studio. Completes once the new one is on screen;
  /// a second call while one runs waits for that one.
  final Future<void> Function() run;

  /// Whether a restart is under way (the old studio may already be gone).
  final bool inProgress;
}

/// Holds the running studio (the app's services around the player) and
/// swaps it for a new one on restart.
///
/// The subtree [builder] makes is keyed by the studio, so on a swap every
/// page is built afresh and subscribes to the new player: nothing keeps a
/// reference to the old one. When a restart fails (the old studio is shut
/// down by then) [errorBuilder] shows the error with a retry that calls
/// [launch].
class StudioHost<T extends Object> extends StatefulWidget {
  const StudioHost({
    super.key,
    required this.initial,
    required this.restart,
    required this.launch,
    required this.builder,
    required this.errorBuilder,
    this.onChanged,
  });

  /// The studio running when the host is first built.
  final T initial;

  /// Shuts [current] down and returns its successor.
  final Future<T> Function(T current) restart;

  /// Starts a studio from scratch, for the retry after a failed restart.
  final Future<T> Function() launch;

  final Widget Function(BuildContext context, T studio, StudioRestart restart)
  builder;

  final Widget Function(BuildContext context, Object error, VoidCallback retry)
  errorBuilder;

  /// Called with each new studio, after it replaced the previous one.
  final ValueChanged<T>? onChanged;

  @override
  State<StudioHost<T>> createState() => _StudioHostState<T>();
}

class _StudioHostState<T extends Object> extends State<StudioHost<T>> {
  late T _studio = widget.initial;
  Object? _error;
  Future<void>? _running;

  Future<void> _restart() => _start(() => widget.restart(_studio));

  void _retry() => _start(widget.launch);

  /// Runs one swap at a time: a call while one runs joins it. [_running]
  /// is set before the swap starts and cleared only when it ended, even
  /// when [next] throws before its first await.
  Future<void> _start(Future<T> Function() next) {
    final running = _running;
    if (running != null) return running;
    final done = _swap(next).whenComplete(() {
      _running = null;
      if (mounted) setState(() {});
    });
    _running = done;
    setState(() {});
    return done;
  }

  Future<void> _swap(Future<T> Function() next) async {
    // Let the caller record the swap as running before anything happens.
    await null;
    try {
      final studio = await next();
      if (!mounted) return;
      setState(() {
        _studio = studio;
        _error = null;
      });
      widget.onChanged?.call(studio);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null && _running == null) {
      return widget.errorBuilder(context, error, _retry);
    }
    return KeyedSubtree(
      key: ObjectKey(_studio),
      child: widget.builder(
        context,
        _studio,
        StudioRestart(run: _restart, inProgress: _running != null),
      ),
    );
  }
}
