library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dexie_web/src/dexie_sri.g.dart';

void installMockDexie() {
  globalContext.callMethodVarArgs<JSAny?>('eval'.toJS, [
    '''
    (function() {
      if (globalThis.__dexieMockInstalled) return;
      globalThis.__dexieMockInstalled = true;
      globalThis.__dexie_web_source = 'dexie_web';
      globalThis.__dexie_web_sha384 = '$dexieScriptSha384Base64';
      globalThis.__dexieMockDatabases = new Map();

      class MockCollection {
        constructor(items) { this.items = items; }
        toArray() { return Promise.resolve(this.items.map(item => ({...item}))); }
      }

      class MockWhereClause {
        constructor(items, index) {
          this.items = items;
          this.index = index;
        }
        equals(value) {
          return new MockCollection(this.items.filter(item => item[this.index] === value));
        }
      }

      class MockTable {
        constructor(dbStore, tableName) {
          this.dbStore = dbStore;
          this.tableName = tableName;
          if (!this.dbStore.tables.has(this.tableName)) {
            this.dbStore.tables.set(this.tableName, []);
            this.dbStore.counters.set(this.tableName, 0);
          }
        }
        put(item) {
          const cloned = item == null ? item : JSON.parse(JSON.stringify(item));
          const rows = this.dbStore.tables.get(this.tableName);
          if (cloned && cloned.id == null) {
            const next = (this.dbStore.counters.get(this.tableName) || 0) + 1;
            this.dbStore.counters.set(this.tableName, next);
            cloned.id = next;
          }
          rows.push(cloned);
          return Promise.resolve(cloned?.id ?? undefined);
        }
        get(key) {
          const rows = this.dbStore.tables.get(this.tableName);
          const found = rows.find(row => row && row.id === key);
          return Promise.resolve(found ? {...found} : undefined);
        }
        toArray() {
          const rows = this.dbStore.tables.get(this.tableName);
          return Promise.resolve(rows.map(item => ({...item})));
        }
        where(index) {
          const rows = this.dbStore.tables.get(this.tableName);
          return new MockWhereClause(rows, index);
        }
      }

      globalThis.Dexie = class Dexie {
        constructor(name) {
          this.name = name;
          const dbs = globalThis.__dexieMockDatabases;
          if (!dbs.has(name)) {
            dbs.set(name, { tables: new Map(), counters: new Map() });
          }
          this._dbStore = dbs.get(name);
        }
        version() {
          return {
            stores: (_schema) => this
          };
        }
        open() { return Promise.resolve(this); }
        table(name) { return new MockTable(this._dbStore, name); }
      };
    })();
  '''
        .toJS,
  ]);
}
