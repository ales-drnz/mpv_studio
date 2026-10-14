import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/console/widgets/console_controls.dart';
import 'package:mpv_studio/features/stream/http_options.dart';
import 'package:mpv_studio/features/stream/widgets/http_options_panel.dart';
import 'package:mpv_studio/features/stream/widgets/stream_form.dart';
import 'package:mpv_studio/ui/widgets/custom_url_bar.dart';

import '../support/layout_harness.dart';

/// Fields that hold URLs, headers and commands keep the keyboard's
/// autocorrect and suggestions off.
void expectNoAutocorrect(WidgetTester tester) {
  final fields = tester.widgetList<TextField>(find.byType(TextField));
  expect(fields, isNotEmpty);
  for (final f in fields) {
    expect(f.autocorrect, isFalse);
    expect(f.enableSuggestions, isFalse);
  }
}

void main() {
  testWidgets('HTTP option fields do not autocorrect', (tester) async {
    await pumpStudio(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: HttpOptionsPanel(
            initial: const HttpOptions(
              headers: [HttpHeader('Referer', 'https://example.test')],
            ),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNWidgets(3));
    expectNoAutocorrect(tester);
  });

  testWidgets('the URL bar and the console do not autocorrect', (tester) async {
    final command = TextEditingController();
    final focus = FocusNode();
    addTearDown(command.dispose);
    addTearDown(focus.dispose);
    await pumpStudio(
      tester,
      Scaffold(
        body: Column(
          children: [
            CustomUrlBar(onPlay: (_) {}),
            ConsoleInput(
              controller: command,
              focusNode: focus,
              onChanged: (_) {},
              onTap: () {},
              onSubmitted: (_) {},
            ),
          ],
        ),
      ),
    );
    expectNoAutocorrect(tester);
  });

  testWidgets('a sign-in field is announced once, by its label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final host = TextEditingController();
    addTearDown(host.dispose);
    await pumpStudio(
      tester,
      Scaffold(
        body: StreamTextField(controller: host, label: 'Host', hint: 'nas'),
      ),
    );
    // The visible label is there, and only the field carries the name.
    expect(find.text('Host'), findsOneWidget);
    final named = find.bySemanticsLabel(RegExp('Host'));
    expect(named, findsOneWidget);
    final node = tester.getSemantics(named);
    // isSemantics replaces it from Flutter 3.40; the app still supports 3.38.
    // ignore: deprecated_member_use
    expect(node, containsSemantics(isTextField: true));
    // The name once, then the hint.
    expect(node.label, 'Host\nnas');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autocorrect, isFalse);
    handle.dispose();
  });
}
