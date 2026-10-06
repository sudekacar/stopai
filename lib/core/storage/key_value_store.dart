import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Basit anahtar-değer deposu.
///
/// Repository'ler doğrudan `SharedPreferences`'a değil bu arayüze bağlanır;
/// böylece testlerde [InMemoryKeyValueStore] ile çalışmak yeterli olur.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);

  /// JSON nesnesi okur; kayıt yoksa veya bozuksa `null` döner.
  Map<String, dynamic>? getJson(String key);

  Future<void> setJson(String key, Map<String, dynamic> value);
}

/// Cihazda kalıcı depolama.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._prefs);

  static Future<SharedPreferencesStore> open() async {
    return SharedPreferencesStore(await SharedPreferences.getInstance());
  }

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Map<String, dynamic>? getJson(String key) => _decodeJson(getString(key));

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));
}

/// Test ve önizleme için bellekte tutulan depo.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initialValues])
      : _values = {...?initialValues};

  final Map<String, String> _values;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

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
    // Bozuk kayıt: kullanıcıyı hata ekranıyla karşılamak yerine yok sayılır.
    return null;
  }
}
