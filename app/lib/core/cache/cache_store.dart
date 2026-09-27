import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

final class SharedPreferencesCacheStore implements CacheStore {
  const SharedPreferencesCacheStore();

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}
