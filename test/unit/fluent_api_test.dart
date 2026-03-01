@TestOn('browser')
library;

// ignore_for_file: implementation_imports

import 'dart:math';

import 'package:dexie_web/src/dexie_web_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_dexie.dart';

String _dbName(String prefix) {
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
}

void main() {
  setUpAll(() {
    installMockDexie();
  });

  group('Dexie schema validation', () {
    test('unknown table throws StateError', () async {
      final db = DexieDatabase(_dbName('schema_table'));
      await db.open({'friends': '++id, name, age'});

      await expectLater(
        db.getAll<Map<String, dynamic>>('missing'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => db.table<Map<String, dynamic>, dynamic, Map<String, dynamic>>(
          'missing',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('unknown index throws StateError', () async {
      final db = DexieDatabase(_dbName('schema_index'));
      await db.open({'friends': '++id, name, age'});

      await expectLater(
        db.whereEquals<Map<String, dynamic>>('friends', 'missing', 1),
        throwsA(isA<StateError>()),
      );
      expect(
        () => db
            .table<Map<String, dynamic>, dynamic, Map<String, dynamic>>(
              'friends',
            )
            .whereIndex('missing'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Dexie helper methods', () {
    test('delete / whereStartsWith / deleteWhereStartsWith', () async {
      final db = DexieDatabase(_dbName('helpers'));
      await db.open({'friends': '++id, name, city'});

      await db.put('friends', {'name': 'Alice', 'city': 'Austin'});
      await db.put('friends', {'name': 'Alfred', 'city': 'Albany'});
      await db.put('friends', {'name': 'Bob', 'city': 'Boston'});

      final prefixed = await db.whereStartsWith<Map<String, dynamic>>(
        'friends',
        'name',
        'Al',
      );
      expect(prefixed, hasLength(2));

      await db.deleteWhereStartsWith('friends', 'name', 'Al');
      final remaining = await db.getAll<Map<String, dynamic>>('friends');
      expect(remaining, hasLength(1));
      expect(remaining.first['name'], 'Bob');

      final id = remaining.first['id'];
      await db.delete('friends', id);
      expect(await db.getAll<Map<String, dynamic>>('friends'), isEmpty);
    });
  });

  group('Dexie fluent API', () {
    test('table / where / collection methods work', () async {
      final db = DexieDatabase(_dbName('fluent'));
      await db.open({'friends': '++id, name, age, city'});

      final table = db
          .table<Map<String, dynamic>, dynamic, Map<String, dynamic>>(
            'friends',
          );

      await table.bulkPut([
        {'name': 'Alice', 'age': 30, 'city': 'Austin'},
        {'name': 'Alfred', 'age': 31, 'city': 'Albany'},
        {'name': 'Bob', 'age': 22, 'city': 'Boston'},
      ]);

      expect(await table.count(), 3);
      expect((await table.toArray()).length, 3);
      expect((await table.limit(2).toArray()).length, 2);
      expect((await table.offset(1).toArray()).length, 2);

      final whereClause = table.whereIndex('name');
      final startsWithAl = await whereClause.startsWith('Al').toList();
      expect(startsWithAl.length, 2);

      final adults = await table
          .whereIndex('age')
          .aboveOrEqual(30)
          .reverse()
          .toArray();
      expect(adults.length, 2);

      final collection = table.toCollection();
      expect(await collection.count(), 3);
      expect(await collection.first(), isA<Map<String, dynamic>>());
      expect(await collection.last(), isA<Map<String, dynamic>>());
      expect((await collection.keys()).length, 3);
      expect((await collection.primaryKeys()).length, 3);
      expect((await collection.uniqueKeys()).length, 3);

      final sorted = await collection.sortBy('name');
      expect(sorted.first['name'], 'Alfred');

      await collection.modify({'city': 'Updated'});
      final updated = await table.toArray();
      expect(updated.every((row) => row['city'] == 'Updated'), isTrue);

      final ids = (await table.toArray()).map((row) => row['id']).toList();
      final bulkGot = await table.bulkGet(ids);
      expect(bulkGot.length, 3);

      await table.bulkDelete([ids.first]);
      expect(await table.count(), 2);

      await table.clear();
      expect(await table.count(), 0);
    });

    test(
      'where-clause and collection operators are exercised directly',
      () async {
        final db = DexieDatabase(_dbName('fluent_ops'));
        await db.open({'friends': '++id, name, age, city'});
        final table = db
            .table<Map<String, dynamic>, dynamic, Map<String, dynamic>>(
              'friends',
            );

        await table.bulkPut([
          {'name': 'Alice', 'age': 30, 'city': 'Austin'},
          {'name': 'Alfred', 'age': 31, 'city': 'Albany'},
          {'name': 'Bob', 'age': 22, 'city': 'Boston'},
          {'name': 'Eve', 'age': 30, 'city': 'El Paso'},
        ]);

        expect(await table.whereIndex('age').above(30).count(), 1);
        expect(await table.whereIndex('age').below(30).count(), 1);
        expect(await table.whereIndex('age').belowOrEqual(30).count(), 3);
        expect(await table.whereIndex('age').between(30, 31).count(), 3);
        expect(await table.whereIndex('age').anyOf([22, 31]).count(), 2);
        expect(await table.whereIndex('age').noneOf([22, 31]).count(), 2);
        expect(await table.whereIndex('age').notEqual(30).count(), 2);
        expect(await table.whereIndex('name').equals('Alice').count(), 1);
        expect(
          await table.whereIndex('name').equalsIgnoreCase('alice').count(),
          1,
        );
        expect(
          await table.whereIndex('name').anyOfIgnoreCase([
            'ALICE',
            'eVe',
          ]).count(),
          2,
        );
        expect(
          await table.whereIndex('name').startsWithAnyOf(['Al', 'Bo']).count(),
          3,
        );
        expect(
          await table.whereIndex('name').startsWithAnyOfIgnoreCase([
            'al',
            'ev',
          ]).count(),
          3,
        );
        expect(
          await table.whereIndex('name').startsWithIgnoreCase('al').count(),
          2,
        );
        expect(
          await table
              .whereIndex('age')
              .inAnyRange(
                [
                  [22, 22],
                  [31, 31],
                ],
                includeLowers: true,
                includeUppers: true,
              )
              .count(),
          2,
        );

        final filtered = table.toCollection().filter((row) => row['age'] == 30);
        expect(await filtered.count(), 2);
        expect(await filtered.clone().count(), 2);
        expect(await filtered.distinct().count(), 2);
        expect(await filtered.limit(1).count(), 1);
        expect(await filtered.offset(1).count(), 1);
        expect(await filtered.raw().count(), 2);
        expect(await filtered.reverse().count(), 2);
        expect(await filtered.until((_) => true).count(), 0);
        expect(
          await filtered.until((_) => true, includeStopEntry: true).count(),
          1,
        );

        var eachSeen = 0;
        await filtered.each((_, __) => eachSeen++);
        expect(eachSeen, 2);

        var eachKeySeen = 0;
        await filtered.eachKey((_, __) => eachKeySeen++);
        expect(eachKeySeen, 2);

        var eachPrimaryKeySeen = 0;
        await filtered.eachPrimaryKey((_, __) => eachPrimaryKeySeen++);
        expect(eachPrimaryKeySeen, 2);

        var eachUniqueKeySeen = 0;
        await filtered.eachUniqueKey((_, __) => eachUniqueKeySeen++);
        expect(eachUniqueKeySeen, 2);

        await filtered
            .and((row) => row['city'].toString().startsWith('A'))
            .modify({'city': 'Updated'});
        final updatedCities = await table
            .whereIndex('name')
            .startsWith('Al')
            .toArray();
        final alice = updatedCities.firstWhere((row) => row['name'] == 'Alice');
        final alfred = updatedCities.firstWhere(
          (row) => row['name'] == 'Alfred',
        );
        expect(alice['city'], 'Updated');
        expect(alfred['city'], 'Albany');

        final firstKey = await filtered.firstKey();
        expect(firstKey, isNotNull);
        expect(await filtered.lastKey(), isNotNull);
        expect(await filtered.keys(), isNotEmpty);
        expect(await filtered.primaryKeys(), isNotEmpty);
        expect(await filtered.uniqueKeys(), isNotEmpty);

        final orCount = await table
            .whereIndex('age')
            .equals(22)
            .or('name')
            .startsWith('Al')
            .count();
        expect(orCount, isA<int>());
      },
    );
  });
}
