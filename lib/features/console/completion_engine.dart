import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'command_catalog.dart';

/// What a suggestion represents — drives the popup's per-row accent.
enum SuggestionKind { command, property, value }

/// One row in the autocomplete popup.
class Suggestion {
  /// Text shown in the row.
  final String label;

  /// Text that replaces the current token when accepted.
  final String insertText;

  /// Right-hand detail — for a command, its argument signature (the
  /// parameters that follow once you start typing it); for a property/value,
  /// a short type tag.
  final String? detail;

  /// Sub-line shown under [label] — a command's one-line description. Null
  /// for properties/values, which have no doc.
  final String? description;

  final SuggestionKind kind;

  const Suggestion({
    required this.label,
    required this.insertText,
    this.detail,
    this.description,
    required this.kind,
  });
}

/// Result of [CompletionEngine.compute]: the ranked suggestions plus the
/// `[tokenStart, tokenEnd)` range in the input that accepting one replaces,
/// and the partial token typed so far (so the popup can bold the match).
class CompletionResult {
  final List<Suggestion> suggestions;
  final int tokenStart;
  final int tokenEnd;
  final String tokenSoFar;

  const CompletionResult({
    required this.suggestions,
    required this.tokenStart,
    required this.tokenEnd,
    required this.tokenSoFar,
  });

  static const empty = CompletionResult(
    suggestions: [],
    tokenStart: 0,
    tokenEnd: 0,
    tokenSoFar: '',
  );

  bool get isEmpty => suggestions.isEmpty;
}

/// Computes console autocompletions from mpv's own model — exactly the
/// sources mpv's built-in console uses:
///
/// * **commands** come from the embedded [kMpvCommands] catalog (mpv's
///   `command-list` is a NODE, not reachable as a string through the
///   client API, but the set is stable and ships in [command_catalog.dart]);
/// * **properties / options** are fetched live from the running engine via
///   the `property-list` and `options` properties (both string-lists), so
///   the catalog always matches the actual libmpv build;
/// * **values** for `set`/`add`/`cycle <prop>` come from
///   `option-info/<name>/choices` (and `/type` for flags), so enum-valued
///   properties complete their allowed values.
///
/// Lists are fetched once and cached; value choices are fetched lazily per
/// property and cached.
class CompletionEngine {
  CompletionEngine(this.player);

  final Player player;

  List<String> _properties = const [];
  List<String> _options = const [];
  final Map<String, List<String>> _choices = {};
  bool _warmedUp = false;

  /// `get` is a console-REPL verb (read a property), not an mpv command,
  /// but it completes a property just like `set`/`cycle` do.
  static const _virtualGet = 'get';

  /// Commands whose first argument is a property/option name.
  static const _propertyArgCommands = {
    'set',
    'add',
    'cycle',
    'multiply',
    'del',
    _virtualGet,
  };

  /// Commands whose value token (after the property) has enum choices.
  static const _valueArgCommands = {'set', 'add', 'cycle'};

  /// Fetch the property and option lists once. Safe to call repeatedly.
  Future<void> warmUp() async {
    if (_warmedUp) return;
    _warmedUp = true;
    _properties = await _fetchList('property-list');
    _options = await _fetchList('options');
  }

  Future<List<String>> _fetchList(String property) async {
    try {
      final raw = await player.getRawProperty(property);
      if (raw == null || raw.isEmpty) return const [];
      final set = <String>{
        for (final e in raw.split(','))
          if (e.trim().isNotEmpty) e.trim(),
      };
      return set.toList()..sort();
    } catch (_) {
      return const [];
    }
  }

  /// The command being typed, for the input bar's inline signature hint —
  /// null until a full command word followed by a space is present.
  MpvCommand? activeCommand(String input) {
    final trimmed = input.trimLeft();
    final firstSpace = trimmed.indexOf(' ');
    if (firstSpace < 0) return null; // still typing the command itself
    final name = trimmed.substring(0, firstSpace);
    for (final c in kMpvCommands) {
      if (c.name == name) return c;
    }
    return null;
  }

