import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_header.dart';
import '../http_options.dart';
import 'choice_row.dart';
import 'stream_row.dart';

/// Edits [HttpOptions]: a user agent, a list of request headers and a
/// chunk size. Reports every edit through [onChanged]; starts from
/// [initial].
class HttpOptionsPanel extends StatefulWidget {
  const HttpOptionsPanel({
    super.key,
    required this.initial,
    required this.onChanged,
    this.globalUserAgent = false,
  });

  final HttpOptions initial;
  final ValueChanged<HttpOptions> onChanged;

  /// Whether Settings, Network sets a user agent for every stream (the one
  /// used when this one is empty).
  final bool globalUserAgent;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('HTTP options'),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.s16,
            vertical: Tokens.s4,
          ),
          decoration: ShapeDecoration(
            color: Tokens.surface,
            shape: Tokens.shape(Tokens.rLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingTile(
                title: 'User agent',
                description:
                    'Sent with this URL only. Proxy, cookies and '
                    'certificates for every stream are in Settings, Network.',
                below: AppTextField(
                  controller: _userAgent,
                  onChanged: (_) => _emit(),
                  label: 'User agent',
                  autocorrect: false,
                  enableSuggestions: false,
                  monospace: true,
                  hint: widget.globalUserAgent
                      ? 'Default (Settings, Network)'
                      : 'Default (libmpv)',
                ),
              ),
              SettingTile(
                title: 'Headers',
                below: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _rows.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.s8),
                        child: _headerRow(i),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Add header'),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Tokens.s16),
                child: ChoiceRow<int?>(
                  label: 'Chunk size',
                  description:
                      'Fetches the stream in bounded range requests, for '
                      'servers that slow down one long request.',
                  selected: _chunkSize,
                  choices: [
                    for (final size in [null, ...HttpOptions.chunkSizes])
                      Choice(
                        size,
                        size == null ? 'Off' : formatChunkSize(size),
                      ),
                  ],
                  onSelected: (size) {
                    setState(() => _chunkSize = size);
                    _emit();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerRow(int i) {
    final row = _rows[i];
    final n = row.name.text.trim();
    final problems = [
      if (n.isNotEmpty) ?headerNameProblem(n),
      ?headerValueProblem(row.value.text),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: AppTextField(
                controller: row.name,
                onChanged: (_) => setState(_emit),
                label: 'Header name',
                autocorrect: false,
                enableSuggestions: false,
                hint: 'Name',
                monospace: true,
              ),
            ),
            const SizedBox(width: Tokens.s8),
            Expanded(
              flex: 3,
              child: AppTextField(
                controller: row.value,
                onChanged: (_) => setState(_emit),
                label: 'Header value',
                autocorrect: false,
                enableSuggestions: false,
                hint: 'Value',
                monospace: true,
              ),
            ),
            const SizedBox(width: Tokens.s4),
            RowButton(
              icon: Icons.close_rounded,
              tooltip: 'Remove header',
              onPressed: () => _removeRow(i),
            ),
          ],
        ),
        for (final p in problems)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.s16,
              Tokens.s4,
              Tokens.s16,
              0,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(p, style: Tokens.label.copyWith(color: Tokens.red)),
            ),
          ),
      ],
    );
  }
}
