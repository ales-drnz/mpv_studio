import 'dart:convert';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'console_tokenizer.dart';
import 'hook_monitor.dart';

/// mpv's command prefixes (`no-osd`, `expand-properties`...), which may
/// precede any command.
const kCommandPrefixes = {
  'no-osd',
  'osd-auto',
  'osd-bar',
  'osd-msg',
  'osd-msg-bar',
  'raw',
  'expand-properties',
  'repeatable',
  'nonrepeatable',
  'nonscalable',
  'async',
  'sync',
};

/// The Console's own verbs, beside mpv's commands.
const kConsoleVerbs = {
  'get': ('<property>', 'Read a property as text'),
  'getnode': ('<property>', 'Read a property as structured data'),
  'help': ('', 'Show how the Console works'),
  'hooks': ('[on|off]', 'Report the file lifecycle hooks as they fire'),
};

/// How a console line was handled.
enum ConsoleResultKind { output, routed, error }

/// One line of a command's answer.
class ConsoleResult {
  const ConsoleResult(this.kind, this.text);
  const ConsoleResult.output(this.text) : kind = ConsoleResultKind.output;
  const ConsoleResult.routed(this.text) : kind = ConsoleResultKind.routed;
  const ConsoleResult.error(this.text) : kind = ConsoleResultKind.error;

  final ConsoleResultKind kind;
  final String text;

  @override
  String toString() => 'ConsoleResult($kind, $text)';
}

/// The Console help, one paragraph per entry.
const kConsoleHelp = [
  'Type an mpv command, such as seek 30 or cycle mute. Tab completes '
      'commands, properties and values; Up and Down recall earlier lines.',
  'Quote an argument with spaces as mpv does: "a b" takes C style escapes '
      "(\\\" \\\\ \\n), 'a b' and `!a b!` are taken literally. Quotes "
      'count only at the start of an argument, # starts a comment, and '
      'backslashes outside quotes stay as typed, so Windows paths need no '
      'quotes.',
  'get <property> reads a property as text, getnode <property> as '
      'structured data, and set <property> <value> writes one.',
  'Commands that change what plays (loadfile and loadlist with any flag, '
      'pause, cycle pause, set pause yes or no, stop, playlist-next, '
      'playlist-prev, playlist-play-index, playlist-remove and the playlist '
      'jumps) go through the Player API, so the play button, the '
      'mini-player and the Engine page stay in step. The log line names the '
      'call used. Other commands go to mpv as typed; the engine refuses '
      'cycle-values pause and the af commands, and quit is not sent.',
  r'print-text and show-text expand ${property} references themselves. '
      'For any other command, put expand-properties in front of it.',
  'hooks on reports the file lifecycle hooks (on_load, on_unload...) as '
      'mpv fires them, and lets each continue at once. hooks off stops the '
      'reports.',
];

/// Runs Console lines against a [PlayerApi].
///
/// mpv only changes the play intent the app shows (`playWhenReady`) when
/// asked through the Player API, never on raw commands, so the commands
/// that start, pause or move playback are turned into the matching Player
/// calls. Everything else goes to mpv as typed.
class ConsoleRunner {
  ConsoleRunner(this.player);

  final PlayerApi player;

  /// Runs [line] and returns what to log.
  Future<List<ConsoleResult>> run(String line) async {
    final List<String> args;
    try {
      args = tokenizeConsoleLine(line);
    } on FormatException catch (e) {
      return [ConsoleResult.error(e.message)];
    }
    if (args.isEmpty) return const [];
    try {
      return await _run(args);
    } on PlayerException catch (e) {
      return [ConsoleResult.error(e.toString())];
    } on ArgumentError catch (e) {
      // Also a RangeError: a queue index that is not there.
      return [ConsoleResult.error('${e.message}')];
    }
  }

  Future<List<ConsoleResult>> _run(List<String> args) async {
    switch (args.first) {
      case 'get' when args.length >= 2:
        final value = await player.getRawProperty(args[1]);
        return [ConsoleResult.output('${args[1]} = ${value ?? '<null>'}')];
      case 'getnode' when args.length >= 2:
        final node = await player.getRawPropertyNode(args[1]);
        return [ConsoleResult.output('${args[1]} = ${_pretty(node)}')];
      case 'help':
        return [for (final p in kConsoleHelp) ConsoleResult.output(p)];
      case 'hooks':
        return _hooks(args.length > 1 ? args[1] : 'on');
      case 'set' when args.length >= 3 && args[1] == 'pause':
        return _setPause(args[2]);
      case 'set' when args.length >= 3:
        final value = args.sublist(2).join(' ');
        await player.setRawProperty(args[1], value);
        return [ConsoleResult.output('${args[1]} = $value')];
    }

    // Leading prefixes (no-osd, expand-properties...) do not change what
    // the command does to playback.
    var at = 0;
    while (at < args.length && kCommandPrefixes.contains(args[at])) {
      at++;
    }
    if (at >= args.length) {
      return const [ConsoleResult.error('A prefix needs a command after it')];
    }
    final command = args[at].replaceAll('_', '-');
    final rest = args.sublist(at + 1);
    final routed = await _route(command, rest);
    if (routed != null) return routed;

    final sent = _expandIfNeeded(args, at, command);
    await player.sendRawCommand(sent);
    return [
      ConsoleResult.output(
        identical(sent, args) ? 'ok' : 'ok (sent as ${_line(sent)})',
      ),
    ];
  }

