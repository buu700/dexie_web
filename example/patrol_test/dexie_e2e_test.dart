// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';

import 'package:dexie_web/src/dexie_sri.g.dart';
import 'package:dexie_web/src/dexie_web_impl.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:patrol/patrol.dart';
import 'package:web/web.dart' as web;

@JS('globalThis')
external JSObject get _globalThis;

Future<void> _deleteDbByName(String dbName) async {
  final indexedDb = web.window.indexedDB;
  final completer = Completer<void>();
  final request = indexedDb.deleteDatabase(dbName);

  request.onsuccess = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('Failed to delete IndexedDB database "$dbName".'),
      );
    }
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!completer.isCompleted) {
      // Best-effort cleanup only. Tests use unique DB names, so a blocked
      // delete should not hang the suite.
      completer.complete();
    }
  }).toJS;

  await completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      // Avoid CI hangs from flaky IndexedDB cleanup semantics in headless runs.
    },
  );
}

String _uniqueDbName(String prefix) {
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
}

void _resetDexieGlobals() {
  globalContext.callMethodVarArgs<JSAny?>('eval'.toJS, [
    '''
    (function() {
      try { delete globalThis.Dexie; } catch (_) {}
      try { delete globalThis.__dexie_web_source; } catch (_) {}
      try { delete globalThis.__dexie_web_integrity; } catch (_) {}
      const scripts = document.querySelectorAll('script[src*="dexie.min.js"]');
      for (const script of scripts) {
        script.remove();
      }
    })();
  '''
        .toJS,
  ]);
}

const Map<String, String> _friendsSchema = {
  'friends': '++id, name, age, birthday, city',
};

void main() {
  patrolTest('bundled Dexie asset hash matches generated SRI constant', (
    $,
  ) async {
    final bytes = await _loadDexieAssetBytes();
    final digestBase64 = base64.encode(sha384.convert(bytes).bytes);
    expect(dexieScriptIntegrity, 'sha384-$digestBase64');
  });

  patrolTest('open initializes a usable database instance', ($) async {
    _resetDexieGlobals();
    final dbName = _uniqueDbName('dexie_e2e');
    final db = DexieDatabase(dbName);
    try {
      await db.open(_friendsSchema);
      expect(db.name, dbName);
    } finally {
      db.close();
      await _deleteDbByName(dbName);
    }
  });

  patrolTest('ensureDexieInitialized is idempotent', ($) async {
    _resetDexieGlobals();
    final dbName = _uniqueDbName('dexie_e2e_loader');
    final db = DexieDatabase(dbName);
    try {
      await db.open(_friendsSchema);

      await ensureDexieInitialized();
      await ensureDexieInitialized();

      final scriptCount = web.document
          .querySelectorAll('script[src*="dexie.min.js"]')
          .length;
      expect(scriptCount, greaterThan(0));

      final script =
          web.document.querySelector('script[src*="dexie.min.js"]')
              as web.HTMLScriptElement?;
      expect(script, isNotNull);
      expect(script!.integrity, dexieScriptIntegrity);

      final source = _globalThis.getProperty('__dexie_web_source'.toJS);
      final integrity = _globalThis.getProperty('__dexie_web_integrity'.toJS);
      expect(source.dartify(), 'dexie_web');
      expect(integrity.dartify(), dexieScriptIntegrity);
    } finally {
      db.close();
      await _deleteDbByName(dbName);
    }
  });

  patrolTest('CRUD, query, and persistence work across instances', ($) async {
    _resetDexieGlobals();
    final dbName = _uniqueDbName('dexie_e2e_data');
    final db1 = DexieDatabase(dbName);
    final db2 = DexieDatabase(dbName);
    try {
      await db1.open(_friendsSchema);
      await db1.put('friends', {
        'name': 'Bob',
        'age': 25,
        'birthday': DateTime.utc(2000, 1, 1),
        'city': 'Boston',
        'nested': {'state': 'MA'},
        'tags': ['flutter', 'dexie'],
        'nullable': null,
      });
      await db1.put('friends', {'name': 'Eve', 'age': 17, 'city': 'Denver'});

      final all = await db1.getAll<Map<String, dynamic>>('friends');
      expect(all, hasLength(2));
      expect(all.map((r) => r['name']).toSet(), {'Bob', 'Eve'});

      final adults = await db1.whereEquals<Map<String, dynamic>>(
        'friends',
        'age',
        25,
      );
      expect(adults, hasLength(1));
      expect(adults.first['name'], 'Bob');

      final noMatches = await db1.whereEquals<Map<String, dynamic>>(
        'friends',
        'age',
        99,
      );
      expect(noMatches, isEmpty);

      await db2.open(_friendsSchema);
      final persisted = await db2.getAll<Map<String, dynamic>>('friends');
      expect(persisted, hasLength(2));
      final bob = persisted.firstWhere((row) => row['name'] == 'Bob');
      expect(bob['birthday'], isA<DateTime>());
      expect((bob['birthday'] as DateTime).toUtc(), DateTime.utc(2000, 1, 1));
      expect((bob['nested'] as Map<String, dynamic>)['state'], 'MA');
    } finally {
      db2.close();
      db1.close();
      await _deleteDbByName(dbName);
    }
  });

  patrolTest('invalid table/index operations propagate runtime errors', (
    $,
  ) async {
    _resetDexieGlobals();
    final dbName = _uniqueDbName('dexie_e2e_errors');
    final db = DexieDatabase(dbName);
    try {
      await db.open(_friendsSchema);
      await _expectFutureThrowsWithoutHanging(
        db.getAll<Map<String, dynamic>>('does_not_exist'),
        expectedErrorType: StateError,
      );
      await _expectFutureThrowsWithoutHanging(
        db.whereEquals<Map<String, dynamic>>('friends', 'does_not_exist', 1),
        expectedErrorType: StateError,
      );
    } finally {
      db.close();
      await _deleteDbByName(dbName);
    }
  });

  patrolTest('calling table operation before open throws StateError', (
    $,
  ) async {
    _resetDexieGlobals();
    final unopened = DexieDatabase(_uniqueDbName('dexie_unopened'));
    await expectLater(
      unopened.getAll<dynamic>('friends'),
      throwsA(isA<StateError>()),
    );
  });
}

Future<Uint8List> _loadDexieAssetBytes() async {
  final data = await rootBundle.load('packages/dexie_web/assets/dexie.min.js');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<void> _expectFutureThrowsWithoutHanging(
  Future<Object?> future, {
  Duration timeout = const Duration(seconds: 10),
  Type? expectedErrorType,
}) async {
  try {
    await future.timeout(timeout);
    fail('Expected an exception, but the future completed successfully.');
  } on TimeoutException {
    fail(
      'Expected an exception, but the future timed out after '
      '${timeout.inSeconds}s.',
    );
  } catch (error) {
    if (expectedErrorType == null) {
      return;
    }
    if (error.runtimeType != expectedErrorType) {
      fail('Expected $expectedErrorType, but got ${error.runtimeType}.');
    }
  }
}
