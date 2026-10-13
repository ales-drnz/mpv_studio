import 'package:flutter/material.dart';

import '../tokens.dart';

/// A square squircle tile for the app's landing grids — a centred accent
/// icon over a title, on a flat surface. Shared by the Settings category
/// grid and the Effects featured grid so the two read as the same object.
///
/// When [active] is set the tile fills with the accent wash and shows an
/// "on" pip in the top-right (used by Effects to flag an engaged effect);
/// the icon stays accent in both states so the grids match.
class GridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  /// Accent wash + "on" pip. Settings categories leave this false; an
  /// engaged effect sets it true.
  final bool active;

  const GridCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    // Squircle (superellipse) corners — the same flat surface as the rest.
    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(40),
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        // Ink (not Container) so the hover/ink highlight paints on the
        // Material above the surface fill instead of being hidden behind it.
        child: Ink(
          decoration: ShapeDecoration(
            color: active ? Tokens.accentWash : Tokens.surface,
            shape: shape,
          ),
          padding: const EdgeInsets.all(Tokens.s16),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 26, color: Tokens.accent),
                    const SizedBox(height: Tokens.s12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Tokens.fg,
                      ),
                    ),
                  ],
                ),
              ),
              // "On" pip, top-right.
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: active ? 1 : 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const ShapeDecoration(
                      color: Tokens.accent,
                      shape: CircleBorder(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