  /// print-text and show-text with `${...}` and no expansion prefix get
  /// `expand-properties`: commands sent as an argument list are not
  /// expanded otherwise.
  static List<String> _expandIfNeeded(
    List<String> args,
    int at,
    String command,
  ) {
    if (command != 'print-text' && command != 'show-text') return args;
    final prefixes = args.sublist(0, at);
    if (prefixes.contains('expand-properties') || prefixes.contains('raw')) {
      return args;
    }
    if (!args.skip(at + 1).any((a) => a.contains(r'${'))) return args;
    return ['expand-properties', ...args];
  }

  Future<List<ConsoleResult>?> _route(String command, List<String> a) async {
    switch (command) {
      case 'loadfile' when a.isNotEmpty:
        return _loadfile(a);
      case 'loadlist' when a.isNotEmpty:
        return _loadlist(a);
      case 'pause':
        await player.pause();
        return _routed('Player.pause()');
      case 'cycle' when a.isNotEmpty && a.first == 'pause':
        return _setPause('toggle');
      case 'set' when a.length >= 2 && a.first == 'pause':
        return _setPause(a[1]);
      case 'stop' when a.contains('keep-playlist'):
        return _stopKeepingPlaylist(['stop', ...a]);
      case 'stop':
        await player.stop();
        return _routed('Player.stop()');
      case 'playlist-remove' when a.isNotEmpty:
        return _remove(a.first);
      case 'quit' || 'quit-watch-later':
        return const [
          ConsoleResult.error(
            'quit would shut the audio engine down for good; close the app '
            'instead',
          ),
        ];
      case 'playlist-next':
        final force = a.isNotEmpty && a.first == 'force';
        final moved = await player.next(force: force);
        return _moved('Player.next(force: $force)', moved, 'No next entry');
      case 'playlist-prev':
        final force = a.isNotEmpty && a.first == 'force';
        final moved = await player.previous(force: force);
        return _moved(
          'Player.previous(force: $force)',
          moved,
          'No previous entry',
        );
      case 'playlist-next-playlist':
        final moved = await player.nextPlaylist();
        return _moved('Player.nextPlaylist()', moved, 'No next playlist');
      case 'playlist-prev-playlist':
        final moved = await player.previousPlaylist();
        return _moved(
          'Player.previousPlaylist()',
          moved,
          'No previous playlist',
        );
      case 'playlist-play-index' when a.isNotEmpty:
        return _playIndex(a.first);
    }
    return null;
  }

  Future<List<ConsoleResult>> _setPause(String value) async {
    final bool pause;
    switch (value) {
      case 'yes':
        pause = true;
      case 'no':
        pause = false;
      case 'toggle' || 'cycle':
        pause = player.state.playWhenReady;
      default:
        return [ConsoleResult.error('pause takes yes, no or toggle')];
    }
    if (pause) {
      await player.pause();
      return _routed('Player.pause()');
    }
    await player.play();
    return _routed('Player.play()');
  }

  Future<List<ConsoleResult>> _playIndex(String which) async {
    final current = player.state.playlist.index;
    switch (which) {
      case 'none':
        return _stopKeepingPlaylist(['playlist-play-index', 'none']);
      case 'current':
        if (current < 0) return [ConsoleResult.error('Nothing is current')];
        await player.jump(current);
        return _routed('Player.jump($current)');
    }
    final index = int.tryParse(which);
    if (index == null) {
      return [ConsoleResult.error('Expected an index, current or none')];
    }
    await player.jump(index);
    return _routed('Player.jump($index)');
  }

  /// Stops playback and keeps the queue: `Player.stop()` would clear it,
  /// so the command goes raw and the intent follows with `Player.pause()`.
  Future<List<ConsoleResult>> _stopKeepingPlaylist(List<String> args) async {
    await player.sendRawCommand(args);
    await player.pause();
    return _routed('raw ${args.join(' ')}, then Player.pause()');
  }

  /// `playlist-remove <index|current>`.
  Future<List<ConsoleResult>> _remove(String which) async {
    final index = which == 'current'
        ? player.state.playlist.index
        : int.tryParse(which);
    if (index == null || index < 0) {
      return [ConsoleResult.error('Expected an index or current')];
    }
    await player.remove(index);
    return _routed('Player.remove($index)');
  }

