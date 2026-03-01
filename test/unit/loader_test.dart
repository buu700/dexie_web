@TestOn('browser')
library;

// ignore_for_file: implementation_imports

import 'dart:math';

import 'package:dexie_web/src/dexie_web_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_dexie.dart';

void main() {
  setUpAll(() {
    installMockDexie();
  });

  group('Dexie loader', () {
    test('ensureDexieInitialized is idempotent', () async {
      await ensureDexieInitialized();
      await ensureDexieInitialized();
    });

    test('open and first write succeed after loader init', () async {
      await ensureDexieInitialized();
      final dbName =
          'loader_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
      final db = DexieDatabase(dbName);

      await db.open({'items': '++id, name'});
      await db.put('items', {'name': 'first'});
      final rows = await db.getAll<Map>('items');
      expect(rows, hasLength(1));
    });
  });
}
