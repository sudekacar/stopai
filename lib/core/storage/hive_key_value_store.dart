import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'key_value_store.dart';

/// Hive tabanlı kalıcı anahtar-değer deposu.
///
/// Profil, paket durumu ve test sonuçları bu kutuda tutulur; çevrimdışıyken
/// SharedPreferences'a göre daha tutarlı okunur.
class HiveKeyValueStore implements KeyValueStore {
  HiveKeyValueStore(this._box);

  static const String boxName = 'stopkoc.kv';

  final Box<String> _box;

  static Future<HiveKeyValueStore> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(boxName);
    return HiveKeyValueStore(box);
  }

  @override
  String? getString(String key) => _box.get(key);

  @override
  Future<void> setString(String key, String value) => _box.put(key, value);

  @override
  Future<void> remove(String key) => _box.delete(key);

  @override
  Map<String, dynamic>? getJson(String key) => _decodeJson(getString(key));

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));
}

Map<String, dynamic>? _decodeJson(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
