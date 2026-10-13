import 'dart:async';

import 'package:flutter/widgets.dart';

/// Drop-in for a [State] that needs to listen to one or more streams for
/// the lifetime of the widget. Removes the `didChangeDependencies` guard +
/// per-field `StreamSubscription` + `dispose` bookkeeping that was
/// copy-pasted across every visualizer and page.
///
/// Override [onSubscribe] (called exactly once, after dependencies are
/// first available so `InheritedWidget`s like `PlayerScope` can be read)
/// and register streams with [listen]. Cancellation is automatic.
///
/// ```dart
/// class _State extends State<Foo> with StreamListenerState<Foo> {
///   @override
///   void onSubscribe() {
///     final player = PlayerScope.of(context);
///     listen(player.stream.pcm, _onFrame);
///   }
/// }
/// ```
mixin StreamListenerState<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _subscribed = false;

  /// Register the widget's stream listeners here. Called once, lazily, on
  /// the first [didChangeDependencies].
  void onSubscribe();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    _subscribed = true;
    onSubscribe();
  }

  /// Subscribe to [stream] for the widget's lifetime; cancelled in
  /// [dispose] automatically.
  void listen<E>(Stream<E> stream, void Function(E event) onData) {
    _subscriptions.add(stream.listen(onData));
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Pairs a `player.stream.X` with its `player.state.X` seed in one
/// widget so call sites never write `?? default` fallbacks. The single
/// reactive primitive used across MPV Studio.
///
/// State streams replay their current value to each new listener, but that
/// first event arrives after the first frame. [initial] fills that frame, so
/// a widget never flashes a default before showing the real value.
class Live<T> extends StatelessWidget {
  final Stream<T> stream;
  final T initial;
  final Widget Function(BuildContext context, T value) builder;

  const Live({
    super.key,
    required this.stream,
    required this.initial,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initial,
      builder: (context, snap) => builder(context, snap.data ?? initial),
    );
  }
}
