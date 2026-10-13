import 'package:flutter/widgets.dart';

import 'palette.dart';

export 'palette.dart';

/// Flat design tokens for MPV Studio.
///
/// Deliberately flat: no shadows, no glows, no gradients. Hierarchy is
/// carried by surface colour and spacing alone. The single accent
/// (`accent`) is used sparingly — transport, progress, active state.
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

  // Hairlines (flat borders, never shadows).
  static Color get line => Palette.active.line;
  static Color get line2 => Palette.active.line2;

  // Text.
  static Color get fg => Palette.active.fg;
  static Color get fgDim => Palette.active.fgDim;
  static Color get fgFaint => Palette.active.fgFaint;

  // Accent (the one blue).
  static Color get accent => Palette.active.accent;
  static Color get accentDim => Palette.active.accentDim;
  static Color get onAccent => Palette.active.onAccent;
  static Color get accentWash => Palette.active.accentWash;

  // Semantic.
  static Color get green => Palette.active.green;
  static Color get amber => Palette.active.amber;
  static Color get red => Palette.active.red;

  // ---- Radius -----------------------------------------------------
  static const double rSm = 8;
  static const double rMd = 12;
  static const double rLg = 16;
  static const double rPill = 999;

  /// Squircle (superellipse) corner of visual radius [r]. Used app-wide so
  /// every rounded surface shares the same continuous-curvature corner
  /// instead of a plain circular arc. The 1.5× keeps the visual roundness
  /// close to the old circular radii while reading as a squircle.
  static ShapeBorder squircle(double r, {BorderSide side = BorderSide.none}) =>
      ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(r * 1.5),
        side: side,
      );

  /// Shared height for every interactive control app-wide — search/text
  /// fields, segmented controls, dropdowns — so they line up exactly on a
  /// row and read uniformly across pages. Matches the segmented control's
  /// natural height.
  static const double controlH = 38;

  // ---- Spacing ----------------------------------------------------
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  // ---- Type -------------------------------------------------------
  // Getters for the same reason as the colours: they carry one.
  static const String mono = 'monospace';

  static TextStyle get title => TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    color: fg,
    letterSpacing: -0.2,
  );
  static TextStyle get heading =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg);
  static TextStyle get body =>
      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400, color: fg);
  static TextStyle get label =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fgDim);
  static TextStyle get caption =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: fgFaint);
  static TextStyle get numeric => TextStyle(
    fontFamily: mono,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: fgDim,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  // ---- Breakpoint -------------------------------------------------
  /// Below this width the app uses the mobile shell (tab bar + sheets);
  /// at or above it uses the desktop shell (sidebar + dock).
  static const double desktopBreakpoint = 720;
}
