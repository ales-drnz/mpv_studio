import 'dart:async';

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/reorder_proxy.dart';
import '../queue_controller.dart';
import '../queue_details.dart';
import 'queue_tile.dart';
import '../../../ui/widgets/studio_snack.dart';

/// What the row menu offers.
enum QueueAction {
  play,
  playNext,
  moveToTop,
  moveToBottom,
  info,
  copyUrl,
  replace,
  remove,
}

/// The menu items for the entry at [index] of a queue of [count] entries
/// whose current entry is [current].
List<StudioMenuItem<QueueAction>> queueMenuItems({
  required int index,
  required int count,
  required int current,
}) => [
  const StudioMenuItem(
    value: QueueAction.play,
    label: 'Play',
    icon: Icons.play_arrow_rounded,
  ),
  StudioMenuItem(
    value: QueueAction.playNext,
    label: 'Play next',
    icon: Icons.queue_play_next_rounded,
    enabled: current >= 0 && index != current && index != current + 1,
  ),
  StudioMenuItem(
    value: QueueAction.moveToTop,
    label: 'Move to top',
    icon: Icons.vertical_align_top_rounded,
    enabled: index > 0,
  ),
  StudioMenuItem(
    value: QueueAction.moveToBottom,
    label: 'Move to bottom',
    icon: Icons.vertical_align_bottom_rounded,
    enabled: index < count - 1,
  ),
  const StudioMenuItem(
    value: QueueAction.info,
    label: 'Show info',
    icon: Icons.info_outline_rounded,
  ),
  const StudioMenuItem(
    value: QueueAction.copyUrl,
    label: 'Copy location',
    icon: Icons.link_rounded,
  ),
  const StudioMenuItem(
    value: QueueAction.replace,
    label: 'Replace with a file',
    icon: Icons.swap_horiz_rounded,
  ),
  const StudioMenuItem(
    value: QueueAction.remove,
    label: 'Remove',
    icon: Icons.close_rounded,
    destructive: true,
  ),
];

/// The queue as a reorderable list.
///
/// With a pointer: a click selects, a double click plays, right click
/// opens the menu, the arrow keys move the selection, Enter plays it and
/// Delete removes it. On touch: a tap plays, a long press opens the
/// action sheet, a swipe removes (with undo) and the handle reorders after
/// a long press.
class QueueList extends StatefulWidget {
  const QueueList({
    super.key,
    required this.playlist,
    required this.details,
    required this.outcomes,
    required this.controller,
    required this.selected,
    required this.onSelect,
    required this.onAction,
  });

  final Playlist playlist;
  final Map<Media, LoadedDetails> details;
  final Map<Media, EntryOutcome> outcomes;
  final QueueController controller;

  /// The selected entry, null for none.
  final int? selected;
  final ValueChanged<int?> onSelect;

  /// Runs a menu [QueueAction] on an entry.
  final void Function(QueueAction action, int index) onAction;

  @override
  State<QueueList> createState() => _QueueListState();
}

class _QueueListState extends State<QueueList> {
  final _focus = FocusNode(debugLabel: 'queue list');
  final _scroll = ScrollController();
  final _rowKeys = <int, GlobalKey>{};

  /// A row swiped away whose removal is still in flight, hidden until the
  /// next playlist arrives.
  int? _dismissed;
  Playlist? _dismissedFrom;

  @override
  void didUpdateWidget(QueueList old) {
    super.didUpdateWidget(old);
    if (!identical(old.playlist, widget.playlist)) {
      _dismissed = null;
      _dismissedFrom = null;
    }
  }

  /// The last pointer click, to tell a double click: a click selects at
  /// once, a second one on the same row soon after plays it.
  Timer? _clickTimer;
  int? _clickIndex;

  void _click(int index) {
    if ((_clickTimer?.isActive ?? false) && _clickIndex == index) {
      _clickTimer!.cancel();
      widget.onAction(QueueAction.play, index);
      return;
    }
    _clickTimer?.cancel();
    _clickIndex = index;
    _clickTimer = Timer(kDoubleTapTimeout, () {});
    _focus.requestFocus();
    widget.onSelect(index);
  }

