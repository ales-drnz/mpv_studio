import '../../ui/layout/layout.dart';

/// How the Effects page shows an open stage.
enum RackMode {
  /// Open stages unfold in place, in the chain (pointer windows of medium
  /// size and up): several can be open at once, and the one just opened
  /// scrolls into view.
  inline,

  /// The chain on the left and the stage being edited on the right, so
  /// editing never hides the chain (wide windows tall enough for the
  /// header, the quick editors and an editor under them).
  split,

  /// One stage at a time, covering the chain like a pushed page, with
  /// back to close it (phones, touch, and low windows, where only a page
  /// of its own leaves the editor enough height).
  detail;

  /// The chain's width when [split].
  static const double listWidth = 360;

  /// The narrowest editor worth splitting for.
  static const double minDetailWidth = 420;

  /// The lowest page worth splitting: below it the page header and the
  /// quick editors leave the editor pane too little room.
  static const double minSplitHeight = 600;

  /// The mode for a page laid out as [layout], [width] wide for content
  /// and [height] tall.
  static RackMode of(StudioLayout layout, double width, double height) {
    final low = layout.isShort || height < minSplitHeight;
    if (!low &&
        TwoPane.splitsAt(
          width,
          listWidth: listWidth,
          minDetailWidth: minDetailWidth,
        )) {
      return split;
    }
    if (layout.prefersSheets || layout.isShort) return detail;
    // A wide but low pointer window: one stage at a time beats an editor
    // squeezed under the chain.
    if (low && width >= listWidth + minDetailWidth) return detail;
    return inline;
  }
}
