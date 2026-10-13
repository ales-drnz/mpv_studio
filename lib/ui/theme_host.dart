import 'package:flutter/material.dart';

import 'palette.dart';

/// The user's theme choice: dark (the default), light, or following the
/// system. Read it, or change it, with [ThemeController.of].
///
/// ```dart
/// ThemeController.of(context).mode = ThemeMode.light;
/// ```
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initial = ThemeMode.dark, this.onChanged})
    : _mode = initial;

  /// Called with each new mode, to persist it.
  final ValueChanged<ThemeMode>? onChanged;

  ThemeMode _mode;

  /// The chosen mode.
  ThemeMode get mode => _mode;
  set mode(ThemeMode value) {
    if (value == _mode) return;
    _mode = value;
    onChanged?.call(value);
    notifyListeners();
  }

  /// Steps dark, light, system and back to dark.
  void cycle() => mode = switch (_mode) {
    ThemeMode.dark => ThemeMode.light,
    ThemeMode.light => ThemeMode.system,
    ThemeMode.system => ThemeMode.dark,
  };

  /// The palette [mode] stands for when the system is [platform].
  Palette resolve(Brightness platform) => switch (_mode) {
    ThemeMode.dark => Palette.dark,
    ThemeMode.light => Palette.light,
    ThemeMode.system =>
      platform == Brightness.light ? Palette.light : Palette.dark,
  };

  /// A short name of [mode] for labels and tooltips.
  String get label => switch (_mode) {
    ThemeMode.dark => 'Dark',
    ThemeMode.light => 'Light',
    ThemeMode.system => 'System',
  };

  /// The icon of [mode].
  IconData get icon => switch (_mode) {
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };

  /// The controller of the nearest [StudioThemeHost].
  static ThemeController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No StudioThemeHost above this context');
    return controller!;
  }

  /// [of], or null without a [StudioThemeHost] (widgets pumped alone).
  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ThemeScope>()?.notifier;
}

/// Applies the [ThemeController]'s palette to the whole app.
///
/// It activates the resolved [Palette] (so `Tokens` colours follow it),
/// hands it to [builder] to make the `ThemeData`, and on every change
/// (the user's choice, or the system brightness in system mode) marks the
/// entire subtree for rebuild and repaint. State, scroll offsets and
/// navigation stacks are kept: nothing is recreated, only rebuilt.
class StudioThemeHost extends StatefulWidget {
  const StudioThemeHost({
    super.key,
    required this.controller,
    required this.builder,
  });

  final ThemeController controller;

  /// Builds the app (usually a `MaterialApp`) for the active palette.
  final Widget Function(BuildContext context, Palette palette) builder;

  @override
  State<StudioThemeHost> createState() => _StudioThemeHostState();
}

class _StudioThemeHostState extends State<StudioThemeHost>
    with WidgetsBindingObserver {
  Brightness get _platform =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    Palette.activate(widget.controller.resolve(_platform));
    widget.controller.addListener(_apply);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(StudioThemeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_apply);
      widget.controller.addListener(_apply);
      _apply();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_apply);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _apply();

  void _apply() {
    final palette = widget.controller.resolve(_platform);
    if (palette == Palette.active || !mounted) return;
    Palette.activate(palette);
    setState(() {});
    // Tokens colours are read at build and paint time without registering
    // a dependency, so every element is rebuilt and every render object
    // repainted (a painter may compare equal and skip its own repaint).
    void refresh(Element element) {
      element.markNeedsBuild();
      if (element is RenderObjectElement) {
        element.renderObject.markNeedsPaint();
      }
      element.visitChildren(refresh);
    }

    (context as Element).visitChildren(refresh);
  }

  @override
  Widget build(BuildContext context) => _ThemeScope(
    notifier: widget.controller,
    child: Builder(
      builder: (context) => widget.builder(context, Palette.active),
    ),
  );
}

class _ThemeScope extends InheritedNotifier<ThemeController> {
  const _ThemeScope({required super.notifier, required super.child});
}
