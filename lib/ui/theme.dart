import 'package:flutter/material.dart';

import 'layout/window_class.dart';
import 'tokens.dart';

/// The Material theme of the "Expressive tonal" direction, built from a
/// [Palette]: flat (no elevation, no splash glow), tonal fills instead of
/// outlines, every button a pill and every icon button a circle, Roboto
/// named on every text style.
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
    final scheme =
        (p.isDark ? const ColorScheme.dark() : const ColorScheme.light())
            .copyWith(
              surface: p.bg,
              surfaceContainerLowest: p.bg,
              surfaceContainerLow: p.surface,
              surfaceContainer: p.surface2,
              surfaceContainerHigh: p.surface3,
              surfaceContainerHighest: p.surface4,
              onSurface: p.fg,
              onSurfaceVariant: p.fgDim,
              outline: p.fgFaint,
              outlineVariant: p.line2,
              primary: p.accent,
              onPrimary: p.onAccent,
              primaryContainer: p.accentContainer,
              onPrimaryContainer: p.onAccentContainer,
              secondary: p.accent,
              onSecondary: p.onAccent,
              secondaryContainer: p.tonal,
              onSecondaryContainer: p.onTonal,
              error: p.red,
            );
    TextStyle text(double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: Tokens.sans,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
    const pillPadding = EdgeInsets.symmetric(horizontal: Tokens.s24);
    // Every button is one tap target tall, whatever the density: the
    // compact density of pointer layouts would take 8 off each minimum.
    final buttonSize = Size.square(input.minTap);
    const buttonDensity = VisualDensity.standard;
    final buttonText = WidgetStatePropertyAll(
      text(14, FontWeight.w600, p.fg).copyWith(letterSpacing: 0.1),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: Tokens.sans,
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
        headlineMedium: Tokens.display.copyWith(color: p.fg),
        titleLarge: Tokens.title.copyWith(color: p.fg),
        titleMedium: Tokens.heading.copyWith(color: p.fg),
        bodyLarge: text(16, FontWeight.w400, p.fg),
        bodyMedium: Tokens.body.copyWith(color: p.fg),
        labelLarge: text(14, FontWeight.w600, p.fg),
        labelMedium: Tokens.label.copyWith(color: p.fgDim),
        bodySmall: Tokens.caption.copyWith(color: p.fgFaint),
      ),
      // Every text button family is a pill with a tonal or solid fill.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          padding: const WidgetStatePropertyAll(pillPadding),
          minimumSize: WidgetStatePropertyAll(buttonSize),
          visualDensity: buttonDensity,
          textStyle: buttonText,
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          padding: const WidgetStatePropertyAll(pillPadding),
          minimumSize: WidgetStatePropertyAll(buttonSize),
          visualDensity: buttonDensity,
          textStyle: buttonText,
          // Tonal instead of outlined: a hairline-free secondary button.
          backgroundColor: WidgetStatePropertyAll(p.tonal),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? p.fgFaint : p.onTonal,
          ),
          side: const WidgetStatePropertyAll(BorderSide.none),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Tokens.s16),
          ),
          minimumSize: WidgetStatePropertyAll(buttonSize),
          visualDensity: buttonDensity,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(CircleBorder()),
          minimumSize: WidgetStatePropertyAll(buttonSize),
          visualDensity: buttonDensity,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: p.surface3,
        selectedColor: p.accentContainer,
        labelStyle: text(13, FontWeight.w500, p.fg),
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surface4,
        contentTextStyle: Tokens.body.copyWith(color: p.fg),
        actionTextColor: p.accent,
        elevation: 0,
        shape: Tokens.shape(Tokens.rMd),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surface4,
        circularTrackColor: p.surface4,
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      badgeTheme: BadgeThemeData(
        backgroundColor: p.red,
        textColor: p.onAccent,
        textStyle: text(11, FontWeight.w700, p.onAccent),
      ),
      iconTheme: IconThemeData(color: p.fgDim, size: 22),
      sliderTheme: SliderThemeData(
        // Flat slider: thin track, small thumb, NO overlay or glow halo.
        trackHeight: 8,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        activeTrackColor: p.accent,
        inactiveTrackColor: p.surface4,
        thumbColor: p.accent,
        overlayColor: Colors.transparent,
        secondaryActiveTrackColor: p.accentDim,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.fgFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surface4,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(color: p.surface4, shape: Tokens.pill),
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.s12,
          vertical: Tokens.s4,
        ),
        textStyle: text(12, FontWeight.w500, p.fg),
      ),
    );
  }
}
