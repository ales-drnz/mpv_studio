import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/playback_issues.dart';
import '../../studio/player_scope.dart';
import '../../ui/tokens.dart';
import '../../util/media_import.dart';
import '../../util/reactive.dart';

/// The live playback queue — a view onto `player.stream.playlist`. Add
/// tracks via the picker or by dropping files/folders; tap to jump,
/// drag to reorder, swipe the trailing handle to remove.
class QueuePage extends StatefulWidget {
  const QueuePage({super.key});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  // Not `final`: didChangeDependencies can fire more than once (inherited
  // deps changing, hot reload), and re-assigning a `late final` throws.
  late Player _player;
  late PlaybackIssues _issues;
  bool _dragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _player = PlayerScope.of(context);
    _issues = PlayerScope.issuesOf(context);
  }

  /// Runs a queue [call], showing what it throws (a stale index, a source
  /// that cannot be read) as a toast.
  Future<void> _guard<T>(Future<T> Function() call) => _issues.guard<T>(call);

  Future<void> _enqueue(List<String> paths) async {
    final medias = [
      for (final p in paths) Media(p, extras: {'title': baseNameNoExt(p)}),
    ];
    if (medias.isEmpty) return;
    await _guard(() async {
      if (_player.state.playlist.items.isEmpty) {
        await _player.openAll(medias, play: true);
      } else {
        for (final m in medias) {
          await _player.add(m);
        }
      }
    });
  }

  Future<void> _addFiles() async => _enqueue(await pickAudioFiles());
  Future<void> _addFolder() async => _enqueue(await pickAudioFolder());

  /// Load a playlist FILE or URL (.m3u / .m3u8 / .pls / .cue): its entries are
  /// expanded into the queue via the engine's `openPlaylistFile` (loadlist),
  /// unlike `open`, which would load the playlist as a single entry.
  Future<void> _loadPlaylist() async {
    const group = XTypeGroup(
      label: 'playlist',
      extensions: ['m3u', 'm3u8', 'pls', 'cue'],
      // iOS filters by UTI, not extension, and rejects an extension-only group
      // outright. Playlists are plain text; m3u carries its own system type.
      uniformTypeIdentifiers: ['public.m3u-playlist', 'public.text'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    await _guard(() => _player.openPlaylistFile(Media(file.path), play: true));
  }

  /// Swap a queue entry for a freshly picked file. `replace` is gapless
  /// when it targets the currently playing item.
  Future<void> _replace(int index) async {
    final paths = await pickAudioFiles();
    if (paths.isEmpty) return;
    final p = paths.first;
    await _guard(
      () => _player.replace(index, Media(p, extras: {'title': baseNameNoExt(p)})),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        _enqueue(resolveDroppedPaths(detail.files.map((f) => f.path)));
      },
      child: Container(
        // A drag-over wash (no border) signals the drop target.
        color: _dragging ? Tokens.accentWash : null,
        child: Column(
          children: [
            _Toolbar(
              onAddFiles: _addFiles,
              onAddFolder: _addFolder,
              onLoadPlaylist: _loadPlaylist,
              onClear: () => _guard(_player.clearPlaylist),
            ),
            // Source-playlist banner (.m3u/.pls the current entry was expanded
            // from) with cross-playlist navigation, shown only when loaded via
            // a playlist file.
            Live<String>(
              stream: _player.stream.playlistPath,
              initial: _player.state.playlistPath,
              builder: (context, path) {
                if (path.isEmpty) return const SizedBox.shrink();
                return _PlaylistBanner(
                  path: path,
                  onPrevPlaylist: () => _guard(_player.previousPlaylist),
                  onNextPlaylist: () => _guard(_player.nextPlaylist),
                );
              },
            ),
            Expanded(
              child: Live<Playlist>(
                stream: _player.stream.playlist,
                initial: _player.state.playlist,
                builder: (context, playlist) {
                  if (playlist.items.isEmpty) {
                    return _EmptyQueue(
                      onAddFiles: _addFiles,
                      onAddFolder: _addFolder,
                    );
                  }
                  return ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Tokens.s16,
                      Tokens.s12,
                      Tokens.s16,
                      Tokens.s12,
                    ),
                    // We supply our own drag handle, so the default trailing
                    // one (which crowded the remove button) is turned off.
                    buildDefaultDragHandles: false,
                    itemCount: playlist.items.length,
                    // onReorderItem already adjusts newIndex for the
                    // item removed at oldIndex.
                    onReorderItem: (oldIndex, newIndex) {
                      if (newIndex != oldIndex) {
                        _guard(() => _player.move(oldIndex, newIndex));
                      }
                    },
                    itemBuilder: (context, i) {
                      final item = playlist.items[i];
                      return _QueueTile(
                        key: ValueKey('${item.uri}#$i'),
                        index: i,
                        title: _titleOf(item),
                        source: _sourceOf(item),
                        current: i == playlist.index,
                        onTap: () => _guard(() => _player.jump(i)),
                        onReplace: () => _replace(i),
                        onRemove: () => _guard(() => _player.remove(i)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _titleOf(Media item) {
    final t = item.extras?['title'];
    if (t is String && t.isNotEmpty) return t;
    return baseNameNoExt(item.uri);
  }

  /// Where the track comes from — the containing folder for local files,
  /// or the bare host/URL for network sources.
  static String _sourceOf(Media item) {
    final uri = item.uri;
    final isUrl = uri.contains('://') && !uri.startsWith('file://');
    if (isUrl) return Uri.tryParse(uri)?.host ?? uri;
    final path = uri.startsWith('file://')
        ? (Uri.tryParse(uri)?.toFilePath() ?? uri)
        : uri;
    final sep = path.contains('\\') ? '\\' : '/';
    final cut = path.lastIndexOf(sep);
    return cut <= 0 ? path : path.substring(0, cut);
  }
}

class _Toolbar extends StatelessWidget {
  final VoidCallback onAddFiles;
  final VoidCallback onAddFolder;
  final VoidCallback onLoadPlaylist;
  final VoidCallback onClear;
  const _Toolbar({
    required this.onAddFiles,
    required this.onAddFolder,
    required this.onLoadPlaylist,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // Folder picking has no file_selector backend on iOS (or web), so the
    // Add folder button is shown disabled there; it works everywhere else.
    final folderEnabled =
        !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS;
    const folderDisabledTip = 'Folder import isn’t available on iOS';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.s16,
        Tokens.s8,
        Tokens.s16,
        Tokens.s8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Four labelled pills don't fit a phone. Below the desktop
          // breakpoint, keep every action but collapse them to icon-only
          // buttons (labels move into tooltips) so nothing overflows.
          if (constraints.maxWidth < Tokens.desktopBreakpoint) {
            return Row(
              children: [
                ToolButton(
                  icon: Icons.add_rounded,
                  label: 'Add files',
                  onTap: onAddFiles,
                  primary: true,
                  iconOnly: true,
                ),
                const SizedBox(width: Tokens.s8),
                ToolButton(
                  icon: Icons.folder_open_rounded,
                  label: 'Add folder',
                  onTap: onAddFolder,
                  iconOnly: true,
                  enabled: folderEnabled,
                  disabledTooltip: folderDisabledTip,
                ),
                const SizedBox(width: Tokens.s8),
                ToolButton(
                  icon: Icons.playlist_play_rounded,
                  label: 'Load playlist',
                  onTap: onLoadPlaylist,
                  iconOnly: true,
                ),
                const Spacer(),
                ToolButton(
                  icon: Icons.clear_all_rounded,
                  label: 'Clear',
                  onTap: onClear,
                  iconOnly: true,
                ),
              ],
            );
          }
          return Row(
            children: [
              ToolButton(
                icon: Icons.add_rounded,
                label: 'Add files',
                onTap: onAddFiles,
                primary: true,
              ),
              const SizedBox(width: Tokens.s8),
              ToolButton(
                icon: Icons.folder_open_rounded,
                label: 'Add folder',
                onTap: onAddFolder,
                enabled: folderEnabled,
                disabledTooltip: folderDisabledTip,
              ),
              const SizedBox(width: Tokens.s8),
              ToolButton(
                icon: Icons.playlist_play_rounded,
                label: 'Load playlist',
                onTap: onLoadPlaylist,
              ),
              const Spacer(),
              ToolButton(
                icon: Icons.clear_all_rounded,
                label: 'Clear',
                onTap: onClear,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Banner shown when the queue was expanded from a playlist file
/// (`player.stream.playlistPath`), with cross-playlist navigation.
class _PlaylistBanner extends StatelessWidget {
  final String path;
  final VoidCallback onPrevPlaylist;
  final VoidCallback onNextPlaylist;
  const _PlaylistBanner({
    required this.path,
    required this.onPrevPlaylist,
    required this.onNextPlaylist,
  });

  String get _name {
    final sep = path.contains('\\') ? '\\' : '/';
    final cut = path.lastIndexOf(sep);
    return cut < 0 ? path : path.substring(cut + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.s16, 0, Tokens.s16, Tokens.s8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.s12,
          vertical: Tokens.s8,
        ),
        decoration: ShapeDecoration(
          color: Tokens.surface2,
          shape: Tokens.squircle(Tokens.rSm),
        ),
        child: Row(
          children: [
            const Icon(Icons.queue_music_rounded,
                size: 16, color: Tokens.accent),
            const SizedBox(width: Tokens.s8),
            Expanded(
              child: Text(
                _name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tokens.caption,
              ),
            ),
            _IconTap(
              icon: Icons.skip_previous_rounded,
              tooltip: 'Previous playlist',
              onTap: onPrevPlaylist,
            ),
            _IconTap(
              icon: Icons.skip_next_rounded,
              tooltip: 'Next playlist',
              onTap: onNextPlaylist,
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final int index;
  final String title;
  final String source;
  final bool current;
  final VoidCallback onTap;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  const _QueueTile({
    super.key,
    required this.index,
    required this.title,
    required this.source,
    required this.current,
    required this.onTap,
    required this.onReplace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // A squircle card per item — same surface language as the settings and
    // catalog lists. The current track gets the accent wash and border.
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s6),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.squircle(Tokens.rSm),
          // Ink so the hover highlight shows over the card surface.
          child: Ink(
            padding: const EdgeInsets.fromLTRB(
              Tokens.s12,
              Tokens.s8,
              Tokens.s6,
              Tokens.s8,
            ),
            decoration: ShapeDecoration(
              color: current ? Tokens.accentWash : Tokens.surface,
              shape: Tokens.squircle(Tokens.rSm),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: current
                      ? const Icon(Icons.volume_up_rounded,
                          size: 16, color: Tokens.accent)
                      : Text('${index + 1}',
                          style: Tokens.numeric, textAlign: TextAlign.center),
                ),
                const SizedBox(width: Tokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tokens.body.copyWith(
                          color: current ? Tokens.accent : Tokens.fg,
                          fontWeight:
                              current ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (source.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tokens.caption,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Tokens.s8),
                // Drag-to-reorder handle (we disabled the default one).
                ReorderableDragStartListener(
                  index: index,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: EdgeInsets.all(Tokens.s6),
                      child: Icon(Icons.drag_indicator_rounded,
                          size: 18, color: Tokens.fgFaint),
                    ),
                  ),
                ),
                _IconTap(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: 'Replace',
                  onTap: onReplace,
                ),
                _IconTap(
                  icon: Icons.close_rounded,
                  tooltip: 'Remove',
                  onTap: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact, non-cramped icon tap target (avoids [IconButton]'s 48px box).
class _IconTap extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconTap({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.squircle(Tokens.rSm),
          child: Padding(
            padding: const EdgeInsets.all(Tokens.s6),
            child: Icon(icon, size: 16, color: Tokens.fgFaint),
          ),
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  final VoidCallback onAddFiles;
  final VoidCallback onAddFolder;
  const _EmptyQueue({required this.onAddFiles, required this.onAddFolder});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.queue_music_rounded,
              size: 40, color: Tokens.fgFaint),
          const SizedBox(height: Tokens.s12),
          const Text('Queue is empty', style: Tokens.label),
          const SizedBox(height: Tokens.s4),
          const Text(
            'Add files, a folder, or drop them here.',
            style: Tokens.caption,
          ),
          const SizedBox(height: Tokens.s20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToolButton(
                icon: Icons.add_rounded,
                label: 'Add files',
                onTap: onAddFiles,
                primary: true,
              ),
              const SizedBox(width: Tokens.s8),
              ToolButton(
                icon: Icons.folder_open_rounded,
                label: 'Add folder',
                onTap: onAddFolder,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small flat pill button used in section toolbars. Set [iconOnly] to drop
/// the label (it becomes a tooltip) for tight, phone-width toolbars; set
/// [enabled] to `false` to show it greyed and inert, with [disabledTooltip]
/// explaining why.
class ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool iconOnly;
  final bool enabled;
  final String? disabledTooltip;

  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.iconOnly = false,
    this.enabled = true,
    this.disabledTooltip,
  });

  @override
  Widget build(BuildContext context) {
    // Disabled wins over primary: a greyed pill must read as inert, not active.
    final fg = !enabled
        ? Tokens.fgFaint
        : (primary ? Tokens.onAccent : Tokens.fg);
    final bg = !enabled || !primary ? Tokens.surface2 : Tokens.accent;

    final content = iconOnly
        ? Icon(icon, size: 18, color: fg)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: Tokens.s6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          );

    final pill = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: Tokens.squircle(Tokens.rSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.s12,
            vertical: Tokens.s8,
          ),
          decoration: ShapeDecoration(
            color: bg,
            shape: Tokens.squircle(Tokens.rSm),
          ),
          child: content,
        ),
      ),
    );

    // Icon-only buttons surface their label as a tooltip; a disabled button
    // explains its inertness instead.
    final tip = !enabled ? (disabledTooltip ?? label) : (iconOnly ? label : null);
    return tip == null ? pill : Tooltip(message: tip, child: pill);
  }
}
