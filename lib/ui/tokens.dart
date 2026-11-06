import 'package:flutter/widgets.dart';

import 'palette.dart';

export 'palette.dart';

/// Design tokens for MPV Studio, direction "Expressive tonal".
///
/// No shadows (but the [lift] of an item being dragged), no glows, no
/// gradients, and almost no hairlines: hierarchy is carried by tonal
/// surface containers (`surface` to `surface4`),
/// shape and spacing. Every corner is a circular arc; interactive
/// controls are pills or full circles. The single accent is used for the
/// primary action, progress and the selected state.
class Tokens {
  Tokens._();

  // ---- Colours, from the active [Palette] ---------------------------
  // Getters, not constants: they follow the theme. Never use them in a
  // `const` expression or cache them in a `static final`.

  /// The colour set in use; prefer the named members below.
  static Palette get palette => Palette.active;

  // Surfaces (layered by lightness).
  static Color get bg => Palette.active.bg;
  static Color get surface => Palette.active.surface;
  static Color get surface2 => Palette.active.surface2;
  static Color get surface3 => Palette.active.surface3;
  static Color get surface4 => Palette.active.surface4;

  /// A card inside a sheet or a dialog.
  static Color get cardOnChrome => Palette.active.cardOnChrome;

  /// A readout panel set into a card (meters, a gauge's track).
  static Color get inset => Palette.active.inset;

  // Hairlines (flat borders, never shadows).
  static Color get line => Palette.active.line;
  static Color get line2 => Palette.active.line2;

  /// A reference line inside a chart (0 dB, unity), 3:1 on the card.
  static Color get lineRef => Palette.active.lineRef;

  /// The inactive part of a track (slider, switch off, a dot that reads
  /// "no"), 3:1 on the card.
  static Color get trackOff => Palette.active.trackOff;

  // Text.
  static Color get fg => Palette.active.fg;
  static Color get fgDim => Palette.active.fgDim;
  static Color get fgFaint => Palette.active.fgFaint;

  // Accent: white in dark, graphite in light.
  static Color get accent => Palette.active.accent;
  static Color get accentDim => Palette.active.accentDim;
  static Color get onAccent => Palette.active.onAccent;
  static Color get accentWash => Palette.active.accentWash;
  static Color get accentContainer => Palette.active.accentContainer;
  static Color get onAccentContainer => Palette.active.onAccentContainer;
  static Color get tonal => Palette.active.tonal;
  static Color get onTonal => Palette.active.onTonal;

  // Semantic.

  /// The opacity of a semantic colour filling a background (an error
  /// notice, an error badge), so text and icon on it keep their contrast.
  static const double semanticWash = 0.14;

  static Color get green => Palette.active.green;
  static Color get amber => Palette.active.amber;
  static Color get red => Palette.active.red;

  /// The one placeholder of a value that is not there (no reading yet,
  /// nothing decoding): an em dash, the same in every table and readout.
  static const String noValue = '\u2014';

  // ---- Shape ------------------------------------------------------
  // Circular arcs only. Small marks 8, inner tiles 12, rows and inset
  // panels 16, cards 24, sheets, dialogs and the hero cover 32; anything
  // interactive and single line is a pill (height / 2) or a circle.
  static const double rXs = 8;
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 24;
  static const double rXl = 32;
  static const double rPill = 999;

