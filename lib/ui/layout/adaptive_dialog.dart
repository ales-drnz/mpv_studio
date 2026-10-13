import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'layout_scope.dart';

/// The small grab bar at the top of every bottom sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(bottom: Tokens.s12),
      decoration: BoxDecoration(
        color: Tokens.line2,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
      ),
    ),
  );
}

/// Opens the app's modal bottom sheet: flat surface, rounded top, grab
/// handle, safe area, lifted above the soft keyboard and capped at 90% of
/// the screen height. [builder] builds the content under the handle; it
/// scrolls when taller than the sheet. Android back closes it.
Future<T?> showStudioSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    backgroundColor: Tokens.surface,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.rLg)),
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
                Tokens.s12,
                Tokens.s12,
                Tokens.s12,
                Tokens.s8,
              ),
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
      );
    },
  );
}

/// Opens a dialog that adapts to the window: a centred dialog at most
/// [maxWidth] wide on medium and wider windows, a bottom sheet on compact
/// ones. [title] heads it, [builder] builds the (scrolling) content and
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
            child: Text(title, style: Tokens.heading),
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
      return Dialog(
        backgroundColor: Tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Tokens.shape(Tokens.rLg),
        insetPadding: const EdgeInsets.all(Tokens.s24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: math.max(height - 48, 120),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Tokens.s20),
            child: body(context, sheet: false),
          ),
        ),
      );
    },
  );
}
