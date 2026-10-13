import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/player_scope.dart';
import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../util/reactive.dart';
import 'completion_engine.dart';
import 'console_log.dart';
import 'console_runner.dart';
import 'hook_monitor.dart';
import 'suggestion_popup.dart';
import 'widgets/console_controls.dart';
import 'widgets/console_log_view.dart';

/// The engine console of the app's player.
class ConsolePage extends StatelessWidget {
  const ConsolePage({super.key});

  @override
  Widget build(BuildContext context) => ConsoleView(
    player: PlayerScope.of(context),
    log: PlayerScope.consoleLogOf(context),
  );
}

/// The engine console: the live mpv and library log with a command line.
/// Type a raw mpv command (`seek 30`), `get`, `getnode` or `set` a
/// property, `hooks on`, or `help`; answers land inline. Commands that
/// change what plays go through the Player API (see [ConsoleRunner]).
///
/// The command line completes from mpv's own model ([CompletionEngine]):
/// commands, then properties and options, then values. The level filter
/// also raises mpv's runtime log level, so the log can show everything
/// from errors down to trace.
class ConsoleView extends StatefulWidget {
  const ConsoleView({super.key, required this.player, required this.log});

  final PlayerApi player;

  /// The log captured since launch, so the Console starts with it.
  final ConsoleLog log;

  @override
  State<ConsoleView> createState() => _ConsoleViewState();
}