  /// A circular-arc rounded rectangle of radius [r] (a pill from
  /// [rPill]). The one shape helper of the app: no squircles.
  static ShapeBorder shape(double r, {BorderSide side = BorderSide.none}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r),
        side: side,
      );

  /// The one shadow of the app: an item lifted by a drag, [t] of the way
  /// up (0 at rest, 1 held). Soft and close, deeper in dark.
  static List<BoxShadow> lift(double t) {
    final dark = Palette.active.isDark;
    return [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, (dark ? 0.34 : 0.16) * t),
        blurRadius: 24 * t,
        offset: Offset(0, 8 * t),
      ),
    ];
  }

  /// The pill of a single line control: radius half its height.
  static const ShapeBorder pill = StadiumBorder();

  /// The height of a thin bar: progress, the mini player's seek line.
  static const double progressH = 4;

  /// The stroke of every circular progress indicator.
  static const double strokeProgress = 2;

  /// The leading circle of a row ([LeadTile]) on pointer; touch uses the
  /// tap target.
  static const double leadSize = 40;

  // ---- Icons ------------------------------------------------------
  // Four sizes. Buttons with a label take theirs from the theme (18).

  /// Marks inside a line of text: origin, status, a chevron.
  static const double iconSm = 16;

  /// Actions and modes: icon buttons, row trailing actions.
  static const double iconMd = 20;

  /// Navigation and primary icons.
  static const double iconLg = 24;

  /// The transport: skip and seek around the play button.
  static const double iconXl = 28;

  // ---- Motion -----------------------------------------------------
  // Three durations. Pass them through [motion], which drops them to zero
  // when the platform asks for reduced motion.

  /// Small state changes: a pill, a badge, a fade.
  static const Duration motionShort = Duration(milliseconds: 160);

  /// Moves within a component: an indicator sliding, a zoom.
  static const Duration motionMedium = Duration(milliseconds: 220);

  /// Layout moves: the sidebar opening, a section change.
  static const Duration motionLong = Duration(milliseconds: 240);

  /// [duration], or zero when the platform asks for reduced motion
  /// (`MediaQuery.disableAnimations`).
  static Duration motion(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : duration;

  /// Height of a field-like control with a pointer (search and text
  /// fields, segmented pills, dropdowns): 40, on the 8 grid. Touch uses
  /// the 48 target.
  static const double controlH = 40;

  // ---- Spacing ----------------------------------------------------
  // The 4 and 8 grid, and nothing off it.
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  // ---- Type -------------------------------------------------------
  // Roboto named explicitly (the goldens render real glyphs). Titles are
  // larger and bolder than body text by a clear step: 28 bold page
  // titles, 22 secondary titles, 16 semibold headings, 14 body, 12
  // labels. Figures and logs are in the bundled Roboto Mono.
  static const String sans = 'Roboto';
  static const String mono = 'Roboto Mono';

  static TextStyle get display => TextStyle(
    fontFamily: sans,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    color: fg,
    letterSpacing: -0.6,
  );
  static TextStyle get title => TextStyle(
    fontFamily: sans,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    color: fg,
    letterSpacing: -0.5,
  );

  /// A secondary title: an album, an empty state, a page title in a
  /// short window.
  static TextStyle get titleSm => TextStyle(
    fontFamily: sans,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    color: fg,
    letterSpacing: -0.2,
  );
  static TextStyle get heading => TextStyle(
    fontFamily: sans,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    color: fg,
  );
  static TextStyle get body => TextStyle(
    fontFamily: sans,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: fg,
  );
  static TextStyle get label => TextStyle(
    fontFamily: sans,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: fgDim,
    letterSpacing: 0.1,
  );

  /// A short label that heads or picks (a section header, a segment):
  /// [label] a step larger and bolder.
  static TextStyle get labelLg => TextStyle(
    fontFamily: sans,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w600,
    color: fgDim,
    letterSpacing: 0.1,
  );
  static TextStyle get caption => TextStyle(
    fontFamily: sans,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w500,
    color: fgFaint,
    letterSpacing: 0.4,
  );
  static TextStyle get numeric => TextStyle(
    fontFamily: mono,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: fgDim,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// A readout that is the point of its cell (Engine, the console's
  /// suggestions): [numeric] at body size.
  static TextStyle get numericLg => TextStyle(
    fontFamily: mono,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: fg,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// The size of the labels painted inside charts (axes, rulers, meters),
  /// before the text scale; see `paintChartLabel`.
  static const double chartLabelSize = 10;

  /// The largest text scale painted chart labels follow: past it they
  /// would crowd the plot they label.
  static const double chartLabelMaxScale = 1.5;
}
