import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan sederhana (tidak sensitif) disimpan di shared_preferences.
class SettingsStore {
  static final _prefs = SharedPreferencesAsync();
  static const _meetingKey = 'meeting_point';
  static const defaultMeetingPoint = 'Gedung Vokasi UB (Lt. 2)';

  static Future<void> saveMeetingPoint(String value) =>
      _prefs.setString(_meetingKey, value);

  static Future<String> loadMeetingPoint() async =>
      await _prefs.getString(_meetingKey) ?? defaultMeetingPoint;
}