import 'package:flutter/widgets.dart';

/// Where the user left things (the section, the sidebar, the Stream tab,
/// the waveform height, the settings group), kept between launches. The
/// app backs it with its settings; without one nothing is kept.
class UiMemory extends InheritedWidget {
  const UiMemory({
    super.key,
    required this.read,
    required this.write,
    required super.child,
  });

  /// The value kept as [name], or null.
  final Object? Function(String name) read;

  /// Keeps [value] as [name].
  final void Function(String name, Object? value) write;

  static UiMemory? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UiMemory>();

  /// The value kept as [name] when it is a [T].
  static T? recall<T>(BuildContext context, String name) {
    final value = maybeOf(context)?.read(name);
    if (T == double && value is num) return value.toDouble() as T;
    return value is T ? value : null;
  }

  static void keep(BuildContext context, String name, Object? value) =>
      maybeOf(context)?.write(name, value);

  @override
  bool updateShouldNotify(UiMemory old) => false;
}

/// A [UiMemory] on a map, for tests and previews.
class MapUiMemory extends StatelessWidget {
  const MapUiMemory({super.key, required this.values, required this.child});

  final Map<String, Object?> values;
  final Widget child;

  @override
  Widget build(BuildContext context) => UiMemory(
    read: (name) => values[name],
    write: (name, value) => values[name] = value,
    child: child,
  );
}
