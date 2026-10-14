import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/tokens.dart';

/// The edge of the screen a [SnackObstacle] covers.
enum SnackEdge { bottom, left }

/// Keeps the app's floating toasts clear of the shell chrome: the
/// mini-player, the bottom tab bar and the rail mini-player. Each piece of
/// chrome wraps itself in a [SnackObstacle], which reports how far it
/// reaches in from its screen edge; this host turns the widest reach per
/// edge into the theme's snack bar margin
/// ([SnackBarThemeData.insetPadding]) for the [Scaffold] below, so every
/// toast floats above the chrome whatever shows it.
class SnackClearanceHost extends StatefulWidget {
  const SnackClearanceHost({super.key, required this.child});

  /// The [Scaffold] that hosts the toasts, with the chrome inside it.
  final Widget child;

  /// The toast's margin with no chrome to clear: 16 at the sides, 8 above
  /// and below.
  static const EdgeInsets baseMargin = EdgeInsets.symmetric(
    horizontal: Tokens.s16,
    vertical: Tokens.s8,
  );

  @override
  State<SnackClearanceHost> createState() => _SnackClearanceHostState();
}

class _SnackClearanceHostState extends State<SnackClearanceHost> {
  final Map<Object, (SnackEdge, double)> _reach = {};

  double _widest(SnackEdge edge) => _reach.values
      .where((r) => r.$1 == edge)
      .fold(0, (m, r) => math.max(m, r.$2));

  void _report(Object id, SnackEdge edge, double? reach) {
    final now = reach == null ? null : (edge, reach);
    if (_reach[id] == now) return;
    if (now == null) {
      _reach.remove(id);
    } else {
      _reach[id] = now;
    }
    if (mounted) setState(() {});
  }

  /// Where [box] sits in this host, or null before both are laid out.
  Rect? _rectOf(RenderBox box) {
    final host = context.findRenderObject();
    if (host is! RenderBox || !host.hasSize || !box.hasSize) return null;
    if (!box.attached || !host.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: host);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    // The floating toast already sits above the bottom safe-area inset and
    // inside the side ones, so the reach is counted past those.
    // A soft keyboard over the pinned tab bar hides the toast too.
    final reach = math.max(_widest(SnackEdge.bottom), media.viewInsets.bottom);
    final bottom = math.max(0.0, reach - media.padding.bottom);
    final left = math.max(0.0, _widest(SnackEdge.left) - media.padding.left);
    final margin =
        SnackClearanceHost.baseMargin +
        EdgeInsets.only(left: left, bottom: bottom);
    return _SnackClearanceScope(
      host: this,
      child: Theme(
        data: theme.copyWith(
          snackBarTheme: theme.snackBarTheme.copyWith(insetPadding: margin),
        ),
        child: widget.child,
      ),
    );
  }
}

class _SnackClearanceScope extends InheritedWidget {
  const _SnackClearanceScope({required this.host, required super.child});

  final _SnackClearanceHostState host;

  @override
  bool updateShouldNotify(_SnackClearanceScope old) => host != old.host;
}

/// Marks [child] as chrome a toast must not cover: it reports to the
/// [SnackClearanceHost] above how far it reaches in from [edge] (from the
/// bottom of the screen to its top, or from the left of the screen to its
/// right side). Without a host it is just [child].
class SnackObstacle extends StatefulWidget {
  const SnackObstacle({super.key, required this.edge, required this.child});

  final SnackEdge edge;
  final Widget child;

  @override
  State<SnackObstacle> createState() => _SnackObstacleState();
}

class _SnackObstacleState extends State<SnackObstacle> {
  _SnackClearanceHostState? _host;

  void _measure() {
    final host = _host;
    if (!mounted || host == null || !host.mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final rect = host._rectOf(box);
    final hostBox = host.context.findRenderObject();
    if (rect == null || hostBox is! RenderBox) return;
    final reach = switch (widget.edge) {
      SnackEdge.bottom => hostBox.size.height - rect.top,
      SnackEdge.left => rect.right,
    };
    host._report(this, widget.edge, reach);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = context
        .dependOnInheritedWidgetOfExactType<_SnackClearanceScope>()
        ?.host;
    if (host != _host) {
      _withdraw(_host, widget.edge);
      _host = host;
    }
  }

  @override
  void didUpdateWidget(SnackObstacle old) {
    super.didUpdateWidget(old);
    if (old.edge != widget.edge) _withdraw(_host, old.edge);
  }

  @override
  void dispose() {
    _withdraw(_host, widget.edge);
    super.dispose();
  }

  /// Takes this obstacle's reach at [edge] off [host] after the frame:
  /// the host may be building this very frame, and rebuilding it now
  /// would mark an ancestor dirty during the build.
  void _withdraw(_SnackClearanceHostState? host, SnackEdge edge) {
    if (host == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => host._report(this, edge, null),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt on every window or inset change, so the reach is measured
    // again after each such layout.
    MediaQuery.sizeOf(context);
    MediaQuery.paddingOf(context);
    MediaQuery.viewInsetsOf(context);
    MediaQuery.textScalerOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return widget.child;
  }
}
