enum DexieLoadPolicy {
  strictPackage,
  strictGlobal,
  preferGlobalFallbackPackage,
}

DexieLoadPolicy _defaultDexieLoadPolicy = DexieLoadPolicy.strictPackage;

void setDefaultDexieLoadPolicy(DexieLoadPolicy policy) {
  _defaultDexieLoadPolicy = policy;
}

DexieLoadPolicy get defaultDexieLoadPolicy => _defaultDexieLoadPolicy;

Future<void> ensureDexieInitialized({DexieLoadPolicy? policy}) async {
  throw UnsupportedError('Dexie is only available on Flutter Web.');
}

abstract class DexieDatabase {
  DexieDatabase(this.name);
  final String name;

  Future<void> open(Map<String, String> schema);
  Future<void> put<T>(String tableName, T item);
  Future<T?> get<T>(String tableName, dynamic key);
  Future<List<T>> getAll<T>(String tableName);
  Future<List<T>> whereEquals<T>(String tableName, String index, dynamic value);
}
