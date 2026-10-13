import 'package:flutter/material.dart';

import 'layout/window_class.dart';
import 'tokens.dart';

/// The flat Material theme, built from a [Palette]. Material widgets are
/// reconfigured so nothing emits elevation, splash glows or overlays: the
/// look is uniformly flat in both the dark and the light palette.
class AppTheme {
  AppTheme._();

  /// The dark theme for pointer input.
  static ThemeData get dark => of(Palette.dark);

  /// The light theme for pointer input.
  static ThemeData get light => of(Palette.light);

  /// The theme for [palette]. [input] sets the density: roomy 48 dp tap
  /// targets on touch, compact controls on pointer.
  static ThemeData of(Palette palette, {InputMode input = InputMode.pointer}) {
    final p = palette;
    final touch = input == InputMode.touch;
    final scheme = p.isDark
        ? ColorScheme.dark(
            surface: p.bg,
            primary: p.accent,
            onPrimary: p.onAccent,
            secondary: p.accent,
            error: p.red,
            onSurface: p.fg,
          )
        : ColorScheme.light(
            surface: p.bg,
            primary: p.accent,
            onPrimary: p.onAccent,
            secondary: p.accent,
            error: p.red,
            onSurface: p.fg,
          );
    TextStyle text(double size, FontWeight weight, Color color) =>
        TextStyle(fontSize: size, fontWeight: weight, color: color);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      visualDensity: touch ? VisualDensity.standard : VisualDensity.compact,
      materialTapTargetSize: touch
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
      // Flat: kill ripple and highlight glows everywhere.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      // App-wide hover: a faint accent wash so every InkWell-backed element
      // (sidebar, settings and effects grids, lists, tiles) lights up under
      // the pointer.
      hoverColor: p.accent.withValues(alpha: 0.10),
      dividerColor: p.line,
      textTheme: TextTheme(
        titleLarge: text(
          21,
          FontWeight.w600,
          p.fg,
        ).copyWith(letterSpacing: -0.2),
        titleMedium: text(15, FontWeight.w600, p.fg),
        bodyMedium: text(13.5, FontWeight.w400, p.fg),
        labelMedium: text(12, FontWeight.w500, p.fgDim),
        bodySmall: text(11, FontWeight.w400, p.fgFaint),
      ),
      iconTheme: IconThemeData(color: p.fgDim, size: 22),
      sliderTheme: SliderThemeData(
        // Flat slider: thin track, small thumb, NO overlay or glow halo.
        trackHeight: 4,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        activeTrackColor: p.accent,
        inactiveTrackColor: p.line2,
        thumbColor: p.accent,
        overlayColor: Colors.transparent,
        secondaryActiveTrackColor: p.accentDim,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.fgFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surface3,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surface3,
          borderRadius: const BorderRadius.all(Radius.circular(Tokens.rSm)),
        ),
        textStyle: TextStyle(color: p.fg, fontSize: 12),
      ),
    );
  }
}
