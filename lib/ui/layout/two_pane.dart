import 'package:flutter/material.dart';

import 'layout_scope.dart';
import '../widgets/section_switcher.dart';

/// A list and its detail: side by side when there is room, one at a time
/// otherwise.
///
/// The page owns the selection: it passes [detail] (null when nothing is
/// selected) and clears it in [onCloseDetail]. When split, [list] keeps
/// [listWidth] and [detail] (or [placeholder]) takes the rest. When
/// single, [detail] covers [list] with the app's fade and slide, and the
/// system back (Android back, the shell's re-tap) calls [onCloseDetail]
/// before leaving the page. The list's state (scroll offset, inputs)
/// survives both the detail and a resize across the split; the detail's
/// own state is rebuilt when the split changes.
///
/// ```dart
/// TwoPane(
///   list: ServerList(onOpen: (s) => setState(() => _open = s)),
///   detail: _open == null ? null : ServerDetail(_open!),
///   onCloseDetail: () => setState(() => _open = null),
/// )
/// ```
class TwoPane extends StatefulWidget {
  const TwoPane({
    super.key,
    required this.list,
    this.detail,
    this.onCloseDetail,
    this.placeholder,
    this.listWidth = 340,
    this.minDetailWidth = 420,
  });

  final Widget list;
  final Widget? detail;
  final VoidCallback? onCloseDetail;

  /// Fills the detail side when split and nothing is selected.
  final Widget? placeholder;

  /// The list's width when split.
  final double listWidth;

  /// The narrowest detail worth splitting for.
  final double minDetailWidth;

  /// Whether a [TwoPane] with these widths splits in [width].
  static bool splitsAt(
    double width, {
    double listWidth = 340,
    double minDetailWidth = 420,
  }) => width >= listWidth + minDetailWidth;

  @override
  State<TwoPane> createState() => _TwoPaneState();
}

class _TwoPaneState extends State<TwoPane> {
  final _listKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final list = KeyedSubtree(key: _listKey, child: widget.list);
        final detail = widget.detail;
        if (TwoPane.splitsAt(
          c.maxWidth,
          listWidth: widget.listWidth,
          minDetailWidth: widget.minDetailWidth,
        )) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: widget.listWidth, child: list),
              // A gap, not a hairline: the panes are told apart by
              // their tonal fills.
              SizedBox(width: context.layout.gap),
              Expanded(
                child: detail ?? widget.placeholder ?? const SizedBox.shrink(),
              ),
            ],
          );
        }
        return PopScope(
          canPop: detail == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) widget.onCloseDetail?.call();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: detail != null,
                child: TickerMode(enabled: detail == null, child: list),
              ),
              SectionSwitcher(
                child: detail == null
                    ? const SizedBox.shrink(key: ValueKey('two-pane-none'))
                    : KeyedSubtree(
                        key: const ValueKey('two-pane-detail'),
                        child: detail,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
