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
      globalThis.__dexie_web_integrity = '$dexieScriptIntegrity';
      globalThis.__dexieMockDatabases = new Map();

      const clone = (value) => {
        if (value == null) return value;
        if (typeof structuredClone === 'function') return structuredClone(value);
        return JSON.parse(JSON.stringify(value));
      };

      const deepEqual = (a, b) => JSON.stringify(a) === JSON.stringify(b);

      const getByPath = (obj, path) => {
        if (obj == null) return undefined;
        if (path === ':id') return obj.id;
        if (path.startsWith('[') && path.endsWith(']')) {
          const fields = path.slice(1, -1).split('+');
          return fields.map((field) => getByPath(obj, field));
        }
        const segments = path.split('.');
        let current = obj;
        for (const segment of segments) {
          if (current == null) return undefined;
          current = current[segment];
        }
        return current;
      };

      class MockCollection {
        constructor(items, dbStore, tableName) {
          this.items = items;
          this.dbStore = dbStore;
          this.tableName = tableName;
        }

        _cursor(item) {
          return { key: item?.id, primaryKey: item?.id };
        }

        _derive(items) {
          return new MockCollection(items, this.dbStore, this.tableName);
        }

        and(filter) { return this.filter(filter); }

        clone() { return this._derive([...this.items]); }

        count() { return Promise.resolve(this.items.length); }

        distinct() {
          const seen = new Set();
          const distinct = [];
          for (const item of this.items) {
            const key = JSON.stringify(item);
            if (!seen.has(key)) {
              seen.add(key);
              distinct.push(item);
            }
          }
          return this._derive(distinct);
        }

        each(callback) {
          this.items.forEach((item) => callback(clone(item), this._cursor(item)));
          return Promise.resolve();
        }

        eachKey(callback) {
          this.items.forEach((item) => callback(item?.id, this._cursor(item)));
          return Promise.resolve();
        }

        eachPrimaryKey(callback) {
          this.items.forEach((item) => callback(item?.id, this._cursor(item)));
          return Promise.resolve();
        }

        eachUniqueKey(callback) {
          const seen = new Set();
          this.items.forEach((item) => {
            if (!seen.has(item?.id)) {
              seen.add(item?.id);
              callback(item?.id, this._cursor(item));
            }
          });
          return Promise.resolve();
        }

        filter(filter) {
          return this._derive(this.items.filter((item) => !!filter(clone(item))));
        }

        first() { return Promise.resolve(this.items.length ? clone(this.items[0]) : undefined); }

        firstKey() { return Promise.resolve(this.items.length ? this.items[0]?.id : undefined); }

        keys() { return Promise.resolve(this.items.map((item) => item?.id)); }

        primaryKeys() { return Promise.resolve(this.items.map((item) => item?.id)); }

        last() {
          return Promise.resolve(
            this.items.length ? clone(this.items[this.items.length - 1]) : undefined,
          );
        }

        lastKey() {
          return Promise.resolve(
            this.items.length ? this.items[this.items.length - 1]?.id : undefined,
          );
        }

        limit(n) { return this._derive(this.items.slice(0, n)); }

        offset(n) { return this._derive(this.items.slice(n)); }

        or(indexOrPrimaryKey) {
          return new MockWhereClause(this.items, indexOrPrimaryKey, this.dbStore, this.tableName);
        }

        raw() { return this._derive(this.items); }

        reverse() { return this._derive([...this.items].reverse()); }

        sortBy(keyPath) {
          const sorted = [...this.items].sort((a, b) => {
            const av = getByPath(a, keyPath);
            const bv = getByPath(b, keyPath);
            if (av == null && bv == null) return 0;
            if (av == null) return -1;
            if (bv == null) return 1;
            if (av < bv) return -1;
            if (av > bv) return 1;
            return 0;
          });
          return Promise.resolve(sorted.map(clone));
        }

        toArray() { return Promise.resolve(this.items.map(clone)); }

        uniqueKeys() {
          return Promise.resolve([...new Set(this.items.map((item) => item?.id))]);
        }

        until(filter, includeStopEntry = false) {
          const out = [];
          for (const item of this.items) {
            const shouldStop = !!filter(clone(item));
            if (shouldStop) {
              if (includeStopEntry) out.push(item);
              break;
            }
            out.push(item);
          }
          return this._derive(out);
        }

        delete() {
          const ids = new Set(this.items.map((item) => item?.id));
          const rows = this.dbStore.tables.get(this.tableName);
          const originalLength = rows.length;
          const kept = rows.filter((row) => !ids.has(row?.id));
          this.dbStore.tables.set(this.tableName, kept);
          return Promise.resolve(originalLength - kept.length);
        }

        modify(changesOrCallback) {
          const rows = this.dbStore.tables.get(this.tableName);
          let updated = 0;
          for (const row of rows) {
            if (!this.items.some((item) => item?.id === row?.id)) continue;
            if (typeof changesOrCallback === 'function') {
              const result = changesOrCallback(row, { value: row });
              if (result === false) continue;
            } else if (changesOrCallback && typeof changesOrCallback === 'object') {
              Object.assign(row, clone(changesOrCallback));
            }
            updated++;
          }
          return Promise.resolve(updated);
        }
      }

      class MockWhereClause {
        constructor(items, index, dbStore, tableName) {
          this.items = items;
          this.index = index;
          this.dbStore = dbStore;
          this.tableName = tableName;
        }

        _collection(filterFn) {
          return new MockCollection(
            this.items.filter((item) => filterFn(getByPath(item, this.index), item)),
            this.dbStore,
            this.tableName,
          );
        }

        above(key) { return this._collection((value) => value > key); }

        aboveOrEqual(key) { return this._collection((value) => value >= key); }

        anyOf(keys) {
          const values = Array.isArray(keys) ? keys : Array.from(arguments);
          return this._collection((value) => values.some((entry) => deepEqual(value, entry)));
        }

        anyOfIgnoreCase(keys) {
          const values = Array.isArray(keys) ? keys : Array.from(arguments);
          const normalized = values.map((entry) => String(entry).toLowerCase());
          return this._collection((value) => normalized.includes(String(value).toLowerCase()));
        }

        below(key) { return this._collection((value) => value < key); }

        belowOrEqual(key) { return this._collection((value) => value <= key); }

        between(lower, upper, includeLower = true, includeUpper = true) {
          return this._collection((value) => {
            const lowerOk = includeLower ? value >= lower : value > lower;
            const upperOk = includeUpper ? value <= upper : value < upper;
            return lowerOk && upperOk;
          });
        }

        equals(key) { return this._collection((value) => deepEqual(value, key)); }

        equalsIgnoreCase(key) {
          return this._collection((value) => String(value).toLowerCase() === key.toLowerCase());
        }

        inAnyRange(ranges, options) {
          const includeLowers = options?.includeLowers ?? true;
          const includeUppers = options?.includeUppers ?? false;
          return this._collection((value) =>
            ranges.some(([lower, upper]) => {
              const lowerOk = includeLowers ? value >= lower : value > lower;
              const upperOk = includeUppers ? value <= upper : value < upper;
              return lowerOk && upperOk;
            }),
          );
        }

        startsWith(prefix) {
          return this._collection((value) => String(value ?? '').startsWith(prefix));
        }

        startsWithAnyOf(prefixes) {
          const values = Array.isArray(prefixes) ? prefixes : Array.from(arguments);
          return this._collection((value) =>
            values.some((prefix) => String(value ?? '').startsWith(String(prefix))),
          );
        }

        startsWithIgnoreCase(prefix) {
          const normalized = prefix.toLowerCase();
          return this._collection((value) =>
            String(value ?? '').toLowerCase().startsWith(normalized),
          );
        }

        startsWithAnyOfIgnoreCase(prefixes) {
          const values = (Array.isArray(prefixes) ? prefixes : Array.from(arguments)).map(
            (entry) => String(entry).toLowerCase(),
          );
          return this._collection((value) =>
            values.some((prefix) => String(value ?? '').toLowerCase().startsWith(prefix)),
          );
        }

        noneOf(keys) {
          return this._collection((value) => !keys.some((entry) => deepEqual(value, entry)));
        }

        notEqual(key) { return this._collection((value) => !deepEqual(value, key)); }
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

        _rows() {
          return this.dbStore.tables.get(this.tableName);
        }

        _nextId() {
          const next = (this.dbStore.counters.get(this.tableName) || 0) + 1;
          this.dbStore.counters.set(this.tableName, next);
          return next;
        }

        _findIndexById(id) {
          return this._rows().findIndex((row) => row?.id === id);
        }

        get(keyOrCriteria) {
          if (keyOrCriteria != null && typeof keyOrCriteria === 'object' && !Array.isArray(keyOrCriteria)) {
            const found = this._rows().find((row) =>
              Object.entries(keyOrCriteria).every(([key, value]) => deepEqual(row?.[key], value)),
            );
            return Promise.resolve(found ? clone(found) : undefined);
          }
          const found = this._rows().find((row) => row?.id === keyOrCriteria);
          return Promise.resolve(found ? clone(found) : undefined);
        }

        where(indexOrCriteria) {
          if (indexOrCriteria != null && typeof indexOrCriteria === 'object' && !Array.isArray(indexOrCriteria)) {
            const rows = this._rows().filter((row) =>
              Object.entries(indexOrCriteria).every(([key, value]) => deepEqual(row?.[key], value)),
            );
            return new MockCollection(rows, this.dbStore, this.tableName);
          }
          const index = Array.isArray(indexOrCriteria)
            ? `[\${indexOrCriteria.join('+')}]`
            : String(indexOrCriteria);
          return new MockWhereClause(this._rows(), index, this.dbStore, this.tableName);
        }

        filter(fn) {
          return new MockCollection(this._rows(), this.dbStore, this.tableName).filter(fn);
        }

        count() { return Promise.resolve(this._rows().length); }

        offset(n) {
          return new MockCollection(this._rows(), this.dbStore, this.tableName).offset(n);
        }

        limit(n) {
          return new MockCollection(this._rows(), this.dbStore, this.tableName).limit(n);
        }

        each(callback) {
          return new MockCollection(this._rows(), this.dbStore, this.tableName).each(callback);
        }

        toArray() {
          return Promise.resolve(this._rows().map(clone));
        }

        toCollection() {
          return new MockCollection(this._rows(), this.dbStore, this.tableName);
        }

        orderBy(indexOrIndexes) {
          const index = Array.isArray(indexOrIndexes)
            ? `[\${indexOrIndexes.join('+')}]`
            : String(indexOrIndexes);
          const sorted = [...this._rows()].sort((a, b) => {
            const av = getByPath(a, index);
            const bv = getByPath(b, index);
            if (av == null && bv == null) return 0;
            if (av == null) return -1;
            if (bv == null) return 1;
            if (av < bv) return -1;
            if (av > bv) return 1;
            return 0;
          });
          return new MockCollection(sorted, this.dbStore, this.tableName);
        }

        reverse() {
          return new MockCollection([...this._rows()].reverse(), this.dbStore, this.tableName);
        }

        mapToClass(constructor) {
          return constructor;
        }

        add(item, key) {
          const cloned = clone(item) ?? {};
          if (key != null) {
            cloned.id = key;
          }
          if (cloned.id == null) {
            cloned.id = this._nextId();
          }
          this._rows().push(cloned);
          return Promise.resolve(cloned.id);
        }

        update(keyOrObject, changesOrCallback) {
          const id = keyOrObject != null && typeof keyOrObject === 'object'
            ? keyOrObject.id
            : keyOrObject;
          const idx = this._findIndexById(id);
          if (idx < 0) return Promise.resolve(0);
          const row = this._rows()[idx];
          if (typeof changesOrCallback === 'function') {
            const result = changesOrCallback(row, { value: row, primKey: row.id });
            if (result === false) return Promise.resolve(0);
          } else {
            Object.assign(row, clone(changesOrCallback));
          }
          return Promise.resolve(1);
        }

        upsert(keyOrObject, changes) {
          const id = keyOrObject != null && typeof keyOrObject === 'object'
            ? keyOrObject.id
            : keyOrObject;
          const idx = this._findIndexById(id);
          if (idx >= 0) {
            Object.assign(this._rows()[idx], clone(changes));
            return Promise.resolve(true);
          }
          const row = { ...(clone(changes) || {}) };
          if (id != null) row.id = id;
          if (row.id == null) row.id = this._nextId();
          this._rows().push(row);
          return Promise.resolve(true);
        }

        put(item, key) {
          const cloned = clone(item) ?? {};
          if (key != null) {
            cloned.id = key;
          }
          if (cloned.id == null) {
            cloned.id = this._nextId();
          }
          const idx = this._findIndexById(cloned.id);
          if (idx >= 0) {
            this._rows()[idx] = cloned;
          } else {
            this._rows().push(cloned);
          }
          return Promise.resolve(cloned.id);
        }

        delete(key) {
          const idx = this._findIndexById(key);
          if (idx >= 0) this._rows().splice(idx, 1);
          return Promise.resolve();
        }

        clear() {
          this.dbStore.tables.set(this.tableName, []);
          return Promise.resolve();
        }

        bulkGet(keys) {
          const rows = this._rows();
          return Promise.resolve(keys.map((key) => {
            const found = rows.find((row) => row?.id === key);
            return found ? clone(found) : undefined;
          }));
        }

        bulkAdd(items, keys, options) {
          const allKeys = options?.allKeys === true;
          const out = [];
          items.forEach((item, index) => {
            const cloned = clone(item) ?? {};
            const key = Array.isArray(keys) ? keys[index] : undefined;
            if (key != null) cloned.id = key;
            if (cloned.id == null) cloned.id = this._nextId();
            this._rows().push(cloned);
            out.push(cloned.id);
          });
          return Promise.resolve(allKeys ? out : out[out.length - 1]);
        }

        bulkPut(items, keys, options) {
          const allKeys = options?.allKeys === true;
          const out = [];
          items.forEach((item, index) => {
            const cloned = clone(item) ?? {};
            const key = Array.isArray(keys) ? keys[index] : undefined;
            if (key != null) cloned.id = key;
            if (cloned.id == null) cloned.id = this._nextId();
            const idx = this._findIndexById(cloned.id);
            if (idx >= 0) this._rows()[idx] = cloned;
            else this._rows().push(cloned);
            out.push(cloned.id);
          });
          return Promise.resolve(allKeys ? out : out[out.length - 1]);
        }

        bulkUpdate(keysAndChanges) {
          let updated = 0;
          keysAndChanges.forEach(({ key, changes }) => {
            const idx = this._findIndexById(key);
            if (idx >= 0) {
              Object.assign(this._rows()[idx], clone(changes));
              updated++;
            }
          });
          return Promise.resolve(updated);
        }

        bulkDelete(keys) {
          const set = new Set(keys);
          this.dbStore.tables.set(
            this.tableName,
            this._rows().filter((row) => !set.has(row?.id)),
          );
          return Promise.resolve();
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
        close() {}
        table(name) { return new MockTable(this._dbStore, name); }
      };
    })();
  '''
        .toJS,
  ]);
}
