import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'effects_codec.dart';

/// Effects chains kept under a name, to try another chain and go back.
abstract class ChainLibrary implements Listenable {
  /// The saved chains by name, in the order they were saved.
  Map<String, List<AudioEffect>> get chains;

  /// Saves [effects] as [name], replacing a chain of that name.
  void save(String name, List<AudioEffect> effects);

  void delete(String name);
}

/// A [ChainLibrary] in memory; [onChanged] gets every change, for the
/// app to persist it.
class MemoryChainLibrary extends ChangeNotifier implements ChainLibrary {
  MemoryChainLibrary({
    Map<String, List<AudioEffect>> initial = const {},
    this.onChanged,
  }) : _chains = Map.of(initial);

  final Map<String, List<AudioEffect>> _chains;
  final ValueChanged<Map<String, List<AudioEffect>>>? onChanged;

  @override
  Map<String, List<AudioEffect>> get chains => Map.unmodifiable(_chains);

  @override
  void save(String name, List<AudioEffect> effects) {
    _chains
      ..remove(name)
      ..[name] = List.unmodifiable(effects);
    _changed();
  }

  @override
  void delete(String name) {
    if (_chains.remove(name) != null) _changed();
  }

  void _changed() {
    onChanged?.call(chains);
    notifyListeners();
  }
}

/// [effects] as text to copy and share: the app's own stored form.
String chainToText(List<AudioEffect> effects) =>
    jsonEncode(EffectsCodec.encode(effects));

/// The chain in [text] (from [chainToText]), or null when it holds none.
List<AudioEffect>? chainFromText(String text) {
  final Object? json;
  try {
    json = jsonDecode(text.trim());
  } on FormatException {
    return null;
  }
  if (json is! Map || json['chain'] is! List) return null;
  final chain = EffectsCodec.decode(json);
  return chain.isEmpty && (json['chain'] as List).isNotEmpty ? null : chain;
}
