import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import '../util/media_import.dart';

/// Takes files and folders dropped anywhere on the window and hands their
/// paths to [onDrop], one drop after the other: a wash over the window
/// shows where they would land, and a bar along its top edge runs while a
/// drop is being searched and added.
class FileDropHost extends StatefulWidget {
  const FileDropHost({super.key, required this.onDrop, required this.child});

  final Future<void> Function(List<String> paths) onDrop;
  final Widget child;

  @override
  State<FileDropHost> createState() => FileDropHostState();
}

class FileDropHostState extends State<FileDropHost> {
  bool _over = false;
  int _busy = 0;
  Future<void> _last = Future.value();

  /// Runs [paths] after the drops before it, so two quick drops on an
  /// empty queue do not both start it.
  @visibleForTesting
  void drop(List<String> paths) {
    setState(() => _busy++);
    _last = _last.then((_) => widget.onDrop(paths)).whenComplete(() {
      if (mounted) setState(() => _busy--);
    });
  }

  @override
  Widget build(BuildContext context) => DropTarget(
    onDragEntered: (_) => setState(() => _over = true),
    onDragExited: (_) => setState(() => _over = false),
    onDragDone: (detail) {
      setState(() => _over = false);
      drop(droppedFilePaths(detail.files));
    },
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_over)
          Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: Tokens.accentWash)),
          ),
        if (_busy > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Semantics(
              liveRegion: true,
              label: 'Adding the dropped files',
              child: LinearProgressIndicator(
                minHeight: 3,
                color: Tokens.accent,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
      ],
    ),
  );
}
