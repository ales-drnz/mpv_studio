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
    required this.surface4,
    required this.line,
    required this.line2,
    required this.fg,
    required this.fgDim,
    required this.fgFaint,
    required this.accent,
    required this.accentDim,
    required this.onAccent,
    required this.accentWash,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.tonal,
    required this.onTonal,
    required this.green,
    required this.amber,
    required this.red,
  });

  /// Whether this is a dark or a light colour set.
  final Brightness brightness;

  // ---- Tonal surfaces (Material 3 surface containers) ---------------

  /// The page background: the stage the sections are drawn on.
  final Color bg;

  /// Cards and list rows on the page.
  final Color surface;

  /// The shell chrome (sidebar, rail, bars), sheets and dialogs.
  final Color surface2;

  /// Fields, segmented tracks, tonal circles, placeholders.
  final Color surface3;

  /// The highest tone: inactive slider and switch tracks, the phone
  /// mini-player card's cover.
  final Color surface4;

  // ---- Hairlines (only inside data views: rulers, grids) ------------

  /// The faint divider.
  final Color line;

  /// The stronger divider.
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

  /// A solid, quieter accent fill: the selected state of a chip or a
  /// segment, the open stage, the current queue row.
  final Color accentContainer;

  /// Content drawn on [accentContainer].
  final Color onAccentContainer;

  /// The low chroma fill of secondary buttons (tonal pills, tile
  /// buttons, rack toolbar), Material's secondary container.
  final Color tonal;

  /// Content drawn on [tonal].
  final Color onTonal;

  // ---- Semantic -----------------------------------------------------

  /// Success, good levels.
  final Color green;

  /// Warnings, bypass.
  final Color amber;

  /// Errors, clipping.
  final Color red;

  /// Whether this is the [dark] colour set.
  bool get isDark => brightness == Brightness.dark;

  /// The graphite studio look, the default theme. Tonal roles of the
  /// seed #2FA8F0 (HCT hue 244) over a graphite neutral (hue 250, chroma
  /// 5, the logo's own grey).
  static const Palette dark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF111417), // N6, surface
    surface: Color(0xFF191C1F), // N10, container low
    surface2: Color(0xFF1D2023), // N12, container
    surface3: Color(0xFF282A2E), // N17, container high
    surface4: Color(0xFF323539), // N22, container highest
    line: Color(0x14FFFFFF), // ~8% white, rare dividers
    line2: Color(0x26FFFFFF), // ~15% white, inactive tracks
    fg: Color(0xFFE1E2E7), // N90, 14.3:1 on bg
    fgDim: Color(0xFFC1C7D0), // NV80, 10.9:1
    fgFaint: Color(0xFF8B919A), // NV60, 5.8:1
    accent: Color(0xFF8FCDFF), // P80, 10.9:1
    accentDim: Color(0xFF007EBA), // P50
    onAccent: Color(0xFF003450), // P20, 7.7:1 on accent
    accentWash: Color(0x248FCDFF), // ~14%
    accentContainer: Color(0xFF004B71), // P30
    onAccentContainer: Color(0xFFCBE6FF), // P90, 7.3:1
    tonal: Color(0xFF364959), // S30
    onTonal: Color(0xFFD1E5F9), // S90, 7.2:1
    green: Color(0xFF68DCA2),
    amber: Color(0xFFE7C268),
    red: Color(0xFFFF8985),
  );

  /// The light counterpart: the same roles at light tones. The page sits
  /// one step down (N94) so cards, in white, stand out clearly on it, and
  /// the chrome is one step further down (N90).
  static const Palette light = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFEDEEF2), // N94, the stage
    surface: Color(0xFFFFFFFF), // N100, cards
    surface2: Color(0xFFE1E2E7), // N90, chrome, sheets
    surface3: Color(0xFFE7E8EC), // N92, fields, tonal circles
    surface4: Color(0xFFD9DADE), // N87, tracks
    line: Color(0x14000000), // ~8% black
    line2: Color(0x29000000), // ~16% black
    fg: Color(0xFF191C1F), // N10, 14.8:1 on bg
    fgDim: Color(0xFF41474F), // NV30, 8.1:1
    fgFaint: Color(0xFF595F67), // NV40, 5.6:1 (5.0:1 on chrome)
    accent: Color(0xFF006495), // P40, 5.6:1
    accentDim: Color(0xFF8FCDFF), // P80
    onAccent: Color(0xFFFFFFFF), // 6.4:1 on accent
    accentWash: Color(0x1F006495), // ~12%
    accentContainer: Color(0xFFCBE6FF), // P90
    onAccentContainer: Color(0xFF001E30), // P10, 13.3:1
    tonal: Color(0xFFD1E5F9), // S90
    onTonal: Color(0xFF091D2C), // S10, 13.3:1
    green: Color(0xFF006C46),
    amber: Color(0xFF765A05),
    red: Color(0xFFAD3134),
  );

  static Palette _active = dark;

  /// The colour set the app is drawn with right now.
  static Palette get active => _active;

  /// Makes [palette] the [active] one. The theme host calls this and then
  /// rebuilds the tree; tests call it through the golden harness. On its
  /// own it does not repaint anything.
  static void activate(Palette palette) => _active = palette;
}
