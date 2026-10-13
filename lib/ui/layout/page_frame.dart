import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'layout_scope.dart';
import 'window_class.dart';

/// Centres [child] and caps its width at [maxWidth], so content reads at a
/// comfortable line length on wide windows and fills narrow ones.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    this.maxWidth = Breakpoints.readable,
    this.fillHeight = false,
    required this.child,
  });

  final double maxWidth;

  /// Gives [child] the full available height (for bodies that scroll
  /// themselves) instead of its own.
  final bool fillHeight;

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(
        width: double.infinity,
        height: fillHeight ? double.infinity : null,
        child: child,
      ),
    ),
  );
}

/// The standard page: a header (optional back button, title, actions and
/// a [bottom] row such as tabs) above a body, all centred at [maxWidth]
/// with the padding of the window class.
///
/// With [scrollable] (the default) the body scrolls as one column, so the
/// page never overflows; pass `scrollable: false` when the body brings its
/// own scrolling (a `ListView`, a `TabBarView`) and it then fills the
/// remaining height. The frame applies the safe area and lifts the body
/// above the soft keyboard; inside the shell both are already consumed,
/// so they cost nothing there.
///
/// ```dart
/// PageFrame(
///   title: 'Queue',
///   actions: [IconButton(...)],
///   body: Column(children: [...]),
/// )
/// ```
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    this.title,
    this.onBack,
    this.actions = const [],
    this.bottom,
    required this.body,
    this.scrollable = true,
    this.maxWidth = Breakpoints.readable,
    this.padding,
    this.controller,
  });

  /// The page title; null for no title row (unless [onBack] or [actions]
  /// are given).
  final String? title;

  /// Shows a back chevron that calls this (a pushed detail page).
  final VoidCallback? onBack;

  /// Trailing header buttons.
  final List<Widget> actions;

  /// A row under the title, such as a `TabBar` or a filter bar. Stays put
  /// while the body scrolls.
  final Widget? bottom;

  final Widget body;

  /// Whether the frame scrolls [body]; see the class docs.
  final bool scrollable;

  /// The content width cap; `double.infinity` for full-bleed pages.
  final double maxWidth;

  /// The body padding; defaults to `context.layout.pagePadding`.
  final EdgeInsets? padding;

  /// The scroll controller of the body when [scrollable].
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final pad = padding ?? layout.pagePadding;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final hasHeader = title != null || onBack != null || actions.isNotEmpty;

    final header = hasHeader
        ? Padding(
            padding: EdgeInsets.fromLTRB(
              onBack != null ? math.max(pad.left - Tokens.s12, 0) : pad.left,
              layout.isShort ? Tokens.s4 : Tokens.s12,
              math.max(pad.right - Tokens.s8, 0),
              Tokens.s4,
            ),
            child: PageHeader(title: title, onBack: onBack, actions: actions),
          )
        : null;
    final tabs = bottom == null
        ? null
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: pad.left),
            child: bottom,
          );

    final Widget content = scrollable
        ? SingleChildScrollView(
            controller: controller,
            padding: pad,
            child: ReadableWidth(maxWidth: maxWidth, child: body),
          )
        : Padding(
            padding: pad,
            child: ReadableWidth(
              maxWidth: maxWidth,
              fillHeight: true,
              child: body,
            ),
          );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null)
                ReadableWidth(maxWidth: maxWidth, child: header),
              if (tabs != null) ReadableWidth(maxWidth: maxWidth, child: tabs),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

/// The header row of a [PageFrame]: back chevron, title and actions, at
/// least one tap target tall. Usable on its own above custom bodies.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.title,
    this.onBack,
    this.actions = const [],
  });

  final String? title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final style = layout.isCompact || layout.isShort
        ? Tokens.title.copyWith(fontSize: 18)
        : Tokens.title;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: layout.minTap),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: 'Back',
              icon: Icon(Icons.chevron_left_rounded, color: Tokens.fgDim),
            ),
          if (title != null)
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}
