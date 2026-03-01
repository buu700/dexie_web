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
  void close();

  DexieTable<T, TKey, TInsertType> table<T, TKey, TInsertType>(
    String tableName,
  ) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<void> put<T>(String tableName, T item);
  Future<T?> get<T>(String tableName, dynamic key);
  Future<List<T>> getAll<T>(String tableName);
  Future<List<T>> whereEquals<T>(String tableName, String index, dynamic value);

  Future<void> delete(String tableName, dynamic key) async {
    await table<dynamic, dynamic, dynamic>(tableName).delete(key);
  }

  Future<List<T>> whereStartsWith<T>(
    String tableName,
    String index,
    String prefix,
  ) async {
    return table<T, dynamic, T>(
      tableName,
    ).whereIndex(index).startsWith(prefix).toArray();
  }

  Future<void> deleteWhereStartsWith(
    String tableName,
    String index,
    String prefix,
  ) async {
    await table<dynamic, dynamic, dynamic>(
      tableName,
    ).whereIndex(index).startsWith(prefix).delete();
  }
}

class DexieTable<T, TKey, TInsertType> {
  DexieTable(this.tableName);
  final String tableName;

  Future<T?> get(dynamic keyOrCriteria) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Object where(dynamic indexOrCriteria) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieWhereClause<T, TKey, TInsertType> whereIndex(String index) {
    final clause = where(index);
    if (clause is DexieWhereClause<T, TKey, TInsertType>) {
      return clause;
    }
    throw StateError('where() did not return a DexieWhereClause.');
  }

  DexieCollection<T, TKey, TInsertType> whereCriteria(
    Map<String, dynamic> criteria,
  ) {
    final collection = where(criteria);
    if (collection is DexieCollection<T, TKey, TInsertType>) {
      return collection;
    }
    throw StateError('where() did not return a DexieCollection.');
  }

  DexieCollection<T, TKey, TInsertType> filter(bool Function(T obj) fn) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<int> count() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> offset(int n) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> limit(int n) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<void> each(void Function(T obj, dynamic cursor) callback) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<List<T>> toArray() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<List<T>> toList() => toArray();

  DexieCollection<T, TKey, TInsertType> toCollection() {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> orderBy(dynamic indexOrIndexes) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> reverse() {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  dynamic mapToClass(dynamic constructor) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<dynamic> add(TInsertType item, {dynamic key}) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<int> update(dynamic keyOrObject, dynamic changes) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<bool> upsert(dynamic keyOrObject, dynamic changes) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<dynamic> put(TInsertType item, {dynamic key}) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<void> delete(dynamic key) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<void> remove(dynamic key) => delete(key);

  Future<void> clear() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<void> removeAll() => clear();

  Future<List<T?>> bulkGet(List<dynamic> keys) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<dynamic> bulkAdd(
    List<TInsertType> items, {
    List<dynamic>? keys,
    bool? allKeys,
  }) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<dynamic> bulkPut(
    List<TInsertType> items, {
    List<dynamic>? keys,
    bool? allKeys,
  }) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<int> bulkUpdate(List<Map<String, dynamic>> keysAndChanges) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<void> bulkDelete(List<dynamic> keys) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }
}

class DexieWhereClause<T, TKey, TInsertType> {
  DexieWhereClause(this.tableName, this.indexName);
  final String tableName;
  final String indexName;

  DexieCollection<T, TKey, TInsertType> above(dynamic key) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> aboveOrEqual(dynamic key) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> anyOf(List<dynamic> keys) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> anyOfIgnoreCase(List<String> keys) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> below(dynamic key) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> belowOrEqual(dynamic key) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> between(
    dynamic lower,
    dynamic upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> equals(dynamic key) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> equalsIgnoreCase(String key) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> inAnyRange(
    List<List<dynamic>> ranges, {
    bool includeLowers = true,
    bool includeUppers = false,
  }) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> startsWith(String key) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> startsWithAnyOf(List<String> prefixes) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> startsWithIgnoreCase(String key) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> startsWithAnyOfIgnoreCase(
    List<String> prefixes,
  ) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> noneOf(List<dynamic> keys) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> notEqual(dynamic key) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }
}

class DexieCollection<T, TKey, TInsertType> {
  DexieCollection(this.tableName);
  final String tableName;

  DexieCollection<T, TKey, TInsertType> and(bool Function(T obj) filter) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> clone({Map<String, dynamic>? props}) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<int> count() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> distinct() {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<void> each(void Function(T obj, dynamic cursor) callback) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<void> eachKey(
    void Function(dynamic key, dynamic cursor) callback,
  ) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<void> eachPrimaryKey(
    void Function(dynamic key, dynamic cursor) callback,
  ) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<void> eachUniqueKey(
    void Function(dynamic key, dynamic cursor) callback,
  ) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> filter(bool Function(T obj) filter) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<T?> first() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<dynamic> firstKey() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<List<dynamic>> keys() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<List<dynamic>> primaryKeys() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<T?> last() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<dynamic> lastKey() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> limit(int n) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> offset(int n) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieWhereClause<T, TKey, TInsertType> or(String indexOrPrimaryKey) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> raw() {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> reverse() {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<List<T>> sortBy(String keyPath) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<List<T>> toArray() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<List<T>> toList() => toArray();

  Future<List<dynamic>> uniqueKeys() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  DexieCollection<T, TKey, TInsertType> until(
    bool Function(T value) filter, {
    bool includeStopEntry = false,
  }) {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<int> delete() async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }

  Future<int> remove() => delete();

  Future<int> modify(dynamic changeCallbackOrChanges) async {
    throw UnsupportedError('Dexie is only available on Flutter Web.');
  }
}
