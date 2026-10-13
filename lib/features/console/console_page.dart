import 'dart:collection';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/player_scope.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/controls.dart';
import '../../util/reactive.dart';
import 'completion_engine.dart';
import 'suggestion_popup.dart';

/// The engine console — a power tool, not just a log. The live mpv +
/// library log interleaved with a REPL: type a raw command (`seek 30`), or
/// `get <property>` / `set <property> <value>`; results land inline.
///
/// The input autocompletes Minecraft-style from mpv's own model
/// ([CompletionEngine]): commands, then properties/options, then enum
/// values. A verbosity selector raises mpv's runtime log level so the
/// console can surface everything from errors down to trace on demand.
class ConsolePage extends StatefulWidget {
  const ConsolePage({super.key});

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

enum _Kind { log, input, output, error }

class _Line {
  final _Kind kind;
  final LogLevel level;
  final String prefix;
  final String text;
  const _Line(
    this.kind,
    this.text, {
    this.level = LogLevel.info,
    this.prefix = '',
  });
}

class _ConsolePageState extends State<ConsolePage>
    with StreamListenerState<ConsolePage> {
  static const _max = 2000;
  static const _mono = TextStyle(
    fontFamily: Tokens.mono,
    fontSize: 12,
    height: 1.5,
    color: Tokens.fg,
  );

  late final Player _player;
  late final CompletionEngine _completion;

  final _lines = Queue<_Line>();
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _search = TextEditingController();
  late final FocusNode _inputFocus = FocusNode(onKeyEvent: _onKey);

  // Shared by the input box and the floating popup so a tap on either counts
  // as "inside" the group; a tap on the log (outside) dismisses both.
  final _inputGroup = Object();

  /// Selected log verbosity — both the level requested from mpv and the
  /// display floor. Starts at info (the engine's configured level).
  LogLevel _level = LogLevel.info;
  bool _autoscroll = true;
  bool _scrollScheduled = false;
  String _query = '';

  // Autocomplete state.
  CompletionResult _result = CompletionResult.empty;
  int _selected = 0;
  int _computeSeq = 0;

  // Command history (recalled with Up/Down when the popup is closed).
  final _history = <String>[];
  int _historyIndex = 0; // == _history.length means "current draft"

  @override
  void onSubscribe() {
    _player = PlayerScope.of(context);
    _completion = CompletionEngine(_player)..warmUp();
    // The engine log is captured app-wide from boot by [ConsoleLog], so the
    // Console isn't empty when opened mid-session. Seed from that backlog,
    // then follow live entries. (The buffer already enforces the same cap.)
    final log = PlayerScope.consoleLogOf(context);
    for (final e in log.backlog) {
      _lines.addLast(
        _Line(_Kind.log, e.text, level: e.level, prefix: e.prefix),
      );
    }
    _scheduleScrollToEnd();
    listen(
      log.entries,
      (e) => _add(_Line(_Kind.log, e.text, level: e.level, prefix: e.prefix)),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _search.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ---- log buffer --------------------------------------------------

  void _add(_Line line) {
    if (!mounted) return;
    setState(() {
      _lines.addLast(line);
      while (_lines.length > _max) {
        _lines.removeFirst();
      }
    });
    _scheduleScrollToEnd();
  }

  /// Jump to the newest line after the next frame. Coalesced: a flood of
  /// lines can land many times per frame (ffmpeg debug spam), and scheduling
  /// one post-frame callback each would stack hundreds of redundant jumps.
  /// One pending jump per frame is enough — it always targets the latest
  /// maxScrollExtent.
  void _scheduleScrollToEnd() {
    if (!_autoscroll || _scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  // Severity rank: lower = more severe.
  static int _severity(LogLevel l) => switch (l) {
    LogLevel.fatal => 0,
    LogLevel.error => 1,
    LogLevel.warn => 2,
    LogLevel.info => 4,
    LogLevel.v => 5,
    LogLevel.debug => 6,
    LogLevel.trace => 7,
    LogLevel.off => 8,
  };

  bool _visible(_Line l) {
    if (l.kind == _Kind.log && _severity(l.level) > _severity(_level)) {
      return false;
    }
    if (_query.isNotEmpty &&
        !l.text.toLowerCase().contains(_query.toLowerCase()) &&
        !l.prefix.toLowerCase().contains(_query.toLowerCase())) {
      return false;
    }
    return true;
  }

  void _setLevel(LogLevel level) {
    setState(() => _level = level);
    // Ask mpv to actually emit down to this level (the display filter
    // alone can't reveal messages the engine never sent).
    _player.setLogLevel(level);
  }

  Color _color(_Line l) {
    switch (l.kind) {
      case _Kind.input:
        return Tokens.accent;
      case _Kind.error:
        return Tokens.red;
      case _Kind.output:
        return Tokens.fg;
      case _Kind.log:
        switch (l.level) {
          case LogLevel.fatal:
          case LogLevel.error:
            return Tokens.red;
          case LogLevel.warn:
            return Tokens.amber;
          case LogLevel.info:
            return Tokens.fgDim;
          default:
            return Tokens.fgFaint;
        }
    }
  }

  // ---- REPL --------------------------------------------------------

  Future<void> _run(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    _add(_Line(_Kind.input, '› $text'));
    _history
      ..remove(text)
      ..add(text);
    _historyIndex = _history.length;
    _input.clear();
    _closePopup();
    _inputFocus.requestFocus();

    final tokens = text.split(RegExp(r'\s+'));
    try {
      if (tokens.first == 'get' && tokens.length >= 2) {
        final prop = tokens[1];
        final value = await _player.getRawProperty(prop);
        _add(_Line(_Kind.output, '$prop = ${value ?? '<null>'}'));
      } else if (tokens.first == 'set' && tokens.length >= 3) {
        final prop = tokens[1];
        final value = tokens.sublist(2).join(' ');
        await _player.setRawProperty(prop, value);
        _add(_Line(_Kind.output, '$prop = $value'));
      } else {
        await _player.sendRawCommand(tokens);
        _add(const _Line(_Kind.output, 'ok'));
      }
    } catch (e) {
      _add(_Line(_Kind.error, e.toString()));
    }
  }

  void _copyAll() {
    final text = _lines
        .where(_visible)
        .map(
          (l) => l.kind == _Kind.log && l.prefix.isNotEmpty
              ? '[${l.prefix}] ${l.text}'
              : l.text,
        )
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
  }

  // ---- autocomplete ------------------------------------------------

  Future<void> _recompute() async {
    final text = _input.text;
    final cursor = _input.selection.baseOffset < 0
        ? text.length
        : _input.selection.baseOffset;
    final seq = ++_computeSeq;
    // Empty input is valid: it yields the whole command catalog.
    final result = await _completion.compute(text, cursor);
    if (!mounted || seq != _computeSeq) return; // a newer keystroke won
    setState(() {
      _result = result;
      if (_selected >= result.suggestions.length) _selected = 0;
      if (_selected < 0) _selected = 0;
    });
  }

  void _closePopup() {
    if (_result.isEmpty) return;
    setState(() {
      _result = CompletionResult.empty;
      _selected = 0;
    });
  }

  /// Tap landed outside the input/popup group: close the popup (if open) and
  /// drop focus. Idempotent — it can fire once per region in the group.
  void _dismiss() {
    if (_result.suggestions.isNotEmpty) _closePopup();
    if (_inputFocus.hasFocus) _inputFocus.unfocus();
  }

  void _moveSelection(int delta) {
    final n = _result.suggestions.length;
    if (n == 0) return;
    setState(
      () => _selected = (_selected + delta) % n < 0
          ? (_selected + delta) % n + n
          : (_selected + delta) % n,
    );
  }

  void _accept(int index) {
    final s = _result.suggestions[index];
    final text = _input.text;
    // Values usually end the line; commands/properties get a trailing
    // space so the next token can be typed (or completed) straight away.
    final trailing = s.kind == SuggestionKind.value ? '' : ' ';
    final prefix = text.substring(0, _result.tokenStart);
    final suffix = text.substring(_result.tokenEnd);
    final composed = '$prefix${s.insertText}$trailing$suffix';
    final caret = prefix.length + s.insertText.length + trailing.length;
    _input.value = TextEditingValue(
      text: composed,
      selection: TextSelection.collapsed(offset: caret),
    );
    _inputFocus.requestFocus(); // keep focus after a popup-row tap
    _recompute(); // surface the next argument's completions
  }

  // ---- history -----------------------------------------------------

  void _recallHistory(int delta) {
    if (_history.isEmpty) return;
    final next = (_historyIndex + delta).clamp(0, _history.length);
    if (next == _historyIndex) return;
    _historyIndex = next;
    final text = next == _history.length ? '' : _history[next];
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  // ---- keyboard ----------------------------------------------------

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final popupOpen = _result.suggestions.isNotEmpty;

    if (key == LogicalKeyboardKey.tab) {
      if (popupOpen) {
        _accept(_selected);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (popupOpen) {
        _closePopup();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (popupOpen) {
        _moveSelection(1);
      } else {
        _recallHistory(1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (popupOpen) {
        _moveSelection(-1);
      } else {
        _recallHistory(-1);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- build -------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Toolbar(
          level: _level,
          onLevel: _setLevel,
          search: _search,
          onSearch: (q) => setState(() => _query = q),
          autoscroll: _autoscroll,
          onAutoscroll: () => setState(() => _autoscroll = !_autoscroll),
          onClear: () => setState(_lines.clear),
          onCopy: _copyAll,
        ),
        Expanded(child: _buildConsole()),
      ],
    );
  }

  Widget _buildConsole() {
    final visible = _lines.where(_visible).toList(growable: false);
    final activeCmd = _completion.activeCommand(_input.text);
    final showPopup = _result.suggestions.isNotEmpty;
    final showHint =
        !showPopup && activeCmd != null && activeCmd.signature.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          _query.isNotEmpty
                              ? 'No lines match “$_query”.'
                              : 'No log output yet.',
                          style: Tokens.caption,
                        ),
                      )
                    // One SelectionArea for the whole log keeps text drag-select
                    // (across rows) without making each row a SelectableText.
                    // Per-row SelectableText registers every line as a read-only
                    // text field in the semantics tree; under a high-frequency
                    // log flood that two-pane semantics layout fights
                    // SliverList's offset estimation and throws "RenderViewport
                    // exceeded its maximum number of layout cycles". Plain Text
                    // rows avoid that entirely.
                    : SelectionArea(
                        // Drop the mouse from this list's drag devices so a
                        // mouse drag selects log text (the whole point of the
                        // SelectionArea) instead of scrolling — the app-wide
                        // mouse drag-to-scroll would otherwise win the gesture.
                        // The wheel/trackpad still scroll normally.
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: const {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.trackpad,
                              PointerDeviceKind.stylus,
                              PointerDeviceKind.unknown,
                            },
                          ),
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(
                              Tokens.s16,
                              Tokens.s8,
                              Tokens.s16,
                              Tokens.s4,
                            ),
                            itemCount: visible.length,
                            itemBuilder: (context, i) => _logRow(visible[i]),
                          ),
                        ),
                      ),
              ),
              // The autocomplete popup FLOATS over the bottom of the log,
              // anchored directly above the command box. It grows upward and is
              // bounded by this area's height (the Stack), so a tall list
              // scrolls inside itself rather than pushing the box down behind
              // the keyboard. The box always keeps its place; the popup adapts.
              if (showPopup)
                Positioned.fill(
                  // Fill so the popup is bounded by the log area's height; the
                  // bottom Align pins it just above the box while letting it
                  // size to content (and scroll) up to that bound.
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TapRegion(
                      groupId: _inputGroup,
                      onTapOutside: (_) => _dismiss(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Tokens.s16,
                          0,
                          Tokens.s16,
                          0,
                        ),
                        child: SuggestionPopup(
                          suggestions: _result.suggestions,
                          selected: _selected,
                          tokenSoFar: _result.tokenSoFar,
                          onTap: _accept,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // The signature hint and the command box share one tap region (grouped
        // with the floating popup above): tapping the box or a suggestion row
        // keeps the popup open; tapping the log dismisses it and drops focus.
        // The single-line hint stays in flow (it can't overflow the column),
        // sitting just above the box with the same inset.
        TapRegion(
          groupId: _inputGroup,
          onTapOutside: (_) => _dismiss(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHint)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.s24,
                    0,
                    Tokens.s16,
                    Tokens.s4,
                  ),
                  child: Text(
                    '${activeCmd.name}  ${activeCmd.signature}',
                    style: Tokens.caption.copyWith(fontFamily: Tokens.mono),
                  ),
                ),
              _inputBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logRow(_Line l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text.rich(
        TextSpan(
          style: _mono,
          children: [
            if (l.kind == _Kind.log) ...[
              TextSpan(
                text: '${l.level.mpvValue.padRight(5)} ',
                style: _mono.copyWith(color: _color(l)),
              ),
              if (l.prefix.isNotEmpty)
                TextSpan(
                  text: '${l.prefix}: ',
                  style: _mono.copyWith(color: Tokens.fgFaint),
                ),
              TextSpan(text: l.text),
            ] else
              TextSpan(
                text: l.text,
                style: _mono.copyWith(color: _color(l)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    // The prompt now lives inside the box, so the box spans the full width
    // and lines up exactly with the popup above and the log inset.
    //
    // Stable key: the popup is inserted *before* this in the column, which
    // shifts the input from index 0 to 1. Without a key, Flutter's
    // position-based reconciliation would rebuild the TextField element and
    // detach its FocusNode — so opening the popup would steal focus.
    return Padding(
      key: const ValueKey('console-input'),
      padding: const EdgeInsets.fromLTRB(
        Tokens.s16,
        Tokens.s8,
        Tokens.s16,
        Tokens.s12,
      ),
      child: Container(
        height: Tokens.controlH,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
        decoration: ShapeDecoration(
          color: Tokens.surface2,
          shape: Tokens.squircle(Tokens.rSm),
        ),
        child: Row(
          children: [
            const Text(
              '›',
              style: TextStyle(color: Tokens.accent, fontSize: 16),
            ),
            const SizedBox(width: Tokens.s8),
            Expanded(
              // Content-sized so the Row centres it vertically in the pill.
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                style: const TextStyle(
                  fontFamily: Tokens.mono,
                  fontSize: 12.5,
                  color: Tokens.fg,
                ),
                cursorColor: Tokens.accent,
                textInputAction: TextInputAction.send,
                // Opens on click / typing; the outer TapRegion owns closing.
                // No-op here so tapping a popup row doesn't drop focus first.
                onTapOutside: (_) {},
                onTap: () => _recompute(),
                onChanged: (_) => _recompute(),
                onSubmitted: _run,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'command',
                  hintStyle: Tokens.caption,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final LogLevel level;
  final ValueChanged<LogLevel> onLevel;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final bool autoscroll;
  final VoidCallback onAutoscroll;
  final VoidCallback onClear;
  final VoidCallback onCopy;

  const _Toolbar({
    required this.level,
    required this.onLevel,
    required this.search,
    required this.onSearch,
    required this.autoscroll,
    required this.onAutoscroll,
    required this.onClear,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final levels = SegmentedControl<LogLevel>(
      expand: false,
      selected: level,
      onSelect: onLevel,
      options: const [
        SegmentOption(LogLevel.error, 'Err'),
        SegmentOption(LogLevel.warn, 'Warn'),
        SegmentOption(LogLevel.info, 'Info'),
        SegmentOption(LogLevel.v, 'Verbose'),
        SegmentOption(LogLevel.debug, 'Debug'),
        SegmentOption(LogLevel.trace, 'Trace'),
      ],
    );
    final searchField = _SearchField(controller: search, onChanged: onSearch);
    final actions = <Widget>[
      IconButton(
        onPressed: onAutoscroll,
        icon: Icon(
          autoscroll
              ? Icons.vertical_align_bottom_rounded
              : Icons.vertical_align_center_rounded,
          size: 18,
        ),
        color: autoscroll ? Tokens.accent : Tokens.fgDim,
        tooltip: 'Autoscroll',
        splashRadius: 18,
      ),
      IconButton(
        onPressed: onCopy,
        icon: const Icon(Icons.copy_rounded, size: 16),
        color: Tokens.fgDim,
        tooltip: 'Copy',
        splashRadius: 18,
      ),
      IconButton(
        onPressed: onClear,
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        color: Tokens.fgDim,
        tooltip: 'Clear',
        splashRadius: 18,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.s16,
        Tokens.s8,
        Tokens.s8,
        Tokens.s8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The 6-segment level filter + search + actions don't fit one row
          // on a phone. Above the breakpoint keep the single toolbar row;
          // below it, drop the level filter to its own row that scrolls
          // horizontally so it never overflows.
          if (constraints.maxWidth >= 560) {
            return Row(
              children: [
                levels,
                const SizedBox(width: Tokens.s12),
                Expanded(child: searchField),
                const SizedBox(width: Tokens.s4),
                ...actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: Tokens.s4),
                  ...actions,
                ],
              ),
              const SizedBox(height: Tokens.s8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: levels,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact log search box (top-right). Filters the scrollback live; a clear
/// affordance appears once there's a query.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      height: Tokens.controlH,
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.squircle(Tokens.rSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s8),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 15, color: Tokens.fgFaint),
          const SizedBox(width: Tokens.s6),
          Expanded(
            // Content-sized so the Row centres it vertically in the pill.
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: Tokens.mono,
                fontSize: 12,
                color: Tokens.fg,
              ),
              cursorColor: Tokens.accent,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search log',
                hintStyle: Tokens.caption,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : InkWell(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Tokens.fgFaint,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