  @override
  void dispose() {
    _clickTimer?.cancel();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<Media> get _items => widget.playlist.items;

  Future<void> _openMenu(int index, Offset? position) async {
    final picked = await showStudioMenu<QueueAction>(
      context,
      items: queueMenuItems(
        index: index,
        count: _items.length,
        current: widget.playlist.index,
      ),
      position: position,
      title: QueueRowInfo.of(
        _items[index],
        widget.details[_items[index]],
      ).title,
    );
    if (picked != null) widget.onAction(picked, index);
  }

  void _select(int index) {
    widget.onSelect(index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(index));
  }

  /// Scrolls the row at [index] into view.
  void _reveal(int index) {
    final ctx = _rowKeys[index]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final count = _items.length;
    if (count == 0) return KeyEventResult.ignored;
    final selected = widget.selected;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _select(selected == null ? 0 : (selected + 1).clamp(0, count - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _select(
        selected == null ? count - 1 : (selected - 1).clamp(0, count - 1),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _select(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _select(count - 1);
      return KeyEventResult.handled;
    }
    if (selected == null || selected >= count) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      widget.onAction(QueueAction.play, selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      widget.onAction(QueueAction.remove, selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu ||
        (key == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed)) {
      _openMenu(selected, null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Removes a swiped row and offers to put it back.
  Future<void> _dismiss(int index) async {
    final title = QueueRowInfo.of(
      _items[index],
      widget.details[_items[index]],
    ).title;
    setState(() {
      _dismissed = index;
      _dismissedFrom = widget.playlist;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    final removed = await widget.controller.remove(index);
    if (!mounted) return;
    if (removed == null) {
      setState(() => _dismissed = null);
      return;
    }
    messenger?.showStudioSnack(
      'Removed "$title"',
      actionLabel: 'Undo',
      onAction: () => widget.controller.restore(removed, index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final touch = layout.isTouch;
    final items = _items;
    final hidden = identical(_dismissedFrom, widget.playlist)
        ? _dismissed
        : null;
    final rows = [
      for (var i = 0; i < items.length; i++)
        if (i != hidden) i,
    ];

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: ReorderableListView.builder(
        scrollController: _scroll,
        padding: PageEnd.padding(context),
        // Each row brings its own handle.
        buildDefaultDragHandles: false,
        // The row lifts in its own shape; the gap under it stays clear.
        proxyDecorator: reorderProxy(
          shape: Tokens.shape(Tokens.rMd),
          inset: const EdgeInsets.only(bottom: Tokens.s4),
        ),
        itemCount: rows.length,
        // ignore: deprecated_member_use
        onReorder: reorderTo(
          (from, to) => widget.controller.move(rows[from], rows[to]),
        ),
        itemBuilder: (context, row) {
          final i = rows[row];
          final item = items[i];
          final rowKey = _rowKeys.putIfAbsent(i, GlobalKey.new);
          // Gaps between the rows only: the last one ends at the page end.
          final gap = row < rows.length - 1 ? Tokens.s4 : 0.0;
          final tile = KeyedSubtree(
            key: rowKey,
            child: QueueTile(
              index: i,
              row: row,
              info: QueueRowInfo.of(item, widget.details[item]),
              outcome: widget.outcomes[item],
              current: i == widget.playlist.index,
              selected: !touch && i == widget.selected,
              player: widget.controller.player,
              onTap: () =>
                  touch ? widget.onAction(QueueAction.play, i) : _click(i),
              onPlay: () => widget.onAction(QueueAction.play, i),
              onRemove: () => widget.onAction(QueueAction.remove, i),
              onMore: (position) => _openMenu(i, position),
              gap: gap,
            ),
          );
          final key = ValueKey('${item.uri}#$i');
          if (!touch) return KeyedSubtree(key: key, child: tile);
          return Dismissible(
            key: key,
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _dismiss(i),
            background: _SwipeBackground(gap: gap),
            child: tile,
          );
        },
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.gap});

  /// The row's space below, left clear.
  final double gap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: gap),
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: Tokens.red.withValues(alpha: 0.14),
        shape: Tokens.shape(Tokens.rMd),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: Tokens.s24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, color: Tokens.red),
              const SizedBox(width: Tokens.s8),
              Text('Remove', style: Tokens.label.copyWith(color: Tokens.red)),
            ],
          ),
        ),
      ),
    ),
  );
}
