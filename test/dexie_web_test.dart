import 'package:dexie_web/dexie_web.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDexieDatabase extends DexieDatabase {
  _FakeDexieDatabase(super.name);

  @override
  void close() {}

  @override
  Future<T?> get<T>(String tableName, dynamic key) async => null;

  @override
  Future<List<T>> getAll<T>(String tableName) async => <T>[];

  @override
  Future<void> open(Map<String, String> schema) async {}

  @override
  Future<void> put<T>(String tableName, T item) async {}

  @override
  Future<List<T>> whereEquals<T>(
    String tableName,
    String index,
    dynamic value,
  ) async => <T>[];
}

void main() {
  test('stub API shape is usable on non-web platforms', () async {
    final db = _FakeDexieDatabase('test');

    await db.open({'items': '++id, name'});
    await db.put('items', {'name': 'n'});

    expect(await db.get<Map>('items', 1), isNull);
    expect(await db.getAll<Map>('items'), isEmpty);
    expect(await db.whereEquals<Map>('items', 'name', 'n'), isEmpty);
  });
}
