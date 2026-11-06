import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/shell/file_drop_host.dart';

import '../support/layout_harness.dart';

void main() {
  testWidgets('drops run one after the other, with a bar meanwhile', (
    tester,
  ) async {
    final started = <List<String>>[];
    final gates = <Completer<void>>[];
    await pumpStudio(
      tester,
      FileDropHost(
        onDrop: (paths) {
          started.add(paths);
          final gate = Completer<void>();
          gates.add(gate);
          return gate.future;
        },
        child: const SizedBox.expand(),
      ),
    );
    final host = tester.state<FileDropHostState>(find.byType(FileDropHost));
    host.drop(['/a']);
    host.drop(['/b']);
    await tester.pump();
    expect(started, [
      ['/a'],
    ]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    gates.first.complete();
    await tester.pump();
    expect(started, [
      ['/a'],
      ['/b'],
    ]);
    gates.last.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
