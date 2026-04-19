import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';
import 'preferences_store.dart';

/// User-facing reminder configuration.
@immutable
class MealRemindersSettings {
  const MealRemindersSettings({
    required this.enabled,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  final bool enabled;
  final TimeOfDay breakfast;
  final TimeOfDay lunch;
  final TimeOfDay dinner;

  static const TimeOfDay defaultBreakfast = TimeOfDay(hour: 8, minute: 30);
  static const TimeOfDay defaultLunch = TimeOfDay(hour: 13, minute: 0);
  static const TimeOfDay defaultDinner = TimeOfDay(hour: 20, minute: 0);

  static const MealRemindersSettings disabled = MealRemindersSettings(
    enabled: false,
    breakfast: defaultBreakfast,
    lunch: defaultLunch,
    dinner: defaultDinner,
  );

  MealRemindersSettings copyWith({
    bool? enabled,
    TimeOfDay? breakfast,
    TimeOfDay? lunch,
    TimeOfDay? dinner,
  }) {
    return MealRemindersSettings(
      enabled: enabled ?? this.enabled,
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      dinner: dinner ?? this.dinner,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'breakfast': _encodeTime(breakfast),
        'lunch': _encodeTime(lunch),
        'dinner': _encodeTime(dinner),
      };

  factory MealRemindersSettings.fromJson(Map<String, dynamic> json) {
    return MealRemindersSettings(
      enabled: json['enabled'] as bool? ?? false,
      breakfast: _decodeTime(json['breakfast'] as String?, defaultBreakfast),
      lunch: _decodeTime(json['lunch'] as String?, defaultLunch),
      dinner: _decodeTime(json['dinner'] as String?, defaultDinner),
    );
  }

  static String _encodeTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _decodeTime(String? value, TimeOfDay fallback) {
    if (value == null) return fallback;
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]) ?? fallback.hour;
    final m = int.tryParse(parts[1]) ?? fallback.minute;
    return TimeOfDay(hour: h, minute: m);
  }
}

class MealRemindersController extends StateNotifier<MealRemindersSettings> {
  MealRemindersController(this._store, this._notifications)
      : super(_load(_store));

  static const String _key = 'meal_reminders';

  final PreferencesStore _store;
  final NotificationService _notifications;

  static MealRemindersSettings _load(PreferencesStore store) {
    final raw = store.getString(_key);
    if (raw == null || raw.isEmpty) return MealRemindersSettings.disabled;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MealRemindersSettings.fromJson(json);
    } catch (_) {
      return MealRemindersSettings.disabled;
    }
  }

  Future<void> _persist() async {
    await _store.setString(_key, jsonEncode(state.toJson()));
  }

  /// Re-applies the current settings to the OS — reschedules everything if
  /// enabled, cancels everything otherwise. Call on app start and after
  /// every change.
  Future<void> apply() async {
    if (!state.enabled) {
      await _notifications.cancelAll();
      return;
    }
    await _notifications.cancelAll();
    await _notifications.scheduleDaily(
      slot: MealReminderSlot.breakfast,
      hour: state.breakfast.hour,
      minute: state.breakfast.minute,
    );
    await _notifications.scheduleDaily(
      slot: MealReminderSlot.lunch,
      hour: state.lunch.hour,
      minute: state.lunch.minute,
    );
    await _notifications.scheduleDaily(
      slot: MealReminderSlot.dinner,
      hour: state.dinner.hour,
      minute: state.dinner.minute,
    );
  }

  /// Toggles the reminders on/off. When turning on, asks for OS permission
  /// — if the user denies, [enabled] is reverted to false.
  Future<bool> setEnabled(bool value) async {
    if (value) {
      final granted = await _notifications.requestPermissions();
      if (!granted) {
        state = state.copyWith(enabled: false);
        await _persist();
        await _notifications.cancelAll();
        return false;
      }
    }
    state = state.copyWith(enabled: value);
    await _persist();
    await apply();
    return value;
  }

  Future<void> setBreakfast(TimeOfDay time) async {
    state = state.copyWith(breakfast: time);
    await _persist();
    if (state.enabled) await apply();
  }

  Future<void> setLunch(TimeOfDay time) async {
    state = state.copyWith(lunch: time);
    await _persist();
    if (state.enabled) await apply();
  }

  Future<void> setDinner(TimeOfDay time) async {
    state = state.copyWith(dinner: time);
    await _persist();
    if (state.enabled) await apply();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final mealRemindersControllerProvider =
    StateNotifierProvider<MealRemindersController, MealRemindersSettings>(
  (ref) {
    return MealRemindersController(
      ref.watch(preferencesStoreProvider),
      ref.watch(notificationServiceProvider),
    );
  },
);
