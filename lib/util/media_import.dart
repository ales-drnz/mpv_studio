import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Audio container/extension whitelist used for both the file picker
/// filter and folder scanning. Lower-case, no leading dot.
const Set<String> kAudioExtensions = {
  'mp3',
  'flac',
  'm4a',
  'aac',
  'wav',
  'ogg',
  'oga',
  'opus',
  'wma',
  'aiff',
  'aif',
  'alac',
  'ape',
  'mka',
  'wv',
  'tta',
  'dsf',
  'dff',
  'mp4',
  'webm',
  'mpc',
};

/// Apple platforms (iOS/macOS) filter the document picker by Uniform Type
/// Identifier, not by extension, and `file_selector_ios` *throws* an
/// `ArgumentError` if a type group carries only `extensions` (so the picker
/// never opens and "Add files" silently does nothing). `public.audio` is the
/// umbrella audio UTI; the common formats (mp3, m4a, aac, wav, aiff, alac,
/// flac, …) conform to it, so files of those types stay selectable.
const List<String> kAudioUtis = <String>['public.audio'];

/// Whether [path] looks like a playable audio file by extension.
bool isAudioPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return false;
  return kAudioExtensions.contains(path.substring(dot + 1).toLowerCase());
}

/// The file names of the files picked or dropped in the browser, by their
/// `blob:` URL: the URL names no file, so the title comes from here.
final Map<String, String> _webFileNames = {};

/// The file's base name without its directory or extension.
String baseNameNoExt(String path) {
  final name = _webFileNames[path] ?? path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

/// Opens a multi-select audio file picker. Returns the chosen absolute
/// paths (empty if the user cancelled).
Future<List<String>> pickAudioFiles() async {
  // Carry both filters: `extensions` for desktop/Android/web, `uniformType-
  // Identifiers` for Apple platforms (which ignore extensions, and on iOS
  // reject an extension-only group).
  final typeGroup = XTypeGroup(
    label: 'Audio',
    extensions: kAudioExtensions.toList(),
    uniformTypeIdentifiers: kAudioUtis,
  );
  final files = await openFiles(
    acceptedTypeGroups: [typeGroup],
    confirmButtonText: 'Add audio files',
  );
  return [for (final f in files) _pickedPath(f)];
}

/// The path of a picked or dropped file, remembering its name on the web,
/// where the path is a `blob:` URL of the page that mpv_audio_kit opens.
String _pickedPath(XFile file) {
  if (kIsWeb) _webFileNames[file.path] = file.name;
  return file.path;
}

/// Opens a folder picker and returns every audio file inside it,
/// recursively, sorted by path. Empty if cancelled or none found.
///
/// Folder selection is a desktop-only operation (file_selector does not
/// support it on iOS/Android); on mobile users add individual files.
Future<List<String>> pickAudioFolder() async {
  final dir = await getDirectoryPath(
    confirmButtonText: 'Add a folder of audio',
  );
  if (dir == null) return const [];
  return scanAudioFolder(dir);
}

/// Expands a set of dropped paths into playable audio files: directories
/// are scanned recursively, plain files kept if they look like audio.
/// Order is preserved; duplicates are dropped.
List<String> resolveDroppedPaths(Iterable<String> paths) {
  final out = <String>[];
  final seen = <String>{};
  void addPath(String p) {
    if (seen.add(p)) out.add(p);
  }

  for (final p in paths) {
    if (FileSystemEntity.isDirectorySync(p)) {
      scanAudioFolder(p).forEach(addPath);
    } else if (isAudioPath(p)) {
      addPath(p);
    }
  }
  return out;
}

/// [resolveDroppedPaths] for the files of a drop. In the browser a drop
/// gives files only, each with its name and a `blob:` URL.
List<String> resolveDroppedFiles(Iterable<XFile> files) {
  if (!kIsWeb) return resolveDroppedPaths(files.map((f) => f.path));
  return [
    for (final f in files)
      if (isAudioPath(f.name)) _pickedPath(f),
  ];
}

/// Recursively lists audio files under [dirPath]. Tolerates unreadable
/// entries (permissions, broken links).
List<String> scanAudioFolder(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return const [];
  final out = <String>[];
  try {
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File && isAudioPath(entity.path)) {
        out.add(entity.path);
      }
    }
  } on FileSystemException {
    // Partial results are fine.
  }
  out.sort();
  return out;
}
