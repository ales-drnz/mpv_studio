import 'package:flutter/foundation.dart';

/// The width and height thresholds of the responsive layout, in logical
/// pixels. Pages never hardcode a width: they ask `context.layout` for the
/// window class, or compare an available width against these names.
abstract final class Breakpoints {
  /// Phones in portrait are below this ([WidthClass.compact]).
  static const double medium = 600;

  /// Small tablets and narrow windows are below this ([WidthClass.medium]).
  static const double expanded = 840;

  /// Large tablets and laptop windows are below this.
  static const double large = 1200;

  /// Desktop windows are below this; ultrawide screens are at or above it.
  static const double xlarge = 1600;

  /// A window lower than this is [HeightClass.short] (phones in landscape).
  static const double short = 500;

  /// An available page width (the space the shell leaves the page, not
  /// the window) from which a page puts two full columns side by side.
  /// Pages compare their own `LayoutBuilder` width against it, so the
  /// layout does not move when the sidebar opens or collapses.
  static const double splitContent = 1080;

  /// The default maximum width of a page's readable content, centred on
  /// wider windows.
  static const double readable = 960;

  /// The maximum width of dense content such as tables and racks.
  static const double wide = 1400;
}

/// The window width, in five classes.
enum WidthClass {
  /// Below 600: phones in portrait.
  compact,

  /// 600 to 839: small tablets, narrow desktop windows.
  medium,

  /// 840 to 1199: tablets in landscape, laptop windows.
  expanded,

  /// 1200 to 1599: desktop windows.
  large,

  /// 1600 and up: big and ultrawide screens.
  xlarge;

  /// The class of a window (or an available area) [width] wide.
  static WidthClass of(double width) {
    if (width < Breakpoints.medium) return compact;
    if (width < Breakpoints.expanded) return medium;
    if (width < Breakpoints.large) return expanded;
    if (width < Breakpoints.xlarge) return large;
    return xlarge;
  }

  /// Whether this class is [other] or wider.
  bool atLeast(WidthClass other) => index >= other.index;

  /// Whether this class is narrower than [other].
  bool below(WidthClass other) => index < other.index;
}

/// The window height, in two classes.
enum HeightClass {
  /// Below 500: phones in landscape. Chrome gets out of the way.
  short,

  /// 500 and up.
  regular;

  /// The class of a window [height] tall.
  static HeightClass of(double height) =>
      height < Breakpoints.short ? short : regular;
}

/// How the user points: fingers or a mouse. Drives tap target sizes,
/// density, hover affordances, and whether menus open as context menus or
/// bottom sheets.
enum InputMode {
  /// Fingers: 48 dp targets, bottom sheets, long press.
  touch,

  /// Mouse and trackpad: denser controls, hover, right-click menus,
  /// keyboard shortcuts.
  pointer;

  /// The platform's mode: touch on Android and iOS, pointer on desktop.
  /// Any build can force one with `--dart-define=STUDIO_INPUT=touch`
  /// (or `pointer`).
  static InputMode get platformDefault {
    const forced = String.fromEnvironment('STUDIO_INPUT');
    if (forced == 'touch') return touch;
    if (forced == 'pointer') return pointer;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => touch,
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => pointer,
    };
  }
}
