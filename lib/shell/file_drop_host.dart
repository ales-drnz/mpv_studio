import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import '../util/media_import.dart';

/// Takes files and folders dropped anywhere on the window and hands their
/// paths to [onDrop]; a wash over the window shows where they would land.
class FileDropHost extends StatefulWidget {
  const FileDropHost({super.key, required this.onDrop, required this.child});

  final ValueChanged<List<String>> onDrop;
  final Widget child;

  @override
  State<FileDropHost> createState() => _FileDropHostState();
}

class _FileDropHostState extends State<FileDropHost> {
  bool _over = false;

  @override
  Widget build(BuildContext context) => DropTarget(
    onDragEntered: (_) => setState(() => _over = true),
    onDragExited: (_) => setState(() => _over = false),
    onDragDone: (detail) {
      setState(() => _over = false);
      widget.onDrop(droppedFilePaths(detail.files));
    },
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_over)
          Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: Tokens.accentWash)),
          ),
      ],
    ),
  );
}