  Future<CompletionResult> compute(String input, int cursor) async {
    final at = cursor.clamp(0, input.length);
    final (start, end) = _tokenRange(input, at);
    final tokenSoFar = input.substring(start, at);

    // Which token position is the cursor in? Count whitespace-separated
    // words strictly before the current token.
    final before = input.substring(0, start);
    final prior = before.trim().isEmpty
        ? const <String>[]
        : before.trim().split(RegExp(r'\s+'));
    final index = prior.length;

    List<Suggestion> out;
    if (index == 0) {
      out = _commands(tokenSoFar);
    } else {
      final cmd = prior.first;
      if (_propertyArgCommands.contains(cmd) && index == 1) {
        out = _propsAndOptions(tokenSoFar, includeOptions: cmd != _virtualGet);
      } else if (_valueArgCommands.contains(cmd) && index == 2) {
        out = await _values(prior[1], tokenSoFar);
      } else {
        out = const [];
      }
    }

    return CompletionResult(
      suggestions: out,
      tokenStart: start,
      tokenEnd: end,
      tokenSoFar: tokenSoFar,
    );
  }

  // ── Sources ────────────────────────────────────────────────────────

  List<Suggestion> _commands(String prefix) {
    final items = [
      const Suggestion(
        label: _virtualGet,
        insertText: _virtualGet,
        detail: '<property>',
        description: 'Read a property value',
        kind: SuggestionKind.command,
      ),
      for (final c in kMpvCommands)
        Suggestion(
          label: c.name,
          insertText: c.name,
          detail: c.signature.isEmpty ? null : c.signature,
          description: c.doc.isEmpty ? null : c.doc,
          kind: SuggestionKind.command,
        ),
    ];
    return _rank(items, prefix);
  }

  List<Suggestion> _propsAndOptions(
    String prefix, {
    required bool includeOptions,
  }) {
    final seen = <String>{};
    final items = <Suggestion>[];
    for (final p in _properties) {
      if (seen.add(p)) {
        items.add(
          Suggestion(
            label: p,
            insertText: p,
            detail: 'property',
            kind: SuggestionKind.property,
          ),
        );
      }
    }
    if (includeOptions) {
      for (final o in _options) {
        if (seen.add(o)) {
          items.add(
            Suggestion(
              label: o,
              insertText: o,
              detail: 'option',
              kind: SuggestionKind.property,
            ),
          );
        }
      }
    }
    return _rank(items, prefix);
  }

  Future<List<Suggestion>> _values(String property, String prefix) async {
    final choices = await _choicesFor(property);
    if (choices.isEmpty) return const [];
    final items = [
      for (final v in choices)
        Suggestion(
          label: v,
          insertText: v,
          detail: 'value',
          kind: SuggestionKind.value,
        ),
    ];
    return _rank(items, prefix);
  }

  Future<List<String>> _choicesFor(String property) async {
    final cached = _choices[property];
    if (cached != null) return cached;
    var choices = await _fetchList('option-info/$property/choices');
    if (choices.isEmpty) {
      // Flags have no `choices` list but accept yes/no.
      try {
        final type = await player.getRawProperty('option-info/$property/type');
        if (type == 'Flag') choices = const ['yes', 'no'];
      } catch (_) {
        /* leave empty */
      }
    }
    _choices[property] = choices;
    return choices;
  }

  // ── Ranking & tokenisation ──────────────────────────────────────────

  /// Prefix matches first (then substring), case-insensitive, capped so the
  /// popup stays snappy. The cap is generous enough to show the entire
  /// command set (≈86) when the prefix is empty — the popup scrolls.
  static List<Suggestion> _rank(List<Suggestion> items, String prefix) {
    const limit = 300;
    if (prefix.isEmpty) return items.take(limit).toList();
    final p = prefix.toLowerCase();
    final starts = <Suggestion>[];
    final contains = <Suggestion>[];
    for (final s in items) {
      final l = s.label.toLowerCase();
      if (l.startsWith(p)) {
        starts.add(s);
      } else if (l.contains(p)) {
        contains.add(s);
      }
    }
    return [...starts, ...contains].take(limit).toList();
  }

  /// The `[start, end)` range of the whitespace-delimited token the cursor
  /// sits in — the region accepting a completion replaces.
  static (int, int) _tokenRange(String input, int cursor) {
    var start = cursor;
    while (start > 0 && input[start - 1] != ' ') {
      start--;
    }
    var end = cursor;
    while (end < input.length && input[end] != ' ') {
      end++;
    }
    return (start, end);
  }
}
