import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  Future<void> writeString({
    required String key,
    required String value,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      key,
      value,
    );
  }

  Future<String?> readString(String key) async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getString(key);
  }

  Future<void> writeBool({
    required String key,
    required bool value,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(
      key,
      value,
    );
  }

  Future<bool?> readBool(String key) async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getBool(key);
  }

  Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(key);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.clear();
  }
}