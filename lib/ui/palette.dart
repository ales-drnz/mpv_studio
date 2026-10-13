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

  // ---- Accent (white in dark, graphite in light) --------------------

  /// The single accent: the selected destination, the play circle,
  /// progress, active tracks, switches on, focus.
  final Color accent;

  /// The secondary tone (the ring grey): unplayed and buffered ranges,
  /// secondary marks.
  final Color accentDim;

  /// Content drawn on a solid [accent] fill.
  final Color onAccent;

  /// A translucent accent for active fills.
  final Color accentWash;

  /// The secondary selection fill (the ring grey): a selected chip, the
  /// current queue row, the selected stage.
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

  /// The default theme, in the logo's own colours: graphite #24282D (the
  /// disc) as the stage, darker and lighter steps of its hue (HCT 250,
  /// chroma 7) for the chrome and the cards, the ring grey #BFBFBF for
  /// secondary emphasis and white as the one accent.
  static const Palette dark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF24282D), // T16, the logo disc: the stage
    surface: Color(0xFF31353A), // T22, cards and rows
    surface2: Color(0xFF181C21), // T10, chrome, sheets, dialogs
    surface3: Color(0xFF3A3E43), // T26, fields, tonal circles
    surface4: Color(0xFF484C51), // T32, inactive tracks
    line: Color(0x14FFFFFF), // ~8% white, inside data views only
    line2: Color(0x26FFFFFF), // ~15% white
    fg: Color(0xFFF1F4FA), // T96, 13.5:1 on bg, 11.2:1 on cards
    fgDim: Color(0xFFBFBFBF), // the ring grey, 8.1:1 on bg, 6.7:1 on cards
    fgFaint: Color(0xFFA8ABB2), // T70, 6.5:1 on bg, 4.7:1 on fields
    accent: Color(0xFFFFFFFF), // white: selection, play, progress
    accentDim: Color(0xFFBFBFBF), // the ring grey: secondary marks
    onAccent: Color(0xFF24282D), // graphite on white, 14.8:1
    accentWash: Color(0x1FFFFFFF), // ~12% white: hover
    accentContainer: Color(0xFFBFBFBF), // the ring grey: secondary selection
    onAccentContainer: Color(0xFF24282D), // 8.1:1
    tonal: Color(0xFF43474C), // T30, secondary buttons
    onTonal: Color(0xFFF1F4FA), // 8.5:1
    green: Color(0xFF68DCA2), // 8.7:1 on bg
    amber: Color(0xFFE7C268), // 8.7:1 on bg
    red: Color(0xFFFF8985), // 6.5:1 on bg, 5.4:1 on cards
  );

  /// The mirror of [dark]: white and near-white steps of the same hue,
  /// graphite #24282D as the accent wherever dark has white, the ring
  /// grey as the secondary selection. The stage sits a step below the
  /// white cards so they read clearly.
  static const Palette light = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFEBEEF5), // T94, the stage
    surface: Color(0xFFFFFFFF), // white cards and rows
    surface2: Color(0xFFE0E2E9), // T90, chrome, sheets, dialogs
    surface3: Color(0xFFE5E8EF), // T92, fields, tonal circles
    surface4: Color(0xFFB6B9BF), // T75, a ring grey step: tracks, 2:1 on white
    line: Color(0x14000000), // ~8% black, inside data views only
    line2: Color(0x29000000), // ~16% black
    fg: Color(0xFF24282D), // graphite, 12.8:1 on bg, 14.8:1 on cards
    fgDim: Color(0xFF43474C), // T30, 8.1:1 on bg
    fgFaint: Color(0xFF5B5F64), // T40, 5.5:1 on bg, 5.0:1 on chrome
    accent: Color(0xFF24282D), // graphite: selection, play, progress
    // The ring grey is too light on white (1.8:1); its T60 step keeps
    // secondary marks (unplayed waveform) at 3.2:1 on white.
    accentDim: Color(0xFF8D9197),
    onAccent: Color(0xFFFFFFFF), // white on graphite, 14.8:1
    accentWash: Color(0x1A24282D), // ~10% graphite: hover
    accentContainer: Color(0xFFBFBFBF), // the ring grey: secondary selection
    onAccentContainer: Color(0xFF24282D), // 8.1:1
    tonal: Color(0xFFD7DAE1), // T87, secondary buttons
    onTonal: Color(0xFF24282D), // 10.6:1
    green: Color(0xFF006C46), // 5.6:1 on bg
    amber: Color(0xFF765A04), // 5.6:1 on bg
    red: Color(0xFFAE2F34), // 5.6:1 on bg
  );

  // ---- The logo (fixed, the same in both themes) --------------------

  /// The logo disc, also [dark]'s stage.
  static const Color logoGraphite = Color(0xFF24282D);

  /// The logo ring.
  static const Color logoRing = Color(0xFFBFBFBF);

  /// The logo's play triangle.
  static const Color logoWhite = Color(0xFFFFFFFF);

  static Palette _active = dark;

  /// The colour set the app is drawn with right now.
  static Palette get active => _active;

  /// Makes [palette] the [active] one. The theme host calls this and then
  /// rebuilds the tree; tests call it through the golden harness. On its
  /// own it does not repaint anything.
  static void activate(Palette palette) => _active = palette;
}
