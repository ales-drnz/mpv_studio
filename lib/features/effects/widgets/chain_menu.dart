import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/round_icon_button.dart';
import '../../../ui/widgets/studio_snack.dart';
import '../rack_controller.dart';
import '../saved_chains.dart';

/// What the Chains menu holds besides the saved chains themselves.
enum _ChainAction { save, copy, paste, delete }

/// The Chains menu of the rack header: save the chain under a name, load
/// a saved one (with an undo), copy the chain as text, paste one, delete
/// a saved one.
Future<void> openChainMenu(
  BuildContext context,
  RackController rack,
  ChainLibrary library, {
  Offset? position,
}) async {
  final saved = library.chains;
  final picked = await showStudioMenu<Object>(
    context,
    title: 'Chains',
    position: position,
    items: [
      for (final name in saved.keys)
        StudioMenuItem(value: name, label: name, icon: Icons.bookmark_rounded),
      StudioMenuItem(
        value: _ChainAction.save,
        label: 'Save as…',
        icon: Icons.bookmark_add_outlined,
        enabled: rack.chain.effects.isNotEmpty,
      ),
      StudioMenuItem(
        value: _ChainAction.copy,
        label: 'Copy as text',
        icon: Icons.copy_rounded,
        enabled: rack.chain.effects.isNotEmpty,
      ),
      const StudioMenuItem(
        value: _ChainAction.paste,
        label: 'Paste a chain…',
        icon: Icons.content_paste_rounded,
      ),
      if (saved.isNotEmpty)
        const StudioMenuItem(
          value: _ChainAction.delete,
          label: 'Delete a saved chain…',
          icon: Icons.bookmark_remove_outlined,
          destructive: true,
        ),
    ],
  );
  if (picked == null || !context.mounted) return;
  switch (picked) {
    case final String name:
      final chain = saved[name];
      if (chain != null) _load(context, rack, chain, 'Loaded "$name"');
    case _ChainAction.save:
      await _save(context, rack, library);
    case _ChainAction.copy:
      await Clipboard.setData(
        ClipboardData(text: chainToText(rack.chain.effects)),
      );
      if (context.mounted) showStudioSnack(context, 'Chain copied as text');
    case _ChainAction.paste:
      await _paste(context, rack);
    case _ChainAction.delete:
      await _delete(context, library);
  }
}

/// Plays [chain] and offers to go back to the one before.
void _load(
  BuildContext context,
  RackController rack,
  List<AudioEffect> chain,
  String message,
) {
  final before = rack.chain.effects;
  rack.replaceAll(chain);
  showStudioSnack(
    context,
    message,
    actionLabel: 'Undo',
    onAction: () => rack.replaceAll(before),
  );
}

Future<void> _save(
  BuildContext context,
  RackController rack,
  ChainLibrary library,
) async {
  final name = await _ask(
    context,
    title: 'Save the chain',
    label: 'Name',
    action: 'Save',
    check: (text) => text.trim().isEmpty ? 'Give the chain a name.' : null,
  );
  if (name == null || !context.mounted) return;
  final key = name.trim();
  final replaced = library.chains[key];
  library.save(key, rack.chain.effects);
  if (replaced == null) {
    showStudioSnack(context, 'Saved "$key"');
  } else {
    showStudioSnack(
      context,
      'Replaced "$key"',
      actionLabel: 'Undo',
      onAction: () => library.save(key, replaced),
    );
  }
}

Future<void> _paste(BuildContext context, RackController rack) async {
  final text = await _ask(
    context,
    title: 'Paste a chain',
    label: 'Chain as text',
    action: 'Load',
    lines: 4,
    check: (text) => chainFromText(text) == null
        ? 'That text is not an effects chain.'
        : null,
  );
  if (text == null || !context.mounted) return;
  _load(context, rack, chainFromText(text)!, 'Chain pasted');
}

/// Picks a saved chain to delete; the dialog closes so the toast's undo
/// is in reach.
Future<void> _delete(BuildContext context, ChainLibrary library) async {
  final name = await showStudioDialog<String>(
    context,
    title: 'Delete a saved chain',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final name in library.chains.keys)
          Row(
            children: [
              Expanded(child: Text(name, style: Tokens.body)),
              RoundIconButton(
                icon: Icons.delete_outline_rounded,
                size: 20,
                tooltip: 'Delete "$name"',
                onTap: () => Navigator.pop(context, name),
              ),
            ],
          ),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
  final chain = name == null ? null : library.chains[name];
  if (name == null || chain == null || !context.mounted) return;
  library.delete(name);
  showStudioSnack(
    context,
    'Deleted "$name"',
    actionLabel: 'Undo',
    onAction: () => library.save(name, chain),
  );
}

/// Asks for a line of text in a dialog; [check] says what is wrong with
/// it, null when it will do. Null when cancelled.
Future<String?> _ask(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  required String? Function(String text) check,
  int lines = 1,
}) => showStudioDialog<String>(
  context,
  title: title,
  builder: (context) =>
      _Ask(label: label, action: action, check: check, lines: lines),
);

/// The field of [_ask], which owns its controller: the dialog keeps
/// building it while it animates out.
class _Ask extends StatefulWidget {
  const _Ask({
    required this.label,
    required this.action,
    required this.check,
    required this.lines,
  });

  final String label;
  final String action;
  final String? Function(String text) check;
  final int lines;

  @override
  State<_Ask> createState() => _AskState();
}

class _AskState extends State<_Ask> {
  final _field = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final wrong = widget.check(_field.text);
    if (wrong == null) {
      Navigator.pop(context, _field.text);
    } else {
      setState(() => _problem = wrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _field,
          label: widget.label,
          showLabel: true,
          autofocus: context.layout.isPointer,
          monospace: widget.lines > 1,
          maxLines: widget.lines,
          minLines: widget.lines,
          onSubmitted: widget.lines == 1 ? (_) => _submit() : null,
        ),
        if (problem != null)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.s8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                problem,
                style: Tokens.caption.copyWith(color: Tokens.red),
              ),
            ),
          ),
        const SizedBox(height: Tokens.s12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: Tokens.s8),
            FilledButton(onPressed: _submit, child: Text(widget.action)),
          ],
        ),
      ],
    );
  }
}
