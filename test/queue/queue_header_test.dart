import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/queue/widgets/queue_header.dart';

import '../support/layout_harness.dart';

/// The header labels its actions by the room the page has, not by the
/// window: beside an open sidebar a 860 window leaves the page 636.
void main() {
  final actions = [
    QueueHeaderAction(
      icon: Icons.add_rounded,
      label: 'Add files',
      onPressed: () {},
      primary: true,
    ),
    QueueHeaderAction(
      icon: Icons.clear_all_rounded,
      label: 'Clear queue',
      onPressed: () {},
    ),
  ];

  Future<List<Widget>> build(WidgetTester tester, double available) async {
    late List<Widget> out;
    await pumpStudio(
      tester,
      Builder(
        builder: (context) {
          out = queueHeaderButtons(context, actions, available: available);
          return const SizedBox();
        },
      ),
      size: const Size(860, 700),
    );
    return out;
  }

  testWidgets('a narrow page folds the actions', (tester) async {
    final buttons = await build(tester, 636);
    expect(buttons, hasLength(2));
    // Add files, then the menu: no labelled Clear queue.
    final last = (buttons.last as Padding).child;
    expect(last, isNot(isA<TextButton>()));
    expect(last, isNot(isA<Tooltip>()));
  });

  testWidgets('a roomy page labels them', (tester) async {
    final buttons = await build(tester, 1000);
    expect(buttons, hasLength(2));
    final last = buttons.last as Padding;
    expect(last.child, isA<TextButton>());
  });
}
