// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
//
// The one-line docs and the argument signatures are excerpts of mpv's
// manual, DOCS/man/input.rst (Copyright the mpv developers), which mpv's
// Copyright file lists as GPLv2+: that text keeps mpv's license, the GPL,
// version 2 or later. The rest of the file is by Alessandro Di Ronza, under
// the BSD 3-Clause license (LICENSE).
//
// AUTO-GENERATED from mpv's DOCS/man/input.rst (command reference) and the
// mp_cmds[] table in player/command.c. Do not edit by hand, with one
// exception: the generator is not in this repository, so four docs were
// edited after it to read in the app's prose (no slashes as separators:
// ab-loop-align-cache, drop-buffers, osd-overlay, run). Redo those edits
// after a regeneration against a newer mpv.

/// One mpv input command: its [name], the argument [signature] as written
/// in mpv's manual (e.g. `<target> [<flags>]`), and a one-line [doc].
class MpvCommand {
  final String name;
  final String signature;
  final String doc;
  const MpvCommand(this.name, this.signature, this.doc);
}

/// The full mpv input-command catalog (used for first-token completion).
const List<MpvCommand> kMpvCommands = [
  MpvCommand(
    'ab-loop',
    '',
    'Cycle through A-B loop states. The first command will set the A point',
  ),
  MpvCommand(
    'ab-loop-align-cache',
    '',
    'Re-adjust the A-B loop points to the start and end within the cache the',
  ),
  MpvCommand(
    'ab-loop-dump-cache',
    '<filename>',
    'Essentially calls dump-cache with the current AB-loop points as',
  ),
  MpvCommand(
    'add',
    '<name> [<value>]',
    'Add the given value to the property or option. On overflow or underflow,',
  ),
  MpvCommand(
    'af',
    '<operation> <value>',
    'Change audio filter chain. See vf command.',
  ),
  MpvCommand(
    'af-command',
    '<label> <command> <argument> [<target>]',
    'Same as vf-command, but for audio filters.',
  ),
  MpvCommand('ao-reload', '', ''),
  MpvCommand(
    'apply-profile',
    '<name> [<mode>]',
    'Apply the contents of a named profile. This is like using profile=name',
  ),
  MpvCommand(
    'audio-add',
    '<url> [<flags> [<title> [<lang>]]]',
    'Load the given audio file. See sub-add command.',
  ),
  MpvCommand(
    'audio-reload',
    '[<id>]',
    'Reload the given audio tracks. See sub-reload command.',
  ),
  MpvCommand(
    'audio-remove',
    '[<id>]',
    'Remove the given audio track. See sub-remove command.',
  ),
  MpvCommand(
    'begin-vo-dragging',
    '',
    'Begin window dragging if supported by the current VO. This command should',
  ),
  MpvCommand(
    'change-list',
    '<name> <operation> <value>',
    'This command changes list options as described in List Options_. The',
  ),
  MpvCommand(
    'context-menu',
    '',
    'Show context menu on the video window. See Context Menu_ section for details.',
  ),
  MpvCommand(
    'cycle',
    '<name> [<value>]',
    'Cycle the given property or option. The second argument can be up or',
  ),
  MpvCommand(
    'cycle-values',
    '[<"!reverse">] <property> <value1> [<value2> [...]]',
    'Cycle through a list of values. Each invocation of the command will set the',
  ),
  MpvCommand(
    'define-section',
    '<name> <contents> [<flags>]',
    'This command is deprecated, except for mpv-internal uses.',
  ),
  MpvCommand(
    'del',
    '<name>',
    'Delete the given property. Most properties cannot be deleted.',
  ),
  MpvCommand(
    'delete-watch-later-config',
    '[<filename>]',
    'Delete any existing resume config file that was written by',
  ),
  MpvCommand(
    'disable-section',
    '<name>',
    'This command is deprecated, except for mpv-internal uses.',
  ),
  MpvCommand(
    'drop-buffers',
    '',
    'Drop audio, video and demuxer buffers, and restart from fresh. Might help with',
  ),
  MpvCommand(
    'dump-cache',
    '<start> <end> <filename>',
    'Dump the current cache to the given filename. The <filename> file is',
  ),
  MpvCommand(
    'enable-section',
    '<name> [<flags>]',
    'This command is deprecated, except for mpv-internal uses.',
  ),
  MpvCommand(
    'escape-ass',
    '<text>',
    'Modify text so that commands and functions that interpret ASS tags,',
  ),
  MpvCommand(
    'expand-path',
    '<text>',
    'Expand a path\'s double-tilde placeholders into a platform-specific path.',
  ),
  MpvCommand(
    'expand-text',
    '<text>',
    'Property-expand the argument and return the expanded string. This can be',
  ),
  MpvCommand('flush-status-line', '', ''),
  MpvCommand(
    'frame-back-step',
    '',
    'Calls frame-step with a value of -1 and the seek flag.',
  ),
  MpvCommand(
    'frame-step',
    '[<frames>] [<flags>]',
    'Go forward or backwards by a given amount of frames. If <frames> is',
  ),
  MpvCommand(
    'ignore',
    '',
    'Use this to "block" keys that should be unbound, and do nothing. Useful for',
  ),
  MpvCommand(
    'keybind',
    '<name> <cmd> [<comment>]',
    'Binds a key to an input command. cmd must be a complete command',
  ),
  MpvCommand(
    'keydown',
    '<name>',
    'Similar to keypress, but sets the KEYDOWN flag so that if the key is',
  ),
  MpvCommand(
    'keypress',
    '<name> [<scale>]',
    'Send a key event through mpv\'s input handler, triggering whatever',
  ),
  MpvCommand(
    'keyup',
    '[<name>]',
    'Set the KEYUP flag, stopping any repeated behavior that had been',
  ),
  MpvCommand(
    'load-config-file',
    '<filename>',
    'Load a configuration file, similar to the --include option. If the file',
  ),
  MpvCommand(
    'load-input-conf',
    '<filename>',
    'Load an input configuration file, similar to the --input-conf option. If',
  ),
  MpvCommand(
    'load-script',
    '<filename>',
    'Load a script, similar to the --script option. Whether this waits for',
  ),
  MpvCommand(
    'loadfile',
    '<url> [<flags> [<index> [<options>]]]',
    'Load the given file or URL and play it. Technically, this is just a playlist',
  ),
  MpvCommand(
    'loadlist',
    '<url> [<flags> [<index>]]',
    'Load the given playlist file or URL (like --playlist).',
  ),
  MpvCommand(
    'mouse',
    '<x> <y> [<button> [<mode>]]',
    'Send a mouse event with given coordinate (<x>, <y>).',
  ),
  MpvCommand(
    'multiply',
    '<name> <value>',
    'Similar to add, but multiplies the property or option with the numeric',
  ),
  MpvCommand(
    'normalize-path',
    '<filename>',
    'Return a canonical representation of the path filename by converting it',
  ),
  MpvCommand('notify-property', '', ''),
  MpvCommand('osd-overlay', '', 'Add, update or remove an OSD overlay.'),
  MpvCommand(
    'overlay-add',
    '<id> <x> <y> <file> <offset> <fmt> <w> <h> <stride> <dw> <dh>',
    'Add an OSD overlay sourced from raw data. This might be useful for scripts',
  ),
  MpvCommand(
    'overlay-remove',
    '<id>',
    'Remove an overlay added with overlay-add and the same ID. Does nothing',
  ),
  MpvCommand(
    'playlist-clear',
    '',
    'Clear the playlist, except the currently played file.',
  ),
  MpvCommand(
    'playlist-move',
    '<index1> <index2>',
    'Move the playlist entry at index1, so that it takes the place of the',
  ),
  MpvCommand(
    'playlist-next',
    '[<flags>]',
    'Go to the next entry on the playlist.',
  ),
  MpvCommand(
    'playlist-next-playlist',
    '',
    'Go to the next entry on the playlist with a different playlist-path.',
  ),
  MpvCommand(
    'playlist-play-index',
    '<integer|current|none>',
    'Start (or restart) playback of the given playlist index. In addition to the',
  ),
  MpvCommand(
    'playlist-prev',
    '[<flags>]',
    'Go to the previous entry on the playlist.',
  ),
  MpvCommand(
    'playlist-prev-playlist',
    '',
    'Go to the first of the previous entries on the playlist with a different',
  ),
  MpvCommand(
    'playlist-remove',
    '<index>',
    'Remove the playlist entry at the given index. Index values start counting',
  ),
  MpvCommand(
    'playlist-shuffle',
    '',
    'Shuffle the playlist. This is similar to what is done on start if the',
  ),
  MpvCommand(
    'playlist-unshuffle',
    '',
    'Attempt to revert the previous playlist-shuffle command. This works',
  ),
  MpvCommand(
    'print-text',
    '<text>',
    'Print text to stdout. The string can contain properties (see',
  ),
  MpvCommand(
    'quit',
    '[<code>]',
    'Exit the player. If an argument is given, it\'s used as process exit code.',
  ),
  MpvCommand(
    'quit-watch-later',
    '[<code>]',
    'Exit player, and store current playback position. Playing that file later',
  ),
  MpvCommand(
    'rescan-external-files',
    '[<mode>]',
    'Rescan external files according to the current --sub-auto,',
  ),
  MpvCommand(
    'revert-seek',
    '[<flags>]',
    'Undoes the seek command, and some other commands that seek (but not',
  ),
  MpvCommand(
    'run',
    '<command> [<arg1> [<arg2> [...]]]',
    'Run the given command. Unlike in MPlayer, mplayer2 and earlier versions of',
  ),
  MpvCommand('screenshot', '[<flags>]', 'Take a screenshot.'),
  MpvCommand(
    'screenshot-raw',
    '[<flags> [<format>]]',
    'Return a screenshot in memory. This can be used only through the client API',
  ),
  MpvCommand(
    'screenshot-to-file',
    '<filename> [<flags>]',
    'Take a screenshot and save it to a given file. The format of the file will',
  ),
  MpvCommand(
    'script-binding',
    '<name> [<arg>]',
    'Invoke a script-provided key binding. This can be used to remap key',
  ),
  MpvCommand(
    'script-message',
    '[<arg1> [<arg2> [...]]]',
    'Send a message to all clients, and pass it the following list of arguments.',
  ),
  MpvCommand(
    'script-message-to',
    '<target> [<arg1> [<arg2> [...]]]',
    'Same as script-message, but send it only to the client named',
  ),
  MpvCommand(
    'seek',
    '<target> [<flags>]',
    'Change the playback position. By default, seeks by a relative amount of',
  ),
  MpvCommand(
    'set',
    '<name> <value>',
    'Set the given property or option to the given value.',
  ),
  MpvCommand(
    'show-progress',
    '',
    'Show the progress bar, the elapsed time and the total duration of the file',
  ),
  MpvCommand(
    'show-text',
    '<text> [<duration>|-1 [<level>]]',
    'Show text on the OSD. The string can contain properties, which are expanded',
  ),
  MpvCommand(
    'stop',
    '[<flags>]',
    'Stop playback and clear playlist. With default settings, this is',
  ),
  MpvCommand(
    'sub-add',
    '<url> [<flags> [<title> [<lang>]]]',
    'Load the given subtitle file or stream. By default, it is selected as',
  ),
  MpvCommand(
    'sub-reload',
    '[<id>]',
    'Reload the given subtitle tracks. If the id argument is missing, reload',
  ),
  MpvCommand(
    'sub-remove',
    '[<id>]',
    'Remove the given subtitle track. If the id argument is missing, remove',
  ),
  MpvCommand(
    'sub-seek',
    '<skip> [<flags>]',
    'Change video and audio position such that the subtitle event after',
  ),
  MpvCommand(
    'sub-step',
    '<skip> [<flags>]',
    'Change subtitle timing such, that the subtitle event after the next',
  ),
  MpvCommand(
    'subprocess',
    '',
    'Similar to run, but gives more control about process execution to the',
  ),
  MpvCommand('vf', '<operation> <value>', 'Change video filter chain.'),
  MpvCommand(
    'vf-command',
    '<label> <command> <argument> [<target>]',
    'Send a command to the filter. Note that currently, this only works with',
  ),
  MpvCommand(
    'video-add',
    '<url> [<flags> [<title> [<lang> [<albumart>]]]]',
    'Load the given video file. See sub-add command for common options.',
  ),
  MpvCommand(
    'video-reload',
    '[<id>]',
    'Reload the given video tracks. See sub-reload command.',
  ),
  MpvCommand(
    'video-remove',
    '[<id>]',
    'Remove the given video track. See sub-remove command.',
  ),
  MpvCommand(
    'write-watch-later-config',
    '',
    'Write the resume config file that the quit-watch-later command writes,',
  ),
];
