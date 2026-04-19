import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lazy singleton for [SharedPreferences]. Initialized at app start in
/// [main] so synchronous lookups in providers are safe.
class PreferencesStore {
  PreferencesStore._(this._prefs);

  static PreferencesStore? _instance;

  final SharedPreferences _prefs;

  static Future<PreferencesStore> ensureInitialized() async {
    final existing = _instance;
    if (existing != null) return existing;
    final prefs = await SharedPreferences.getInstance();
    final store = PreferencesStore._(prefs);
    _instance = store;
    return store;
  }

  static PreferencesStore get instance {
    final existing = _instance;
    if (existing == null) {
      throw StateError(
        'PreferencesStore not initialized. Call ensureInitialized() first.',
      );
    }
    return existing;
  }

  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  Future<bool> remove(String key) => _prefs.remove(key);
}

final preferencesStoreProvider = Provider<PreferencesStore>((ref) {
  return PreferencesStore.instance;
});
