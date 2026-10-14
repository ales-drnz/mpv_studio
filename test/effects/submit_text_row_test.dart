import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/effects/widgets/param_controls.dart';

import '../support/layout_harness.dart';

/// The raw lavfi entry shows over three lines but is one line: Enter
/// applies it, and no line break reaches the entry.
void main() {
  Future<List<String>> pump(WidgetTester tester) async {
    final submitted = <String>[];
    await pumpStudio(
      tester,
      Scaffold(
        body: SizedBox(
          width: 480,
          child: SubmitTextRow(
            label: 'lavfi entry',
            value: 'lavfi-aecho=0.8:0.9:500:0.3',
            maxLines: 3,
            onSubmit: submitted.add,
          ),
        ),
      ),
    );
    return submitted;
  }

  EditableText editable(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  testWidgets('Enter applies a wrapped entry', (tester) async {
    final submitted = await pump(tester);
    final field = editable(tester);
    expect(field.maxLines, 3);
    expect(field.textInputAction, TextInputAction.done);
    expect(field.keyboardType, TextInputType.text);

    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'lavfi-aecho=0.6');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, ['lavfi-aecho=0.6']);
  });

  testWidgets('a pasted line break is dropped', (tester) async {
    final submitted = await pump(tester);
    await tester.tap(find.byType(EditableText));
    await tester.enterText(
      find.byType(EditableText),
      'lavfi-aecho=0.6\n:0.9\r\n',
    );
    expect(editable(tester).controller.text, 'lavfi-aecho=0.6:0.9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, ['lavfi-aecho=0.6:0.9']);
    expect(submitted.single, isNot(contains('\n')));
  });
}
