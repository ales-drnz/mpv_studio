import 'package:flutter/widgets.dart';

/// Tells a Stream tab whether it is the one on screen. The page keeps every
/// tab mounted (so a sign-in or a folder survives a tab switch); a hidden
/// tab reads this to stand down what would otherwise act on screen, such
/// as its handling of the system back.
class StreamTabScope extends InheritedWidget {
  const StreamTabScope({super.key, required this.active, required super.child});

  final bool active;

  /// Whether the tab around [context] is on screen; true outside a page.
  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StreamTabScope>()?.active ??
      true;

  @override
  bool updateShouldNotify(StreamTabScope oldWidget) =>
      oldWidget.active != active;
}
