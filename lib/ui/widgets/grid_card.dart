import 'package:flutter/material.dart';

import '../tokens.dart';

/// A square squircle tile for the app's landing grids: a centred accent
/// icon over a title, on a flat surface. Lay several out with
/// `ResponsiveGrid`.
///
/// When [active] is set the tile fills with the accent wash and shows an
/// "on" pip in the top-right corner, for a tile whose feature is engaged;
/// the icon stays accent in both states.
class GridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  /// The accent wash and the "on" pip.
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
    // Squircle (superellipse) corners, the same flat surface as the rest.
    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(40),
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        // Ink (not Container) so the hover and ink highlight paints on the
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
                      style: TextStyle(
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
                    decoration: ShapeDecoration(
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