class _ConsoleViewState extends State<ConsoleView>
    with StreamListenerState<ConsoleView> {
  static const _max = 2000;

  late final CompletionEngine _completion;
  late final ConsoleRunner _runner;

  final _lines = Queue<ConsoleLine>();
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _search = TextEditingController();
  late final FocusNode _inputFocus = FocusNode(onKeyEvent: _onKey);

  // Shared by the command field and the popup so a tap on either counts
  // as inside; a tap on the log closes the popup.
  final _inputGroup = Object();

  /// The selected verbosity: the level asked of mpv and the display floor.
  /// Starts at info, the engine's configured level.
  LogLevel _level = LogLevel.info;
  bool _autoscroll = true;
  bool _scrollScheduled = false;
  String _query = '';

  CompletionResult _result = CompletionResult.empty;
  int _selected = 0;
  int _computeSeq = 0;

  /// Earlier lines, recalled with Up and Down when the popup is closed.
  final _history = <String>[];

  /// `_history.length` stands for the line being typed.
  int _historyIndex = 0;

  @override
  void onSubscribe() {
    _completion = CompletionEngine(widget.player)..warmUp();
    _runner = ConsoleRunner(widget.player);
    for (final e in widget.log.backlog) {
      _lines.addLast(ConsoleLine.log(e));
    }
    _scheduleScrollToEnd();
    listen(widget.log.entries, (e) => _add(ConsoleLine.log(e)));
    listen(
      HookMonitor.of(widget.player).reports,
      (r) => _add(
        r.continued
            ? ConsoleLine(
                ConsoleLineKind.output,
                'hook ${r.event.hook.mpvValue} (id ${r.event.id}), continued',
              )
            : ConsoleLine(
                ConsoleLineKind.error,
                'hook ${r.event.hook.mpvValue} (id ${r.event.id}) could not '
                'be continued; mpv waits for its timeout',
              ),
      ),
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

  void _add(ConsoleLine line) {
    if (!mounted) return;
    setState(() {
      _lines.addLast(line);
      while (_lines.length > _max) {
        _lines.removeFirst();
      }
    });
    _scheduleScrollToEnd();
  }

  /// Jumps to the newest line after the next frame, once per frame however
  /// many lines arrive in it.
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

  bool _visible(ConsoleLine l) {
    if (l.kind == ConsoleLineKind.log &&
        logSeverity(l.level) > logSeverity(_level)) {
      return false;
    }
    return l.matches(_query);
  }

  void _setLevel(LogLevel level) {
    setState(() => _level = level);
    // The display filter alone cannot show lines mpv never sent.
    widget.player.setLogLevel(level);
  }

  void _clear() => setState(_lines.clear);

  Future<void> _copyAll() async {
    final text = _lines.where(_visible).map((l) => l.plain).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Log copied', style: TextStyle(color: Tokens.fg)),
          backgroundColor: Tokens.surface3,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _showHelp() => showStudioDialog<void>(
    context,
    title: 'Console help',
    maxWidth: 640,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in kConsoleHelp)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.s12),
            child: Text(p, style: Tokens.body),
          ),
        Text(
          'Keys: Enter runs, Tab completes, Up and Down recall, Escape '
          'closes the suggestions, Ctrl+L clears the log.',
          style: Tokens.caption,
        ),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );

  // ---- commands ----------------------------------------------------

  Future<void> _run(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    _add(ConsoleLine(ConsoleLineKind.input, '› $text'));
    _history
      ..remove(text)
      ..add(text);
    _historyIndex = _history.length;
    _input.clear();
    _closePopup();
    _inputFocus.requestFocus();
    for (final r in await _runner.run(text)) {
      _add(
        ConsoleLine(switch (r.kind) {
          ConsoleResultKind.output => ConsoleLineKind.output,
          ConsoleResultKind.routed => ConsoleLineKind.routed,
          ConsoleResultKind.error => ConsoleLineKind.error,
        }, r.text),
      );
    }
  }

  // ---- completion --------------------------------------------------

  Future<void> _recompute({bool acceptSingle = false}) async {
    final text = _input.text;
    final cursor = _input.selection.baseOffset < 0
        ? text.length
        : _input.selection.baseOffset;
    final seq = ++_computeSeq;
    // Empty input is valid: it lists every command.
    final result = await _completion.compute(text, cursor);
    if (!mounted || seq != _computeSeq) return; // a newer keystroke won
    if (acceptSingle && result.suggestions.length == 1) {
      _result = result;
      _accept(0);
      return;
    }
    setState(() {
      _result = result;
      if (_selected >= result.suggestions.length || _selected < 0) {
        _selected = 0;
      }
    });
  }

  void _closePopup() {
    if (_result.isEmpty) return;
    setState(() {
      _result = CompletionResult.empty;
      _selected = 0;
    });
  }

  /// A tap outside the field and the popup: close the popup and drop the
  /// focus.
  void _dismiss() {
    _closePopup();
    if (_inputFocus.hasFocus) _inputFocus.unfocus();
  }

  void _moveSelection(int delta) {
    final n = _result.suggestions.length;
    if (n == 0) return;
    setState(() => _selected = (_selected + delta) % n);
  }

  void _accept(int index) {
    final s = _result.suggestions[index];
    final text = _input.text;
    // Values usually end the line; commands and properties get a space so
    // the next argument can be typed (or completed) straight away.
    final trailing = s.kind == SuggestionKind.value ? '' : ' ';
    final prefix = text.substring(0, _result.tokenStart);
    final suffix = text.substring(_result.tokenEnd);
    final composed = '$prefix${s.insertText}$trailing$suffix';
    final caret = prefix.length + s.insertText.length + trailing.length;
    _input.value = TextEditingValue(
      text: composed,
      selection: TextSelection.collapsed(offset: caret),
    );
    _inputFocus.requestFocus();
    _recompute();
  }

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

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final popupOpen = _result.suggestions.isNotEmpty;
    if (key == LogicalKeyboardKey.tab) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      if (popupOpen) {
        _accept(_selected);
      } else {
        _recompute(acceptSingle: true);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && popupOpen) {
      _closePopup();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && popupOpen) {
      // Enter runs the line; the suggestions are not picked by it.
      _closePopup();
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      popupOpen ? _moveSelection(1) : _recallHistory(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      popupOpen ? _moveSelection(-1) : _recallHistory(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- build -------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final tap = BoxConstraints.tightFor(
      width: layout.minTap,
      height: layout.minTap,
    );
    final visible = _lines.where(_visible).toList(growable: false);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): _clear,
      },
      child: PageFrame(
        title: 'Console',
        scrollable: false,
        maxWidth: Breakpoints.wide,
        actions: [
          IconButton(
            onPressed: () => setState(() => _autoscroll = !_autoscroll),
            isSelected: _autoscroll,
            tooltip: _autoscroll ? 'Stop following' : 'Follow new lines',
            icon: const Icon(Icons.vertical_align_bottom_rounded),
            color: _autoscroll ? Tokens.accent : Tokens.fgDim,
            constraints: tap,
          ),
          IconButton(
            onPressed: _copyAll,
            tooltip: 'Copy the log',
            icon: const Icon(Icons.copy_rounded, size: 20),
            color: Tokens.fgDim,
            constraints: tap,
          ),
          IconButton(
            onPressed: _clear,
            tooltip: 'Clear the log',
            icon: const Icon(Icons.delete_outline_rounded),
            color: Tokens.fgDim,
            constraints: tap,
          ),
          IconButton(
            onPressed: _showHelp,
            tooltip: 'Console help',
            icon: const Icon(Icons.help_outline_rounded),
            color: Tokens.fgDim,
            constraints: tap,
          ),
        ],
        bottom: ConsoleFilterBar(
          search: _search,
          onSearch: (q) => setState(() => _query = q.toLowerCase()),
          level: _level,
          onLevel: _setLevel,
        ),
        // The page bottom padding would float the command line; keep it
        // near the edge (and so near the keyboard).
        padding: layout.pagePadding.copyWith(bottom: Tokens.s8),
        body: _body(visible),
      ),
    );
  }

  Widget _body(List<ConsoleLine> visible) {
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
                child: ConsoleLogView(
                  lines: visible,
                  controller: _scroll,
                  emptyText: _query.isNotEmpty
                      ? 'No lines match "${_search.text}".'
                      : 'No log output yet. Type help to start.',
                ),
              ),
              // The popup floats over the bottom of the log, right above
              // the command line, and is bounded by the log area: it never
              // pushes the field down behind the keyboard, it scrolls.
              if (showPopup)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TapRegion(
                      groupId: _inputGroup,
                      onTapOutside: (_) => _dismiss(),
                      child: SuggestionPopup(
                        suggestions: _result.suggestions,
                        selected: _selected,
                        tokenSoFar: _result.tokenSoFar,
                        onTap: _accept,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
                    Tokens.s8,
                    Tokens.s4,
                    Tokens.s8,
                    0,
                  ),
                  child: Text(
                    '${activeCmd.name}  ${activeCmd.signature}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Tokens.caption.copyWith(fontFamily: Tokens.mono),
                  ),
                ),
              Padding(
                // A stable key: the hint above comes and goes, and the
                // field must keep its focus.
                key: const ValueKey('console-input'),
                padding: const EdgeInsets.only(top: Tokens.s8),
                child: ConsoleInput(
                  controller: _input,
                  focusNode: _inputFocus,
                  onTap: _recompute,
                  onChanged: (_) => _recompute(),
                  onSubmitted: _run,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
