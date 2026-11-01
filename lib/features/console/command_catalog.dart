// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
//
// The command names and argument signatures follow mpv's command table
// (mp_cmds[] in player/command.c, mpv 0.41.0), in the notation of mpv's
// input reference; the one-line docs are written for the app. Keep them in
// step with that table when mpv_audio_kit moves to a newer mpv.

/// One mpv input command: its [name], the argument [signature] in mpv's
/// notation (e.g. `<target> [<flags>]`), and a one-line [doc].
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
    'Set the loop start, then the loop end, then clear both, one step per call',
  ),
  MpvCommand(
    'ab-loop-align-cache',
    '',
    'Snap the A and B loop points to the cached range that ab-loop-dump-cache would write',
  ),
  MpvCommand(
    'ab-loop-dump-cache',
    '<filename>',
    'Write the cached span between the A and B loop points to a file, as dump-cache does',
  ),
  MpvCommand(
    'add',
    '<name> [<value>]',
    'Increase a property by value (1 if omitted), stopping at its limits',
  ),
  MpvCommand(
    'af',
    '<operation> <value>',
    'Edit the audio filter chain: set, add, remove, toggle or clr its stages, as vf does for video',
  ),
  MpvCommand(
    'af-command',
    '<label> <command> <argument> [<target>]',
    'Send a runtime command to a labelled audio filter (lavfi filters only)',
  ),
  MpvCommand(
    'ao-reload',
    '',
    'Close and reopen the audio output, for example after the output device changes',
  ),
  MpvCommand(
    'apply-profile',
    '<name> [<mode>]',
    'Apply a named profile now, or with restore undo what it set',
  ),
  MpvCommand(
    'audio-add',
    '<url> [<flags> [<title> [<lang>]]]',
    'Add an external audio file as a track; flags as for sub-add',
  ),
  MpvCommand(
    'audio-reload',
    '[<id>]',
    'Reload an external audio track from its file (the current one if no id)',
  ),
  MpvCommand(
    'audio-remove',
    '[<id>]',
    'Drop an external audio track (the current one if no id)',
  ),
  MpvCommand(
    'begin-vo-dragging',
    '',
    'Start moving the video window with the mouse; does nothing without a video window',
  ),
  MpvCommand(
    'change-list',
    '<name> <operation> <value>',
    'Edit a list option in place, with operations such as append, add, pre, remove, del, toggle or clr',
  ),
  MpvCommand(
    'context-menu',
    '',
    'Open the context menu of the video window; does nothing without a video window',
  ),
  MpvCommand(
    'cycle',
    '<name> [<value>]',
    'Step a property to its next value (or previous with down), wrapping at the ends',
  ),
  MpvCommand(
    'cycle-values',
    '[<"!reverse">] <property> <value1> [<value2> [...]]',
    'Set a property to the value after its current one in the given list, wrapping around',
  ),
  MpvCommand(
    'define-section',
    '<name> <contents> [<flags>]',
    'Deprecated: create an input section of key bindings (kept for mpv\'s own use)',
  ),
  MpvCommand('del', '<name>', 'Delete a property; few properties support this'),
  MpvCommand(
    'delete-watch-later-config',
    '[<filename>]',
    'Forget the saved resume position of a file (the current one if no filename)',
  ),
  MpvCommand(
    'disable-section',
    '<name>',
    'Deprecated: turn off a named input section (kept for mpv\'s own use)',
  ),
  MpvCommand(
    'drop-buffers',
    '',
    'Throw away the buffered audio, video and demuxer data and start reading anew',
  ),
  MpvCommand(
    'dump-cache',
    '<start> <end> <filename>',
    'Save the cached stream between two times to a file, replacing any file there',
  ),
  MpvCommand(
    'enable-section',
    '<name> [<flags>]',
    'Deprecated: turn on a named input section (kept for mpv\'s own use)',
  ),
  MpvCommand(
    'escape-ass',
    '<text>',
    'Return the text with ASS markup escaped, so an OSD overlay shows it as typed',
  ),
  MpvCommand(
    'expand-path',
    '<text>',
    'Return the path with its ~~ shortcuts (such as ~~home/) resolved',
  ),
  MpvCommand(
    'expand-text',
    '<text>',
    'Return the text with its \${property} references filled in',
  ),
  MpvCommand(
    'flush-status-line',
    '<clear>',
    'Print the pending terminal status line now; clear wipes it instead',
  ),
  MpvCommand(
    'frame-back-step',
    '',
    'Go back one video frame and pause; needs video',
  ),
  MpvCommand(
    'frame-step',
    '[<frames>] [<flags>]',
    'Play a number of video frames (1 if omitted), then pause; with seek, also backwards; needs video',
  ),
  MpvCommand('ignore', '', 'Do nothing; bind a key to it to silence that key'),
  MpvCommand(
    'keybind',
    '<name> <cmd> [<comment>]',
    'Bind a key, named as in input.conf, to a full command line',
  ),
  MpvCommand(
    'keydown',
    '<name>',
    'Press a key and hold it, so a repeatable binding repeats until keyup',
  ),
  MpvCommand(
    'keypress',
    '<name> [<scale>]',
    'Press and release a key, running whatever it is bound to',
  ),
  MpvCommand(
    'keyup',
    '[<name>]',
    'Release a held key (all held keys if no name)',
  ),
  MpvCommand(
    'load-config-file',
    '<filename>',
    'Read a config file and apply its options now',
  ),
  MpvCommand(
    'load-input-conf',
    '<filename>',
    'Read an input.conf file and add its key bindings',
  ),
  MpvCommand(
    'load-script',
    '<filename>',
    'Start a script and return its client id',
  ),
  MpvCommand(
    'loadfile',
    '<url> [<flags> [<index> [<options>]]]',
    'Play a file or URL, or with append, insert-next or insert-at put it in the playlist',
  ),
  MpvCommand(
    'loadlist',
    '<url> [<flags> [<index>]]',
    'Read a playlist file or URL and replace the playlist with it, or add it with append or insert flags',
  ),
  MpvCommand(
    'mouse',
    '<x> <y> [<button> [<mode>]]',
    'Move the pointer to x, y and optionally click a button, once or twice (double)',
  ),
  MpvCommand(
    'multiply',
    '<name> <value>',
    'Multiply a numeric property by value',
  ),
  MpvCommand(
    'normalize-path',
    '<filename>',
    'Return the path made absolute, with . and .. and repeated slashes resolved; URLs come back as they are',
  ),
  MpvCommand(
    'notify-property',
    '<property>',
    'Report a property as changed to everyone observing it',
  ),
  MpvCommand(
    'osd-overlay',
    '',
    'Create, update or remove a text overlay drawn from ASS markup; meant for scripts',
  ),
  MpvCommand(
    'overlay-add',
    '<id> <x> <y> <file> <offset> <fmt> <w> <h> <stride> <dw> <dh>',
    'Draw a raw bitmap from memory or a file over the video, in one of 64 slots',
  ),
  MpvCommand(
    'overlay-remove',
    '<id>',
    'Take away the bitmap overlay in a slot; an empty slot is left as it is',
  ),
  MpvCommand(
    'playlist-clear',
    '',
    'Empty the playlist except for the entry that is playing',
  ),
  MpvCommand(
    'playlist-move',
    '<index1> <index2>',
    'Move entry index1 so it sits just before the entry now at index2',
  ),
  MpvCommand(
    'playlist-next',
    '[<flags>]',
    'Play the next entry; with force, stop at the end of the list',
  ),
  MpvCommand(
    'playlist-next-playlist',
    '',
    'Skip ahead to the first entry that came from another playlist file',
  ),
  MpvCommand(
    'playlist-play-index',
    '<integer|current|none>',
    'Play the entry at an index (from 0), restart the current one, or stop with none',
  ),
  MpvCommand(
    'playlist-prev',
    '[<flags>]',
    'Play the previous entry; with force, stop at the start of the list',
  ),
  MpvCommand(
    'playlist-prev-playlist',
    '',
    'Skip back to the start of the previous group of entries from another playlist file',
  ),
  MpvCommand(
    'playlist-remove',
    '<index>',
    'Delete the entry at an index (from 0), or current; removing the playing entry moves on to the next',
  ),
  MpvCommand(
    'playlist-shuffle',
    '',
    'Put the playlist entries in random order',
  ),
  MpvCommand(
    'playlist-unshuffle',
    '',
    'Bring back the order from before the last playlist-shuffle; works once',
  ),
  MpvCommand(
    'print-text',
    '<text>',
    'Write the text, with \${property} references filled in, to the log',
  ),
  MpvCommand(
    'quit',
    '[<code>]',
    'Shut mpv down, with an optional exit code; the Console refuses it, as the app needs mpv running',
  ),
  MpvCommand(
    'quit-watch-later',
    '[<code>]',
    'Save the playback position for next time, then shut mpv down; the Console refuses it',
  ),
  MpvCommand(
    'rescan-external-files',
    '[<mode>]',
    'Look again for external audio, subtitle and cover files, as the *-auto options set',
  ),
  MpvCommand(
    'revert-seek',
    '[<flags>]',
    'Jump back to where the last seek started from, or with mark remember a spot to come back to',
  ),
  MpvCommand(
    'run',
    '<command> [<arg1> [<arg2> [...]]]',
    'Start a program with these arguments, without a shell, and carry on without waiting',
  ),
  MpvCommand(
    'screenshot',
    '[<flags>]',
    'Save a screenshot of the video; needs video',
  ),
  MpvCommand(
    'screenshot-raw',
    '[<flags> [<format>]]',
    'Return a screenshot as image data instead of a file; needs video',
  ),
  MpvCommand(
    'screenshot-to-file',
    '<filename> [<flags>]',
    'Save a screenshot to the given path, its format picked by the extension; needs video',
  ),
  MpvCommand(
    'script-binding',
    '<name> [<arg>]',
    'Run a key binding that a script registered, named binding or script/binding',
  ),
  MpvCommand(
    'script-message',
    '[<arg1> [<arg2> [...]]]',
    'Broadcast the arguments to every script and client',
  ),
  MpvCommand(
    'script-message-to',
    '<target> [<arg1> [<arg2> [...]]]',
    'Send the arguments to one named script or client',
  ),
  MpvCommand(
    'seek',
    '<target> [<flags>]',
    'Move the playback position, by seconds from here unless flags say absolute or percent',
  ),
  MpvCommand('set', '<name> <value>', 'Give a property a new value'),
  MpvCommand(
    'show-progress',
    '',
    'Show the elapsed time, duration and progress bar on the OSD',
  ),
  MpvCommand(
    'show-text',
    '<text> [<duration>|-1 [<level>]]',
    'Show text on the OSD, with \${property} references filled in',
  ),
  MpvCommand(
    'stop',
    '[<flags>]',
    'End playback and empty the playlist; keep-playlist leaves the list alone',
  ),
  MpvCommand(
    'sub-add',
    '<url> [<flags> [<title> [<lang>]]]',
    'Add an external subtitle file as a track, selected unless flags is auto',
  ),
  MpvCommand(
    'sub-reload',
    '[<id>]',
    'Reload an external subtitle track from its file (the current one if no id)',
  ),
  MpvCommand(
    'sub-remove',
    '[<id>]',
    'Drop an external subtitle track (the current one if no id)',
  ),
  MpvCommand(
    'sub-seek',
    '<skip> [<flags>]',
    'Seek to the start of a subtitle line, skip lines away (0 is the current line)',
  ),
  MpvCommand(
    'sub-step',
    '<skip> [<flags>]',
    'Shift the subtitle delay so the line skip lines away shows now',
  ),
  MpvCommand(
    'subprocess',
    '',
    'Run a program and wait for it, with named args to capture its output and read its exit status',
  ),
  MpvCommand(
    'vf',
    '<operation> <value>',
    'Edit the video filter chain: set, add, remove, toggle or clr its stages',
  ),
  MpvCommand(
    'vf-command',
    '<label> <command> <argument> [<target>]',
    'Send a runtime command to a labelled video filter (lavfi filters only)',
  ),
  MpvCommand(
    'video-add',
    '<url> [<flags> [<title> [<lang> [<albumart>]]]]',
    'Add an external video or image file as a track; flags as for sub-add',
  ),
  MpvCommand(
    'video-reload',
    '[<id>]',
    'Reload an external video track from its file (the current one if no id)',
  ),
  MpvCommand(
    'video-remove',
    '[<id>]',
    'Drop an external video track (the current one if no id)',
  ),
  MpvCommand(
    'write-watch-later-config',
    '',
    'Save the current playback position so the file resumes there next time',
  ),
];
