import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/player_scope.dart';
import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/round_icon_button.dart';
import '../../util/reactive.dart';
import 'completion_engine.dart';
import 'console_log.dart';
import 'console_runner.dart';
import 'hook_monitor.dart';
import 'suggestion_popup.dart';
import 'widgets/console_controls.dart';
import 'widgets/console_log_view.dart';
import 'widgets/console_side_panel.dart';
import '../../ui/widgets/studio_snack.dart';

/// The engine console of the app's player.
class ConsolePage extends StatelessWidget {
  const ConsolePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = PlayerScope.settingsOf(context);
    // One log level for the app: the setting's, recorded from here too,
    // and followed when Settings changes it.
    return ListenableBuilder(
      listenable: settings.changes,
      builder: (context, _) => ConsoleView(
        player: PlayerScope.of(context),
        log: PlayerScope.consoleLogOf(context),
        level: settings.logLevel,
        onLevel: settings.recordLogLevel,
      ),
    );
  }
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
  const ConsoleView({
    super.key,
    required this.player,
    required this.log,
    this.level = LogLevel.info,
    this.onLevel,
  });

  final PlayerApi player;

  /// The log captured since launch, so the Console starts with it.
  final ConsoleLog log;

  /// The log level to start at: the one the engine runs at.
  final LogLevel level;

  /// Records a level picked here, the app's single log level setting.
  final ValueChanged<LogLevel>? onLevel;

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
  /// Starts at the engine's configured level.
  late LogLevel _level = widget.level;
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

  /// The line being typed when Up went into the history, back on Down.
  String _draft = '';

  /// Whether the popup came from typing: then Up and Down move in it.
  /// A popup from a click or a recalled line leaves them to the history.
  bool _typed = false;

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
  void didUpdateWidget(ConsoleView old) {
    super.didUpdateWidget(old);
    // The level changed in Settings while the Console stayed alive.
    if (old.level != widget.level && widget.level != _level) {
      setState(() => _level = widget.level);
    }
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
      _jumpToEnd(3);
    });
  }

  /// Jumps to the end of the log. The lazy list only estimates its length
  /// until the rows near the end are laid out, and a wrapped row is taller
  /// than the estimate, so the jump repeats on the next frames (up to
  /// [tries] times) until it lands on the real end and the last line sits
  /// above the card's padding, not under the edge.
  void _jumpToEnd(int tries) {
    if (!mounted || !_autoscroll || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent) return;
    _scroll.jumpTo(position.maxScrollExtent);
    if (tries > 1) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpToEnd(tries - 1),
      );
    }
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
    widget.onLevel?.call(level);
  }

  /// Empties the log, with an undo that puts the lines back before the
  /// ones that came since.
  void _clear() {
    if (_lines.isEmpty) return;
    final cleared = List.of(_lines);
    setState(_lines.clear);
    showStudioSnack(
      context,
      'Log cleared',
      actionLabel: 'Undo',
      onAction: () {
        if (!mounted) return;
        setState(() {
          final since = List.of(_lines);
          _lines
            ..clear()
            ..addAll(cleared)
            ..addAll(since);
          while (_lines.length > _max) {
            _lines.removeFirst();
          }
        });
      },
    );
  }

  Future<void> _copyAll() async {
    final text = _lines.where(_visible).map((l) => l.plain).join('\n');
    if (text.isEmpty) {
      showStudioSnack(
        context,
        'Nothing to copy',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showStudioSnack(
      context,
      'Log copied',
      duration: const Duration(seconds: 2),
    );
  }

  /// The history newest first, in a menu; the line picked goes to the
  /// field. For the layouts without the side panel's history.
  Future<void> _pickHistory() async {
    final picked = await showStudioMenu<String>(
      context,
      title: 'Command history',
      items: [
        for (final line in _history.reversed.toSet())
          StudioMenuItem(value: line, label: line, icon: Icons.history),
      ],
    );
    if (picked == null || !mounted) return;
    _historyIndex = _history.length;
    _input.value = TextEditingValue(
      text: picked,
      selection: TextSelection.collapsed(offset: picked.length),
    );
    _inputFocus.requestFocus();
    _typed = false;
    _recompute();
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

  Future<void> _recompute({
    bool acceptSingle = false,
    VoidCallback? onNone,
  }) async {
    final text = _input.text;
    final cursor = _input.selection.baseOffset < 0
        ? text.length
        : _input.selection.baseOffset;
    final seq = ++_computeSeq;
    // Empty input is valid: it lists every command.
    final result = await _completion.compute(text, cursor);
    if (!mounted || seq != _computeSeq) return; // a newer keystroke won
    if (onNone != null && result.suggestions.isEmpty) {
      onNone();
      return;
    }
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
    if (_historyIndex == _history.length) _draft = _input.text;
    _historyIndex = next;
    _typed = false;
    final text = next == _history.length ? _draft : _history[next];
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    // The hint and the side panel follow the recalled command.
    _recompute();
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
      } else if (_input.text.trim().isEmpty) {
        // An empty line has nothing to complete: Tab moves on.
        node.nextFocus();
      } else {
        // Nothing to complete: Tab moves on, like everywhere else.
        _recompute(acceptSingle: true, onNone: node.nextFocus);
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
    final inPopup = popupOpen && _typed;
    if (key == LogicalKeyboardKey.arrowDown) {
      inPopup ? _moveSelection(1) : _recallHistory(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      inPopup ? _moveSelection(-1) : _recallHistory(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space &&
        HardwareKeyboard.instance.isControlPressed) {
      // The full list on demand, to move through with the arrows.
      _typed = true;
      _recompute();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- build -------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visible = _lines.where(_visible).toList(growable: false);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): _clear,
      },
      child: LayoutBuilder(
        builder: (context, page) {
          // With room for three columns the log keeps a reading width
          // and the commands stand beside it.
          final three =
              page.maxWidth - context.layout.pagePadding.horizontal >=
              Breakpoints.threeColumns;
          return PageFrame(
            title: 'Console',
            scrollable: false,
            maxWidth: three ? Breakpoints.full : Breakpoints.wide,
            actions: [
              RoundIconButton(
                onTap: () => setState(() => _autoscroll = !_autoscroll),
                active: _autoscroll,
                toggled: _autoscroll,
                label: 'Follow new lines',
                tooltip: _autoscroll ? 'Stop following' : 'Follow new lines',
                icon: Icons.vertical_align_bottom_rounded,
              ),
              RoundIconButton(
                onTap: _copyAll,
                tooltip: 'Copy the log',
                icon: Icons.copy_rounded,
                size: 20,
              ),
              RoundIconButton(
                onTap: _clear,
                tooltip: 'Clear the log',
                icon: Icons.delete_outline_rounded,
              ),
              RoundIconButton(
                onTap: _showHelp,
                tooltip: 'Console help',
                icon: Icons.help_outline_rounded,
              ),
            ],
            bottom: ConsoleFilterBar(
              search: _search,
              onSearch: (q) => setState(() => _query = q.toLowerCase()),
              level: _level,
              onLevel: _setLevel,
            ),
            // Keyed, so crossing the threshold keeps the field and its focus.
            body: three
                ? _withSide(KeyedSubtree(key: _bodyKey, child: _body(visible)))
                : KeyedSubtree(key: _bodyKey, child: _body(visible)),
          );
        },
      ),
    );
  }

  /// [log] with the side panel beside it.
  Widget _withSide(Widget log) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: log),
      SizedBox(width: context.layout.gap),
      SizedBox(
        width: _sideWidth,
        child: ConsoleSidePanel(
          history: _history,
          active: _completion.activeCommand(_input.text),
          onPick: (line) {
            _historyIndex = _history.length;
            _input.value = TextEditingValue(
              text: line,
              selection: TextSelection.collapsed(offset: line.length),
            );
            _inputFocus.requestFocus();
            _recompute();
          },
        ),
      ),
    ],
  );

  final _bodyKey = GlobalKey();

  /// The side panel's width.
  static const double _sideWidth = 360;

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
                    Tokens.s16,
                    Tokens.s8,
                    Tokens.s16,
                    0,
                  ),
                  child: Text(
                    '${activeCmd.name}  ${activeCmd.signature}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Tokens.numeric,
                  ),
                ),
              Padding(
                // A stable key: the hint above comes and goes, and the
                // field must keep its focus. The field ends the page, the
                // gutter above its edge.
                key: const ValueKey('console-input'),
                padding: EdgeInsets.only(
                  top: Tokens.s8,
                  bottom: PageEnd.of(context),
                ),
                child: ConsoleInput(
                  controller: _input,
                  focusNode: _inputFocus,
                  onTap: () {
                    _typed = false;
                    _recompute();
                  },
                  onChanged: (_) {
                    _typed = true;
                    _recompute();
                  },
                  onHistory: _history.isEmpty ? null : _pickHistory,
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
