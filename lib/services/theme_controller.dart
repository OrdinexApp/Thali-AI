import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_variant.dart';
import 'preferences_store.dart';

class ThemeController extends StateNotifier<ThemeVariant> {
  ThemeController(this._store)
      : super(ThemeVariant.fromName(_store.getString(_key)));

  static const String _key = 'theme_variant';

  final PreferencesStore _store;

  Future<void> set(ThemeVariant variant) async {
    if (state == variant) return;
    state = variant;
    await _store.setString(_key, variant.name);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeVariant>((ref) {
  return ThemeController(ref.watch(preferencesStoreProvider));
});
