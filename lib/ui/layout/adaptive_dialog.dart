import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'layout_scope.dart';

/// The round grab handle at the top of every bottom sheet: a 32 by 4
/// pill, centred, 16 above the content.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 32,
      height: 4,
      margin: const EdgeInsets.only(bottom: Tokens.s16),
      decoration: ShapeDecoration(color: Tokens.fgFaint, shape: Tokens.pill),
    ),
  );
}

/// Opens the app's modal bottom sheet: flat surface, rounded top, grab
/// handle, safe area, lifted above the soft keyboard and capped at 90% of
/// the screen height. [builder] builds the content under the handle; it
/// scrolls when taller than the sheet. Android back closes it.
///
/// It opens on the root navigator (unless [useRootNavigator] is false), so
/// its barrier dims the whole screen, the mini-player and the tab bar
/// included, as a dialog's does; a sheet on a section's own navigator
/// would open under them.
Future<T?> showStudioSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    backgroundColor: Tokens.surface2,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.rXl)),
    ),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) {
      final mq = MediaQuery.of(context);
      return Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.s16,
                Tokens.s16,
                Tokens.s16,
                Tokens.s16,
              ),
              // Bottom anchored, so the buttons at the bottom stay put
              // when the content changes height; the top edge follows,
              // animated.
              child: _Resizing(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SheetHandle(),
                    Flexible(
                      child: SingleChildScrollView(child: builder(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Opens a dialog that adapts to the window: a centred dialog at most
/// [maxWidth] wide on medium and wider windows, a bottom sheet on compact
/// ones. The dialog hangs from a fixed top ([dialogTopInset]) and the
/// sheet from the bottom, so neither jumps when its content changes
/// height. [title] heads it, [builder] builds the (scrolling) content and
/// [actions] builds the buttons, which sit at the bottom right. Pop the
/// dialog's own context with a result to close it.
///
/// ```dart
/// final ok = await showStudioDialog<bool>(
///   context,
///   title: 'Remove server?',
///   builder: (context) => const Text('Its favourites stay.'),
///   actions: (context) => [
///     TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
///     FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
///   ],
/// );
/// ```
Future<T?> showStudioDialog<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  List<Widget> Function(BuildContext context)? actions,
  double maxWidth = 520,
}) {
  Widget body(BuildContext context, {required bool sheet}) {
    final buttons = actions?.call(context) ?? const <Widget>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.s12),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Tokens.heading.copyWith(fontSize: 22, height: 28 / 22),
            ),
          ),
        ),
        // The sheet scrolls as a whole; the dialog scrolls its content
        // between a fixed title and fixed buttons.
        if (sheet)
          builder(context)
        else
          Flexible(child: SingleChildScrollView(child: builder(context))),
        if (buttons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.s16),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: Tokens.s8,
              runSpacing: Tokens.s8,
              children: buttons,
            ),
          ),
      ],
    );
  }

  if (context.layout.isCompact) {
    return showStudioSheet<T>(
      context,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s8),
        child: body(context, sheet: true),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height;
      final top = dialogTopInset(height);
      return Dialog(
        backgroundColor: Tokens.surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Tokens.shape(Tokens.rXl),
        // Hung from a fixed top instead of centred: when the content grows
        // or shrinks (a choice that hides rows), the title stays put and
        // only the bottom edge moves, animated, instead of the whole
        // dialog jumping and its buttons sliding under the pointer.
        alignment: Alignment.topCenter,
        insetPadding: EdgeInsets.fromLTRB(
          Tokens.s24,
          top,
          Tokens.s24,
          Tokens.s24,
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: math.max(height - top - Tokens.s24, 120),
          ),
          child: _Resizing(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(Tokens.s24),
              child: body(context, sheet: false),
            ),
          ),
        ),
      );
    },
  );
}

/// Where a [showStudioDialog] dialog's top edge sits in a window [height]
/// tall: a tenth of the way down, never under 24.
@visibleForTesting
double dialogTopInset(double height) => math.max(Tokens.s24, height * 0.1);

/// Animates its size when its child's changes, so a dialog or sheet whose
/// content grows or shrinks moves its free edge smoothly instead of
/// snapping.
class _Resizing extends StatelessWidget {
  const _Resizing({required this.alignment, required this.child});

  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    alignment: alignment,
    child: child,
  );
}
