import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The JSON blob behind [AppSettings], kept in [SharedPreferences] under
/// one key. Reads are typed with a default; writes are debounced and
/// notify the listeners when a value actually changed.
///
/// [load] migrates a blob written by an older MPV Studio
/// ([migrateSettings]), so nothing the user set is lost across updates.
class SettingsStore extends ChangeNotifier {
  SettingsStore(
    this._prefs,
    Map<String, Object?> data, {
    this.debounce = const Duration(milliseconds: 400),
  }) : _data = data;

  /// The preferences key. Kept from MPV Studio 0.2: the blob carries its
  /// own [settingsSchema] version instead.
  static const key = 'mpv_studio.settings.v1';

  /// Loads the persisted blob (empty on first run, or when it is corrupt),
  /// migrated to the current [settingsSchema].
  static Future<SettingsStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    var data = <String, Object?>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = decoded.cast<String, Object?>();
      } on FormatException {
        // A corrupt blob starts clean rather than crash the launch.
      }
    }
    return SettingsStore(prefs, migrateSettings(data));
  }

  final SharedPreferences _prefs;
  final Map<String, Object?> _data;
  final Duration debounce;
  Timer? _saveTimer;

  /// The raw value under [k], for the typed getters of [AppSettings].
  Object? operator [](String k) => _data[k];

  bool containsKey(String k) => _data.containsKey(k);

  // The typed readers fall back to the default for a value of the wrong
  // type (a hand-edited or damaged blob), so one bad value never stops the
  // launch.
  double readDouble(String k, double d) => switch (_data[k]) {
    final num v when v.isFinite => v.toDouble(),
    _ => d,
  };
  int readInt(String k, int d) => switch (_data[k]) {
    final num v when v.isFinite => v.toInt(),
    _ => d,
  };
  bool readBool(String k, bool d) => switch (_data[k]) {
    final bool v => v,
    _ => d,
  };
  String readString(String k, String d) => switch (_data[k]) {
    final String v => v,
    _ => d,
  };

  /// The [values] entry named by the string under [k], or [d].
  E readEnum<E extends Enum>(String k, List<E> values, E d) {
    final name = _data[k];
    for (final v in values) {
      if (v.name == name) return v;
    }
    return d;
  }

  /// Records [value] under [k]; saves (debounced) and notifies only when
  /// it changed. JSON values (lists, maps) compare by content.
  void write(String k, Object? value) {
    final old = _data[k];
    final same = value is List || value is Map
        ? jsonEncode(old) == jsonEncode(value)
        : old == value;
    if (same && _data.containsKey(k)) return;
    _data[k] = value;
    _changed();
  }

  /// Records several values at once, with one save and one notification.
  void writeAll(Map<String, Object?> values) {
    var changed = false;
    values.forEach((k, v) {
      if (_data[k] == v && _data.containsKey(k)) return;
      _data[k] = v;
      changed = true;
    });
    if (changed) _changed();
  }

  /// Drops every value except the [keep] keys (and the schema version).
  void clear({Set<String> keep = const {}}) {
    _data.removeWhere((k, _) => k != schemaKey && !keep.contains(k));
    _changed();
  }

  void _changed() {
    _saveTimer?.cancel();
    _saveTimer = Timer(debounce, flush);
    notifyListeners();
  }

  /// Writes the blob now, cancelling a pending debounced save.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _prefs.setString(key, jsonEncode(_data));
  }

  /// Writes a pending change and stops the debounce timer.
  Future<void> close() async {
    if (_saveTimer?.isActive ?? false) await flush();
    _saveTimer?.cancel();
  }
}

/// The key of the blob's schema version.
const schemaKey = 'schema';

/// The current version of the settings blob.
///
/// 1: MPV Studio 0.2 (no version key).
/// 2: MPV Studio 0.3: adds the network, logging and raw option keys,
///    stores an automatic output driver as an empty string, and marks a
///    0.2 user as past the welcome screen.
const settingsSchema = 2;

/// Upgrades [data] from whichever schema wrote it to [settingsSchema],
/// keeping every value an older version stored.
@visibleForTesting
Map<String, Object?> migrateSettings(Map<String, Object?> data) {
  final out = Map<String, Object?>.of(data);
  final version = out[schemaKey];
  final from = version is num ? version.toInt() : 1;
  if (from < 2) {
    // 0.2 could store the driver picker's "auto" literally; mpv has no
    // driver of that name, and 0.3 stores automatic as empty.
    if (out['audioDriver'] == 'auto') out['audioDriver'] = '';
    // Someone who used 0.2 knows the app: the welcome screen is for a
    // first launch (Settings still opens it).
    if (out.isNotEmpty) out['onboarded'] = true;
  }
  out[schemaKey] = settingsSchema;
  return out;
}
