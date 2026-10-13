import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/studio/studio_host.dart';

/// A stand-in studio: a name, and whether it was shut down.
class _Studio {
  _Studio(this.name);
  final String name;
  bool down = false;
}

/// Keeps the studio it was first built on, as a page holding its player
/// would: a page that was not rebuilt would still show the old one.
class _Page extends StatefulWidget {
  const _Page(this.studio);
  final _Studio studio;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  late final _Studio subscribed = widget.studio;
  @override
  Widget build(BuildContext context) => Text('page on ${subscribed.name}');
}

void main() {
  late _Studio first;
  late Completer<_Studio> next;
  late StudioRestart restart;
  final changed = <String>[];

  Future<void> pump(
    WidgetTester tester, {
    Future<_Studio> Function()? launch,
    Future<_Studio> Function(_Studio old)? restartWith,
  }) {
    first = _Studio('one');
    next = Completer();
    changed.clear();
    return tester.pumpWidget(
      MaterialApp(
        home: StudioHost<_Studio>(
          initial: first,
          restart:
              restartWith ??
              (old) {
                old.down = true;
                return next.future;
              },
          launch: launch ?? () async => _Studio('fresh'),
          onChanged: (s) => changed.add(s.name),
          errorBuilder: (context, error, retry) =>
              TextButton(onPressed: retry, child: Text('failed: $error')),
          builder: (context, studio, r) {
            restart = r;
            return Column(
              children: [
                _Page(studio),
                if (r.inProgress) const Text('restarting'),
              ],
            );
          },
        ),
      ),
    );
  }

  testWidgets('a restart swaps the studio and rebuilds the pages on it', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('page on one'), findsOneWidget);

    final done = restart.run();
    await tester.pump();
    expect(find.text('restarting'), findsOneWidget);
    expect(first.down, isTrue);

    next.complete(_Studio('two'));
    await done;
    await tester.pump();
    expect(find.text('page on two'), findsOneWidget);
    expect(find.text('restarting'), findsNothing);
    expect(changed, ['two']);
  });

  testWidgets('a second restart while one runs joins it', (tester) async {
    await pump(tester);
    final a = restart.run();
    await tester.pump();
    final b = restart.run();
    next.complete(_Studio('two'));
    await Future.wait([a, b]);
    await tester.pump();
    expect(changed, ['two']);
  });

  testWidgets('a failed restart shows the error, and retry launches', (
    tester,
  ) async {
    await pump(tester);
    final done = restart.run();
    next.completeError(StateError('no device'));
    await done;
    await tester.pump();
    expect(find.textContaining('failed: Bad state: no device'), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text('page on fresh'), findsOneWidget);
    expect(changed, ['fresh']);
  });

  testWidgets('a restart that throws at once still ends on the error', (
    tester,
  ) async {
    await pump(tester, restartWith: (_) => throw StateError('no engine'));
    await restart.run();
    await tester.pump();
    expect(find.textContaining('failed: Bad state: no engine'), findsOneWidget);
    // Not stuck: retry launches.
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text('page on fresh'), findsOneWidget);
  });
}
