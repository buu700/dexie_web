@TestOn('browser')
library;

// ignore_for_file: implementation_imports

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';

import 'package:dexie_web/src/dexie_web_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'mock_dexie.dart';

JSAny? _evaluate(String script) {
  return globalContext.callMethodVarArgs<JSAny?>('eval'.toJS, [script.toJS]);
}

void _restoreLoaderFixture() {
  _evaluate('''
    const fixture = globalThis.__dexieLoaderFixture;
    if (fixture) {
      document.head.append = fixture.append;
      globalThis.Dexie = fixture.constructor;
      globalThis.__dexie_web_source = fixture.source;
      globalThis.__dexie_web_integrity = fixture.integrity;
      delete globalThis.__dexieLoaderFixture;
    }
  ''');
}

void main() {
  setUpAll(() {
    installMockDexie();
  });

  group('Dexie loader', () {
    test('ensureDexieInitialized is idempotent', () async {
      await ensureDexieInitialized();
      await ensureDexieInitialized();
    });

    test('concurrent load errors reach every caller and allow retry', () async {
      _evaluate('''
        globalThis.__dexieLoaderFixture = {
          constructor: globalThis.Dexie,
          source: globalThis.__dexie_web_source,
          integrity: globalThis.__dexie_web_integrity,
          append: document.head.append,
          scripts: []
        };
        delete globalThis.Dexie;
        delete globalThis.__dexie_web_source;
        delete globalThis.__dexie_web_integrity;
        document.head.append = function(script) {
          globalThis.__dexieLoaderFixture.scripts.push(script);
        };
      ''');
      addTearDown(_restoreLoaderFixture);

      final first = ensureDexieInitialized();
      final second = ensureDexieInitialized();
      final checks = [
        expectLater(first, throwsA(isA<StateError>())),
        expectLater(second, throwsA(isA<StateError>())),
      ];
      expect(_evaluate('__dexieLoaderFixture.scripts.length')?.dartify(), 1);
      final script =
          _evaluate('__dexieLoaderFixture.scripts[0]') as web.HTMLScriptElement;
      script.dispatchEvent(web.Event('error'));
      await Future.wait(checks).timeout(const Duration(seconds: 5));

      _restoreLoaderFixture();
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
