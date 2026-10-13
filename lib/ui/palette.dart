import 'package:flutter/widgets.dart';

/// The app's colour set: one instance per theme ([dark], [light]).
///
/// Widgets never read a [Palette] directly: they use the colour members of
/// `Tokens` (`Tokens.fg`, `Tokens.accent`...), which forward to [active].
/// The theme host (`StudioThemeHost`) switches [active] and rebuilds and
/// repaints the whole tree, so every page, painter and text style follows
/// a theme change without a restart and without losing state.
///
/// Because the colours are read at build or paint time, they cannot appear
/// inside `const` expressions, and must not be cached in `static final`
/// fields or in long-lived state: read `Tokens.x` where the colour is used.
@immutable
class Palette {
  const Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.line2,
    required this.fg,
    required this.fgDim,
    required this.fgFaint,
    required this.accent,
    required this.accentDim,
    required this.onAccent,
    required this.accentWash,
    required this.green,
    required this.amber,
    required this.red,
  });

  /// Whether this is a dark or a light colour set.
  final Brightness brightness;

  // ---- Surfaces, layered by lightness -------------------------------

  /// The page background.
  final Color bg;

  /// Cards, sidebar, bars.
  final Color surface;

  /// Inset fields and controls on a [surface].
  final Color surface2;

  /// Raised bits: tooltips, toasts, thumbs.
  final Color surface3;

  // ---- Hairlines (flat borders, never shadows) ----------------------

  /// The faint divider.
  final Color line;

  /// The stronger divider, inactive tracks and outlines.
  final Color line2;

  // ---- Text ---------------------------------------------------------

  /// Primary text and icons.
  final Color fg;

  /// Secondary text and icons.
  final Color fgDim;

  /// Captions, hints and disabled content.
  final Color fgFaint;

  // ---- Accent (the one blue) ----------------------------------------

  /// The single accent: transport, progress, active state.
  final Color accent;

  /// A quieter accent (secondary tracks, buffered ranges).
  final Color accentDim;

  /// Content drawn on a solid [accent] fill.
  final Color onAccent;

  /// A translucent accent for active fills.
  final Color accentWash;

  // ---- Semantic -----------------------------------------------------

  /// Success, good levels.
  final Color green;

  /// Warnings, bypass.
  final Color amber;

  /// Errors, clipping.
  final Color red;

  /// Whether this is the [dark] colour set.
  bool get isDark => brightness == Brightness.dark;

  /// The near-black studio look, the default theme.
  static const Palette dark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF0E0F11),
    surface: Color(0xFF16181B),
    surface2: Color(0xFF1C1F23),
    surface3: Color(0xFF24282D),
    line: Color(0x12FFFFFF), // ~7% white
    line2: Color(0x1FFFFFFF), // ~12% white
    fg: Color(0xFFE6E8EA),
    fgDim: Color(0xFF8A9097),
    fgFaint: Color(0xFF565C63),
    accent: Color(0xFF91D8F9),
    accentDim: Color(0xFF4E8BAA),
    onAccent: Color(0xFF08151C),
    accentWash: Color(0x2291D8F9), // ~13% for active fills
    green: Color(0xFF5FD39A),
    amber: Color(0xFFE9C46A),
    red: Color(0xFFE55A5A),
  );

  /// The light counterpart: cool grey surfaces, near-black text and a
  /// deeper blue accent that keeps its contrast on white.
  static const Palette light = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFF2F4F6),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEBEEF1),
    surface3: Color(0xFFDDE1E6),
    line: Color(0x14000000), // ~8% black
    line2: Color(0x26000000), // ~15% black
    fg: Color(0xFF15181C),
    fgDim: Color(0xFF555D66),
    fgFaint: Color(0xFF8A929B),
    accent: Color(0xFF1A78A8),
    accentDim: Color(0xFF8CC2DE),
    onAccent: Color(0xFFFFFFFF),
    accentWash: Color(0x241A78A8), // ~14% for active fills
    green: Color(0xFF16915A),
    amber: Color(0xFFB07D0A),
    red: Color(0xFFCC3535),
  );

  static Palette _active = dark;

  /// The colour set the app is drawn with right now.
  static Palette get active => _active;

  /// Makes [palette] the [active] one. The theme host calls this and then
  /// rebuilds the tree; tests call it through the golden harness. On its
  /// own it does not repaint anything.
  static void activate(Palette palette) => _active = palette;
}
