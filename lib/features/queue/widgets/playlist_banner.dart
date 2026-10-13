import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/round_icon_button.dart';

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
        SnackBar(content: Text(none), duration: const Duration(seconds: 3)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Tokens.s16,
          Tokens.s4,
          Tokens.s8,
          Tokens.s4,
        ),
        decoration: ShapeDecoration(
          color: Tokens.surface,
          shape: Tokens.shape(Tokens.rLg),
        ),
        child: Row(
          children: [
            Icon(Icons.queue_music_rounded, size: 20, color: Tokens.fg),
            const SizedBox(width: Tokens.s12),
            Expanded(
              child: Text(
                'From ${nameOf(path)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tokens.body,
              ),
            ),
            RoundIconButton(
              icon: Icons.skip_previous_rounded,
              size: 20,
              tooltip: 'Previous playlist',
              onTap: () =>
                  _go(context, onPrevious, 'This is the first playlist'),
            ),
            RoundIconButton(
              icon: Icons.skip_next_rounded,
              size: 20,
              tooltip: 'Next playlist',
              onTap: () => _go(context, onNext, 'This is the last playlist'),
            ),
          ],
        ),
      ),
    );
  }
}