  /// `loadfile <url> [<flags> [<index> [<options>]]]`.
  Future<List<ConsoleResult>> _loadfile(List<String> a) async {
    final media = Media(a[0]);
    final flag = a.length > 1 ? a[1] : 'replace';
    if (a.length > 3) {
      // Per-file options have no typed form: send the line as typed and
      // bring the intent in step where mpv starts playback: always for
      // replace, only from idle for the -play flags.
      final idle = _idle;
      await player.sendRawCommand(['loadfile', ...a]);
      if (flag == 'replace' || (flag.endsWith('-play') && idle)) {
        await player.play();
        return _routed('raw loadfile (with options), then Player.play()');
      }
      return _routed('raw loadfile (with options)');
    }
    final playlist = player.state.playlist;
    final idle = _idle;
    final end = playlist.items.length;
    final calls = <String>[];

    Future<void> add() async {
      await player.add(media);
      calls.add('Player.add()');
    }

    // The new entry is assumed to land at [end]: a queue change from
    // elsewhere between the add and the move would misplace it.
    Future<void> moveTo(int target) async {
      if (target >= end) return;
      await player.move(end, target);
      calls.add('Player.move($end, $target)');
    }

    Future<void> playIfIdle(int index) async {
      if (!idle) return;
      await player.jump(index);
      calls.add('Player.jump($index)');
    }

    switch (flag) {
      case 'replace':
        await player.open(media, play: true);
        calls.add('Player.open(play: true)');
      case 'append':
        await add();
      case 'append-play':
        await add();
        await playIfIdle(end);
      case 'insert-next' || 'insert-next-play':
        // With nothing current mpv appends.
        final target = idle ? end : playlist.index + 1;
        await add();
        await moveTo(target);
        if (flag == 'insert-next-play') await playIfIdle(target);
      case 'insert-at' || 'insert-at-play':
        final target = a.length > 2 ? int.tryParse(a[2]) : null;
        if (target == null) {
          return [ConsoleResult.error('$flag needs an index')];
        }
        // A negative index appends, as in mpv.
        final at = target < 0 || target > end ? end : target;
        await add();
        await moveTo(at);
        if (flag == 'insert-at-play') await playIfIdle(at);
      default:
        return [ConsoleResult.error('Unknown loadfile flag "$flag"')];
    }
    return _routed(calls.join(', '));
  }

  /// `loadlist <url> [<flags> [<index>]]`.
  Future<List<ConsoleResult>> _loadlist(List<String> a) async {
    final flag = a.length > 1 ? a[1] : 'replace';
    if (flag == 'replace') {
      await player.openPlaylistFile(Media(a[0]), play: true);
      return _routed('Player.openPlaylistFile(play: true)');
    }
    // Appending a playlist file has no typed form: send it as typed, then
    // start playback the way mpv would, through the Player API.
    final idle = _idle;
    await player.sendRawCommand(['loadlist', ...a]);
    if (flag.endsWith('-play') && idle) {
      await player.play();
      return _routed('raw loadlist, then Player.play()');
    }
    return _routed('raw loadlist');
  }

  Future<List<ConsoleResult>> _hooks(String mode) async {
    final monitor = HookMonitor.of(player);
    switch (mode) {
      case 'on':
        final failed = await monitor.start();
        final names = [
          for (final h in Hook.values)
            if (monitor.registered.contains(h)) h.mpvValue,
        ];
        return [
          if (names.isEmpty)
            const ConsoleResult.error('No hook could be registered')
          else
            ConsoleResult.output('Reporting hooks: ${names.join(', ')}'),
          if (failed.isNotEmpty && names.isNotEmpty)
            ConsoleResult.error(
              'Could not register: '
              '${failed.map((h) => h.mpvValue).join(', ')}',
            ),
        ];
      case 'off':
        monitor.stop();
        return [const ConsoleResult.output('Stopped reporting hooks')];
    }
    return [const ConsoleResult.error('hooks takes on or off')];
  }

  /// Whether nothing is loaded, the case where mpv's `-play` flags start
  /// playback.
  bool get _idle {
    final playlist = player.state.playlist;
    return playlist.items.isEmpty || playlist.index < 0;
  }

  static List<ConsoleResult> _routed(String via) => [
    ConsoleResult.routed('via $via'),
  ];

  static List<ConsoleResult> _moved(String via, bool moved, String none) => [
    ConsoleResult.routed('via $via'),
    if (!moved) ConsoleResult.output(none),
  ];

  static String _line(List<String> args) => args.map(quoteConsoleArg).join(' ');

  static String _pretty(Object? node) {
    if (node == null) return '<null>';
    try {
      return const JsonEncoder.withIndent('  ').convert(node);
    } on JsonUnsupportedObjectError {
      return node.toString();
    }
  }
}
