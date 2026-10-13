import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'window_class.dart';

/// How the shell navigates between sections at a given [StudioLayout].
enum ShellNavigation {
  /// A bottom tab bar with a More sheet (phones in portrait).
  bottomBar,

  /// A slim icon rail on the left (narrow windows, phones in landscape).
  rail,

  /// The full text sidebar (tablets in landscape and desktop).
  sidebar,
}

/// The window classes and input mode the app is laid out for. Read it
/// with `context.layout`.
///
/// It only changes when a class changes, not on every pixel of a window
/// resize, so depending on it is cheap. For the exact size use
/// `MediaQuery.sizeOf`, and for the space a widget actually has use a
/// [LayoutBuilder] with [WidthClass.of].
@immutable
class StudioLayout {
  const StudioLayout({
    required this.width,
    required this.height,
    required this.input,
  });

  /// The layout of a window of [size], with [input] defaulting to
  /// [InputMode.platformDefault].
  factory StudioLayout.of(Size size, {InputMode? input}) => StudioLayout(
    width: WidthClass.of(size.width),
    height: HeightClass.of(size.height),
    input: input ?? InputMode.platformDefault,
  );

  final WidthClass width;
  final HeightClass height;
  final InputMode input;

  bool get isTouch => input == InputMode.touch;
  bool get isPointer => input == InputMode.pointer;

  /// A phone-wide window.
  bool get isCompact => width == WidthClass.compact;

  /// A low window (a phone in landscape).
  bool get isShort => height == HeightClass.short;

  /// The shell's navigation: bottom bar on compact, a rail on medium and
  /// on any short window, the sidebar from expanded up.
  ShellNavigation get navigation {
    if (isShort) return ShellNavigation.rail;
    if (isCompact) return ShellNavigation.bottomBar;
    if (width == WidthClass.medium) return ShellNavigation.rail;
    return ShellNavigation.sidebar;
  }

  /// The smallest side of anything tappable: 48 on touch, 40 with a
  /// pointer ([InputMode.minTap]).
  double get minTap => input.minTap;

  /// The page's side margin.
  double get gutter => switch (width) {
    WidthClass.compact => Tokens.s16,
    WidthClass.medium => Tokens.s24,
    WidthClass.expanded => Tokens.s24,
    WidthClass.large || WidthClass.xlarge => Tokens.s32,
  };

  /// The gap between cards in a grid or a two-pane split.
  double get gap => isCompact ? Tokens.s12 : Tokens.s16;

  /// The standard padding of a page body: [gutter] at the sides, a short
  /// top and a longer bottom so the last item clears the edge.
  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(
    gutter,
    Tokens.s8,
    gutter,
    isShort ? Tokens.s16 : Tokens.s32,
  );

  /// Whether menus and pickers open as bottom sheets instead of popups:
  /// on touch, and on any compact window.
  bool get prefersSheets => isTouch || isCompact;

  @override
  bool operator ==(Object other) =>
      other is StudioLayout &&
      other.width == width &&
      other.height == height &&
      other.input == input;

  @override
  int get hashCode => Object.hash(width, height, input);

  @override
  String toString() =>
      'StudioLayout(${width.name}, ${height.name}, '
      '${input.name})';
}

/// Computes the [StudioLayout] from the enclosing [MediaQuery] and hands
/// it down. The app installs one above its navigator, so pages, dialogs
/// and sheets all see it; tests install one to force an [inputMode].
class LayoutScope extends StatelessWidget {
  const LayoutScope({super.key, this.inputMode, required this.child});

  /// Forces the input mode; null follows [InputMode.platformDefault].
  final InputMode? inputMode;

  final Widget child;

  /// The nearest layout. Without a [LayoutScope] above, it is derived from
  /// the [MediaQuery] (or a desktop window when there is none), so widgets
  /// pumped on their own in tests still lay out.
  static StudioLayout of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_LayoutData>();
    if (scope != null) return scope.layout;
    final size = MediaQuery.maybeSizeOf(context) ?? const Size(1280, 800);
    return StudioLayout.of(size);
  }

  @override
  Widget build(BuildContext context) {
    final layout = StudioLayout.of(
      MediaQuery.sizeOf(context),
      input: inputMode,
    );
    return _LayoutData(layout: layout, child: child);
  }
}

class _LayoutData extends InheritedWidget {
  const _LayoutData({required this.layout, required super.child});

  final StudioLayout layout;

  @override
  bool updateShouldNotify(_LayoutData old) => old.layout != layout;
}

/// `context.layout`: the [StudioLayout] in effect here.
extension StudioLayoutContext on BuildContext {
  StudioLayout get layout => LayoutScope.of(this);
}
