import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';

/// Shown when the current entry came from a playlist file
/// (`stream.playlistPath`): its name and buttons to the previous and next
/// source playlist. [onPrevious] and [onNext] report whether there was one
/// to go to (null when the call failed and a toast already said so); the
/// banner says so when there was none.
class PlaylistBanner extends StatelessWidget {
  const PlaylistBanner({
    super.key,
    required this.path,
    required this.onPrevious,
    required this.onNext,
  });

  final String path;
  final Future<bool?> Function() onPrevious;
  final Future<bool?> Function() onNext;

  /// The file name of [path], a local path or a URL.
  static String nameOf(String path) {
    final cut = path.lastIndexOf(RegExp(r'[/\\]'));
    final name = cut < 0 ? path : path.substring(cut + 1);
    if (name.isEmpty) return path;
    try {
      return Uri.decodeComponent(name);
    } on ArgumentError {
      return name;
    } on FormatException {
      return name;
    }
  }

  Future<void> _go(
    BuildContext context,
    Future<bool?> Function() go,
    String none,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final moved = await go();
    if (moved != false || messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(none, style: TextStyle(color: Tokens.fg)),
          backgroundColor: Tokens.surface3,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tap = context.layout.minTap;
    final constraints = BoxConstraints.tightFor(width: tap, height: tap);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s8),
      child: Container(
        padding: const EdgeInsets.only(left: Tokens.s12),
        decoration: ShapeDecoration(
          color: Tokens.surface2,
          shape: Tokens.squircle(Tokens.rSm),
        ),
        child: Row(
          children: [
            Icon(Icons.queue_music_rounded, size: 16, color: Tokens.accent),
            const SizedBox(width: Tokens.s8),
            Expanded(
              child: Text(
                'From ${nameOf(path)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tokens.caption.copyWith(color: Tokens.fgDim),
              ),
            ),
            IconButton(
              tooltip: 'Previous playlist',
              onPressed: () =>
                  _go(context, onPrevious, 'This is the first playlist'),
              icon: const Icon(Icons.skip_previous_rounded, size: 20),
              color: Tokens.fgDim,
              constraints: constraints,
            ),
            IconButton(
              tooltip: 'Next playlist',
              onPressed: () =>
                  _go(context, onNext, 'This is the last playlist'),
              icon: const Icon(Icons.skip_next_rounded, size: 20),
              color: Tokens.fgDim,
              constraints: constraints,
            ),
          ],
        ),
      ),
    );
  }
}
