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

  group('Dexie data fidelity', () {
    late DexieDatabase db;

    setUp(() async {
      final dbName =
          'converters_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
      db = DexieDatabase(dbName);
      await db.open({
        'records': '++id, name, age, active, nested, tags, birthday',
      });
    });

    test(
      'roundtrip accepts complex payloads and preserves retrievable ids',
      () async {
        final birthday = DateTime.utc(1995, 6, 15, 13, 4, 5);
        await db.put('records', {
          'name': 'Alice',
          'age': 30,
          'active': true,
          'score': 7.5,
          'nullable': null,
          'birthday': birthday,
          'nested': {'city': 'Boston', 'zip': 2101},
          'tags': [
            'flutter',
            'dexie',
            {'k': 'v'},
          ],
        });

        final rows = await db.getAll<Map<String, dynamic>>('records');
        expect(rows, hasLength(1));

        final row = rows.first;
        expect(row['id'], isA<int>());

        final byId = await db.get<Map<String, dynamic>>('records', row['id']);
        expect(byId, isNotNull);
        expect(byId!['id'], row['id']);
      },
    );
  });
}
