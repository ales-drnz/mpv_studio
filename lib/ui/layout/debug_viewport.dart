import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Renders the app inside a fixed logical viewport, to try phone and
/// tablet layouts in a desktop window. Off unless a size is defined:
///
/// ```sh
/// flutter run -d linux --dart-define=STUDIO_VIEWPORT=360x780 \
///   --dart-define=STUDIO_INPUT=touch
/// ```
///
/// The viewport is centred (scaled down when the window is smaller) and
/// its [MediaQuery] reports the viewport size and phone-like safe-area
/// insets: 24 at the top and 16 at the bottom by default, or the
/// `STUDIO_INSETS=left,top,right,bottom` define. `STUDIO_INPUT` is read by
/// `InputMode.platformDefault`. Release builds compile this to [child].
class DebugViewport extends StatelessWidget {
  const DebugViewport({super.key, required this.child});

  final Widget child;

  static const String _viewport = String.fromEnvironment('STUDIO_VIEWPORT');
  static const String _insets = String.fromEnvironment('STUDIO_INSETS');

  /// The forced viewport size, or null when off.
  static Size? get size {
    if (kReleaseMode || _viewport.isEmpty) return null;
    final parts = _viewport.toLowerCase().split('x');
    if (parts.length != 2) return null;
    final w = double.tryParse(parts[0]);
    final h = double.tryParse(parts[1]);
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return Size(w, h);
  }

  static EdgeInsets get _padding {
    final v = _insets.split(',').map(double.tryParse).toList();
    if (v.length == 4 && v.every((e) => e != null)) {
      return EdgeInsets.fromLTRB(v[0]!, v[1]!, v[2]!, v[3]!);
    }
    return const EdgeInsets.only(top: 24, bottom: 16);
  }

  @override
  Widget build(BuildContext context) {
    final forced = size;
    if (forced == null) return child;
    final padding = _padding;
    final data = MediaQuery.of(
      context,
    ).copyWith(size: forced, padding: padding, viewPadding: padding);
    return ColoredBox(
      color: Tokens.surface3,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox.fromSize(
            size: forced,
            child: ClipRect(
              child: MediaQuery(data: data, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
