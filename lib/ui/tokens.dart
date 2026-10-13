import 'package:flutter/widgets.dart';

import 'palette.dart';

export 'palette.dart';

/// Design tokens for MPV Studio, direction "Expressive tonal".
///
/// No shadows, no glows, no gradients, and almost no hairlines: hierarchy
/// is carried by tonal surface containers (`surface` to `surface4`),
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

  // Hairlines (flat borders, never shadows).
  static Color get line => Palette.active.line;
  static Color get line2 => Palette.active.line2;

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
  static Color get green => Palette.active.green;
  static Color get amber => Palette.active.amber;
  static Color get red => Palette.active.red;

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

  /// The pill of a single line control: radius half its height.
  static const ShapeBorder pill = StadiumBorder();

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
  // larger and bolder than body text by a clear step: 28/24 bold page
  // titles, 16 semibold headings, 14 body, 12 labels.
  static const String sans = 'Roboto';
  static const String mono = 'monospace';

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
}
