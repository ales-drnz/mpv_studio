import 'package:flutter/widgets.dart';

import 'layout_scope.dart';

/// Lays [children] out in as many equal columns as fit the available
/// width, each at least [minTileWidth] wide (and at most [maxColumns]).
/// It sizes to its content, so it sits inside a scrolling page body.
///
/// ```dart
/// ResponsiveGrid(
///   minTileWidth: 150,
///   tileAspectRatio: 1,
///   children: [for (final c in categories) GridCard(...)],
/// )
/// ```
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 160,
    this.maxColumns,
    this.spacing,
    this.tileAspectRatio,
  });

  final List<Widget> children;

  /// The narrowest a tile may get before a column is dropped.
  final double minTileWidth;

  /// A cap on the column count, for content that reads badly too wide.
  final int? maxColumns;

  /// The gap between tiles, both ways; defaults to `context.layout.gap`.
  final double? spacing;

  /// Width over height of every tile; null lets each tile take its own
  /// height.
  final double? tileAspectRatio;

  /// How many columns of at least [minTileWidth] fit [width].
  static int columnsFor(
    double width, {
    double minTileWidth = 160,
    double spacing = 12,
    int? maxColumns,
  }) {
    final fit = ((width + spacing) / (minTileWidth + spacing)).floor();
    final cap = maxColumns ?? fit;
    return fit.clamp(1, cap < 1 ? 1 : cap);
  }

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? context.layout.gap;
    return LayoutBuilder(
      builder: (context, c) {
        final columns = columnsFor(
          c.maxWidth,
          minTileWidth: minTileWidth,
          spacing: gap,
          maxColumns: maxColumns,
        );
        // Floored so rounding never pushes the last tile onto a new run.
        final tile = ((c.maxWidth - gap * (columns - 1)) / columns)
            .floorToDouble();
        final ratio = tileAspectRatio;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(
                width: tile,
                child: ratio == null
                    ? child
                    : AspectRatio(aspectRatio: ratio, child: child),
              ),
          ],
        );
      },
    );
  }
}
