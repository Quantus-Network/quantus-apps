abstract class StorageService {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<Map<String, String>> readAll();
  Future<void> deleteAll();
  Future<void> setBool(String key, bool value);
  Future<bool?> getBool(String key);
  Future<void> remove(String key);
}
