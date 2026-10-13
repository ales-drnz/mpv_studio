import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../http_options.dart';
import 'choice_row.dart';
import 'stream_form.dart';
import 'stream_row.dart';

/// Edits [HttpOptions]: a user agent, a list of request headers and a
/// chunk size. Reports every edit through [onChanged]; starts from
/// [initial].
class HttpOptionsPanel extends StatefulWidget {
  const HttpOptionsPanel({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final HttpOptions initial;
  final ValueChanged<HttpOptions> onChanged;

  @override
  State<HttpOptionsPanel> createState() => _HttpOptionsPanelState();
}

class _HeaderRow {
  _HeaderRow([HttpHeader? h])
    : name = TextEditingController(text: h?.name ?? ''),
      value = TextEditingController(text: h?.value ?? '');

  final TextEditingController name;
  final TextEditingController value;

  HttpHeader get header => HttpHeader(name.text, value.text);

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _HttpOptionsPanelState extends State<HttpOptionsPanel> {
  late final _userAgent = TextEditingController(text: widget.initial.userAgent);
  late final List<_HeaderRow> _rows = [
    for (final h in widget.initial.headers) _HeaderRow(h),
  ];
  late int? _chunkSize = widget.initial.chunkSize;

  @override
  void dispose() {
    _userAgent.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(
    HttpOptions(
      headers: [for (final r in _rows) r.header],
      userAgent: _userAgent.text,
      chunkSize: _chunkSize,
    ),
  );

  void _addRow() {
    setState(() => _rows.add(_HeaderRow()));
    _emit();
  }

  void _removeRow(int i) {
    final row = _rows.removeAt(i);
    setState(() {});
    // After the frame, so the removed fields detach before their
    // controllers go.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tokens.s12),
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.squircle(Tokens.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sent with this URL only. Proxy, cookies and certificates for '
            'every stream are in Settings, Network.',
            style: Tokens.label,
          ),
          const SizedBox(height: Tokens.s12),
          TextField(
            controller: _userAgent,
            onChanged: (_) => _emit(),
            autocorrect: false,
            enableSuggestions: false,
            style: streamFieldStyle,
            decoration: streamFieldDecoration(
              context,
              label: 'User agent',
              hint: 'Default (libmpv)',
              icon: Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: Tokens.s12),
          Text('Headers', style: Tokens.label.copyWith(color: Tokens.fg)),
          const SizedBox(height: Tokens.s8),
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.s8),
              child: _headerRow(i),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add header'),
              style: TextButton.styleFrom(foregroundColor: Tokens.accent),
            ),
          ),
          const SizedBox(height: Tokens.s8),
          ChoiceRow<int?>(
            label: 'Chunk size',
            selected: _chunkSize,
            choices: [
              for (final size in [null, ...HttpOptions.chunkSizes])
                Choice(size, size == null ? 'Off' : formatChunkSize(size)),
            ],
            onSelected: (size) {
              setState(() => _chunkSize = size);
              _emit();
            },
          ),
          const SizedBox(height: Tokens.s4),
          Text(
            'Fetches the stream in bounded range requests, for servers that '
            'slow down one long request.',
            style: Tokens.caption,
          ),
        ],
      ),
    );
  }

  Widget _headerRow(int i) {
    final row = _rows[i];
    String? nameError() {
      final n = row.name.text.trim();
      return n.isEmpty ? null : headerNameProblem(n);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: row.name,
            onChanged: (_) => setState(_emit),
            autocorrect: false,
            enableSuggestions: false,
            style: streamFieldStyle,
            decoration: streamFieldDecoration(
              context,
              label: 'Name',
            ).copyWith(errorText: nameError(), errorMaxLines: 2),
          ),
        ),
        const SizedBox(width: Tokens.s8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: row.value,
            onChanged: (_) => setState(_emit),
            autocorrect: false,
            enableSuggestions: false,
            style: streamFieldStyle,
            decoration: streamFieldDecoration(context, label: 'Value').copyWith(
              errorText: headerValueProblem(row.value.text),
              errorMaxLines: 2,
            ),
          ),
        ),
        RowButton(
          icon: Icons.close_rounded,
          tooltip: 'Remove header',
          onPressed: () => _removeRow(i),
        ),
      ],
    );
  }
}
