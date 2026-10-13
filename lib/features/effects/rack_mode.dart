import '../../ui/layout/layout.dart';

/// How the Effects page shows an open stage.
enum RackMode {
  /// Open stages unfold in place, in the chain (pointer windows of medium
  /// size and up): several can be open at once, and the one just opened
  /// scrolls into view.
  inline,

  /// The chain on the left and the stage being edited on the right, so
  /// editing never hides the chain (wide windows).
  split,

  /// One stage at a time, covering the chain like a pushed page, with
  /// back to close it (phones, touch, and low windows where an inline
  /// editor would not fit).
  detail;

  /// The chain's width when [split].
  static const double listWidth = 360;

  /// The narrowest editor worth splitting for.
  static const double minDetailWidth = 420;

  /// The mode for a page laid out as [layout], with [width] for content.
  static RackMode of(StudioLayout layout, double width) {
    if (TwoPane.splitsAt(
      width,
      listWidth: listWidth,
      minDetailWidth: minDetailWidth,
    )) {
      return split;
    }
    if (layout.prefersSheets || layout.isShort) return detail;
    return inline;
  }
}
