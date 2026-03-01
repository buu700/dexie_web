import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'dexie_sri.g.dart';
import 'dexie_stub.dart' as stub;

bool _dexieLoaded = false;
Completer<void>? _loadCompleter;
const String _dexieScriptAssetPath =
    'assets/packages/dexie_web/assets/dexie.min.js';
const String _dexieSourceMarkerKey = '__dexie_web_source';
const String _dexieIntegrityMarkerKey = '__dexie_web_integrity';
const String _dexieSourceMarkerValue = 'dexie_web';

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

@JS('Dexie')
external JSFunction? get _dexieConstructor;

Future<void> ensureDexieInitialized({DexieLoadPolicy? policy}) async {
  final effectivePolicy = policy ?? _defaultDexieLoadPolicy;
  _validateDexieSriConstants();
  final pending = _loadCompleter;
  if (pending != null) {
    if (pending.isCompleted) {
      _loadCompleter = null;
    } else {
      return pending.future;
    }
  }

  if (_dexieLoaded) {
    final hasDexieGlobal = _dexieConstructor != null;
    final sourceMarker = _readGlobalString(_dexieSourceMarkerKey);
    final integrityMarker = _readGlobalString(_dexieIntegrityMarkerKey);
    final markerMatches =
        sourceMarker == _dexieSourceMarkerValue &&
        integrityMarker == dexieScriptIntegrity;
    switch (effectivePolicy) {
      case DexieLoadPolicy.strictPackage:
        if (hasDexieGlobal && markerMatches) {
          return;
        }
        _dexieLoaded = false;
        if (hasDexieGlobal && !markerMatches) {
          throw StateError(
            'Detected pre-existing global Dexie not managed by dexie_web. '
            'Refusing to continue in strictPackage mode.',
          );
        }
        break;
      case DexieLoadPolicy.strictGlobal:
        if (hasDexieGlobal) {
          return;
        }
        _dexieLoaded = false;
        throw StateError(
          'Dexie global was expected after initialization, but none was found.',
        );
      case DexieLoadPolicy.preferGlobalFallbackPackage:
        if (hasDexieGlobal) {
          return;
        }
        _dexieLoaded = false;
        break;
    }
  }

  final inFlight = _loadCompleter;
  if (inFlight != null) {
    if (!inFlight.isCompleted) {
      return inFlight.future;
    }
    _loadCompleter = null;
  }

  final completer = Completer<void>();
  _loadCompleter = completer;
  try {
    final hasDexieGlobal = _dexieConstructor != null;
    final sourceMarker = _readGlobalString(_dexieSourceMarkerKey);
    final integrityMarker = _readGlobalString(_dexieIntegrityMarkerKey);
    final markerMatches =
        sourceMarker == _dexieSourceMarkerValue &&
        integrityMarker == dexieScriptIntegrity;

    if (hasDexieGlobal) {
      switch (effectivePolicy) {
        case DexieLoadPolicy.strictPackage:
          if (!markerMatches) {
            throw StateError(
              'Detected pre-existing global Dexie not managed by dexie_web. '
              'Refusing to continue in strictPackage mode.',
            );
          }
          break;
        case DexieLoadPolicy.strictGlobal:
        case DexieLoadPolicy.preferGlobalFallbackPackage:
          break;
      }
      _dexieLoaded = true;
      _loadCompleter = null;
      completer.complete();
      return completer.future;
    }

    if (effectivePolicy == DexieLoadPolicy.strictGlobal) {
      throw StateError(
        'Dexie global was not found, but strictGlobal mode requires it.',
      );
    }

    final scriptSrc = _resolveDexieScriptSrc();

    if (web.document.querySelector('script[src*="dexie.min.js"]') != null &&
        _dexieConstructor != null) {
      if (effectivePolicy == DexieLoadPolicy.strictPackage && !markerMatches) {
        throw StateError(
          'Found existing Dexie script/global that is not managed by dexie_web. '
          'Refusing to continue in strictPackage mode.',
        );
      }
      _dexieLoaded = true;
      _loadCompleter = null;
      completer.complete();
      return completer.future;
    }

    _removeDexieScriptElements();

    final script = web.HTMLScriptElement()
      ..src = scriptSrc
      ..integrity = dexieScriptIntegrity
      ..crossOrigin = 'anonymous'
      ..type = 'text/javascript';

    script.onload = ((web.Event _) {
      if (_dexieConstructor != null) {
        _writeGlobalString(_dexieSourceMarkerKey, _dexieSourceMarkerValue);
        _writeGlobalString(_dexieIntegrityMarkerKey, dexieScriptIntegrity);
        _dexieLoaded = true;
        _loadCompleter = null;
        if (!completer.isCompleted) {
          completer.complete();
        }
        return;
      }
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Dexie script loaded but global Dexie constructor is missing.',
          ),
        );
      }
      _loadCompleter = null;
    }).toJS;

    script.onerror = ((web.Event _) {
      _dexieLoaded = false;
      script.remove();
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Failed to load Dexie.js from package asset: $scriptSrc'),
        );
      }
      _loadCompleter = null;
    }).toJS;

    web.document.head?.append(script);
  } catch (error, stackTrace) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
    _loadCompleter = null;
  }
  await completer.future;
}

void _removeDexieScriptElements() {
  final scripts = web.document.querySelectorAll('script[src*="dexie.min.js"]');
  final length = scripts.length;
  for (var i = 0; i < length; i++) {
    final script = scripts.item(i);
    if (script is web.HTMLScriptElement) {
      script.remove();
    }
  }
}

String _resolveDexieScriptSrc() {
  try {
    final base = web.document.baseURI;
    return Uri.parse(base).resolve(_dexieScriptAssetPath).toString();
  } catch (_) {
    return '/$_dexieScriptAssetPath';
  }
}

void _validateDexieSriConstants() {
  final valid = RegExp(
    r'^sha384-[A-Za-z0-9+/]{64}$',
  ).hasMatch(dexieScriptIntegrity);
  if (!valid) {
    throw StateError(
      'Invalid dexieScriptIntegrity format. Expected sha384-<base64 SHA-384 digest>.',
    );
  }
}

@JS('globalThis')
external JSObject get _globalThis;

String? _readGlobalString(String key) {
  final value = _globalThis.getProperty(key.toJS);
  if (value is JSString) {
    return value.toDart;
  }
  return null;
}

void _writeGlobalString(String key, String value) {
  _globalThis.setProperty(key.toJS, value.toJS);
}

JSAny? _dartToJs(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value.toJS;
  }
  if (value is bool) {
    return value.toJS;
  }
  if (value is int) {
    return value.toJS;
  }
  if (value is double) {
    return value.toJS;
  }
  if (value is num) {
    return value.toJS;
  }
  if (value is DateTime) {
    return _JsDate(value.millisecondsSinceEpoch.toJS);
  }
  if (value is Map) {
    final obj = JSObject();
    value.forEach((key, nested) {
      obj.setProperty(key.toString().toJS, _dartToJs(nested));
    });
    return obj;
  }
  if (value is Iterable) {
    final list = value.toList(growable: false);
    final array = JSArray<JSAny?>.withLength(list.length);
    for (var i = 0; i < list.length; i++) {
      array[i] = _dartToJs(list[i]);
    }
    return array;
  }
  throw ArgumentError(
    'Unsupported value type for JS conversion: ${value.runtimeType}.',
  );
}

dynamic _jsToDart(JSAny? value) {
  if (value == null) {
    return null;
  }
  if (_isJsDate(value)) {
    final epochMillisAny = (value as JSObject).callMethodVarArgs<JSAny?>(
      'getTime'.toJS,
      const [],
    );
    if (epochMillisAny is JSNumber) {
      return DateTime.fromMillisecondsSinceEpoch(
        epochMillisAny.toDartDouble.round(),
        isUtc: true,
      );
    }
  }
  if (_isJsArray(value)) {
    final array = value as JSArray<JSAny?>;
    final list = <dynamic>[];
    final length = array.length;
    for (var i = 0; i < length; i++) {
      list.add(_jsToDart(array[i]));
    }
    return list;
  }
  if (value is JSObject) {
    final map = <String, dynamic>{};
    final keys = _objectKeys(value);
    final length = keys.length;
    for (var i = 0; i < length; i++) {
      final key = keys[i].toDart;
      map[key] = _jsToDart(value.getProperty(key.toJS));
    }
    return map;
  }
  return value.dartify();
}

@JS('Object.keys')
external JSArray<JSString> _objectKeys(JSObject object);

@JS('Array.isArray')
external JSBoolean _arrayIsArray(JSAny? value);

bool _isJsArray(JSAny? value) => _arrayIsArray(value).toDart;

@JS('Object.prototype.toString.call')
external JSString _objectTypeTag(JSAny? value);

bool _isJsDate(JSAny? value) => _objectTypeTag(value).toDart == '[object Date]';

@JS('Date')
extension type _JsDate._(JSObject _) implements JSObject {
  external factory _JsDate(JSNumber epochMillis);
}

@JS('Dexie')
extension type Dexie._(JSObject _) implements JSObject {
  external factory Dexie(JSString name);
  external Version version(JSNumber n);
  external JSPromise<JSAny?> open();
  external void close();
  external JSObject table(JSString name);
}

extension type Version._(JSObject _) implements JSObject {
  external Version stores(JSObject schema);
}

JSAny? _invoke(JSObject target, String method, [List<JSAny?> args = const []]) {
  return target.callMethodVarArgs<JSAny?>(method.toJS, args);
}

Future<JSAny?> _invokePromise(
  JSObject target,
  String method, [
  List<JSAny?> args = const [],
]) async {
  final result = _invoke(target, method, args);
  if (result is! JSPromise<JSAny?>) {
    throw StateError('Dexie method $method did not return a Promise.');
  }
  return result.toDart;
}

JSObject _invokeObject(
  JSObject target,
  String method, [
  List<JSAny?> args = const [],
]) {
  final result = _invoke(target, method, args);
  if (result is JSObject) {
    return result;
  }
  throw StateError('Dexie method $method did not return an object.');
}

List<T> _toTypedList<T>(JSAny? value, String context) {
  final dart = _jsToDart(value);
  if (dart is! List) {
    throw StateError('$context did not resolve to a JS array.');
  }
  return dart.map((e) => e as T).toList(growable: false);
}

int _toInt(JSAny? value, String context) {
  final dart = _jsToDart(value);
  if (dart is num) {
    return dart.toInt();
  }
  throw StateError('$context did not resolve to a numeric value.');
}

bool _toBool(JSAny? value, String context) {
  final dart = _jsToDart(value);
  if (dart is bool) {
    return dart;
  }
  throw StateError('$context did not resolve to a boolean value.');
}

class _TableSchemaMeta {
  _TableSchemaMeta(this.indexes);
  final Set<String> indexes;
}

Map<String, _TableSchemaMeta> _parseSchemaMeta(Map<String, String> schema) {
  final parsed = <String, _TableSchemaMeta>{};
  schema.forEach((tableName, tableSchema) {
    final indexes = <String>{':id'};
    final rawIndexes = tableSchema
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty);
    for (final raw in rawIndexes) {
      final normalized = _normalizeIndex(raw);
      if (normalized.isEmpty) {
        continue;
      }
      indexes.add(normalized);
      if (normalized.startsWith('[') && normalized.endsWith(']')) {
        final inner = normalized.substring(1, normalized.length - 1);
        if (inner.isNotEmpty) {
          indexes.add(inner);
        }
      }
    }
    parsed[tableName] = _TableSchemaMeta(indexes);
  });
  return parsed;
}

String _normalizeIndex(String raw) {
  var value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  if (value.startsWith('[') && value.endsWith(']')) {
    return value;
  }
  if (value.startsWith('++')) {
    value = value.substring(2);
  }
  while (value.isNotEmpty &&
      (value.startsWith('&') ||
          value.startsWith('*') ||
          value.startsWith('+') ||
          value.startsWith('!'))) {
    value = value.substring(1);
  }
  return value.trim();
}

class DexieDatabase extends stub.DexieDatabase {
  DexieDatabase(super.name);

  Dexie? _db;
  Map<String, _TableSchemaMeta> _schemaMeta = const {};

  @override
  void close() {
    _db?.close();
    _db = null;
  }

  Dexie get _requireDb {
    final db = _db;
    if (db == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    return db;
  }

  bool _hasIndex(String tableName, String index) {
    final table = _schemaMeta[tableName];
    return table != null && table.indexes.contains(index);
  }

  void _ensureKnownTable(String tableName) {
    if (!_schemaMeta.containsKey(tableName)) {
      throw StateError('Unknown table "$tableName".');
    }
  }

  void _ensureKnownIndex(String tableName, String index) {
    _ensureKnownTable(tableName);
    final table = _schemaMeta[tableName]!;
    if (!table.indexes.contains(index)) {
      throw StateError('Unknown index "$index" on table "$tableName".');
    }
  }

  JSObject _tableObject(String tableName) {
    _ensureKnownTable(tableName);
    return _requireDb.table(tableName.toJS);
  }

  @override
  Future<void> open(Map<String, String> schema) async {
    await ensureDexieInitialized();

    final db = Dexie(name.toJS);
    final jsSchema = _dartToJs(schema);
    if (jsSchema is! JSObject) {
      throw StateError('Failed to convert schema to a JS object.');
    }
    db.version(1.toJS).stores(jsSchema);
    await db.open().toDart;
    _db = db;
    _schemaMeta = _parseSchemaMeta(schema);
  }

  @override
  stub.DexieTable<T, TKey, TInsertType> table<T, TKey, TInsertType>(
    String tableName,
  ) {
    final tableJs = _tableObject(tableName);
    return DexieTable<T, TKey, TInsertType>._(this, tableName, tableJs);
  }

  @override
  Future<void> put<T>(String tableName, T item) async {
    await table<dynamic, dynamic, dynamic>(tableName).put(item);
  }

  @override
  Future<T?> get<T>(String tableName, dynamic key) async {
    return table<T, dynamic, T>(tableName).get(key);
  }

  @override
  Future<List<T>> getAll<T>(String tableName) async {
    return table<T, dynamic, T>(tableName).toArray();
  }

  @override
  Future<List<T>> whereEquals<T>(
    String tableName,
    String index,
    dynamic value,
  ) async {
    return table<T, dynamic, T>(
      tableName,
    ).whereIndex(index).equals(value).toArray();
  }

  @override
  Future<void> delete(String tableName, dynamic key) async {
    await table<dynamic, dynamic, dynamic>(tableName).delete(key);
  }

  @override
  Future<List<T>> whereStartsWith<T>(
    String tableName,
    String index,
    String prefix,
  ) async {
    return table<T, dynamic, T>(
      tableName,
    ).whereIndex(index).startsWith(prefix).toArray();
  }

  @override
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

class DexieTable<T, TKey, TInsertType>
    extends stub.DexieTable<T, TKey, TInsertType> {
  DexieTable._(this._database, super.tableName, this._table);

  final DexieDatabase _database;
  final JSObject _table;

  @override
  Future<T?> get(dynamic keyOrCriteria) async {
    final value = await _invokePromise(_table, 'get', [
      _dartToJs(keyOrCriteria),
    ]);
    return _jsToDart(value) as T?;
  }

  @override
  Object where(dynamic indexOrCriteria) {
    if (indexOrCriteria is String) {
      _database._ensureKnownIndex(tableName, indexOrCriteria);
      final clause = _invokeObject(_table, 'where', [indexOrCriteria.toJS]);
      return DexieWhereClause<T, TKey, TInsertType>._(
        _database,
        tableName,
        indexOrCriteria,
        clause,
      );
    }

    if (indexOrCriteria is List) {
      final parts = indexOrCriteria.map((entry) => entry.toString()).toList();
      final compound = '[${parts.join('+')}]';
      if (!_database._hasIndex(tableName, compound)) {
        for (final part in parts) {
          _database._ensureKnownIndex(tableName, part);
        }
      }
      final clause = _invokeObject(_table, 'where', [_dartToJs(parts)]);
      return DexieWhereClause<T, TKey, TInsertType>._(
        _database,
        tableName,
        compound,
        clause,
      );
    }

    if (indexOrCriteria is Map<String, dynamic>) {
      for (final key in indexOrCriteria.keys) {
        _database._ensureKnownIndex(tableName, key);
      }
      final collection = _invokeObject(_table, 'where', [
        _dartToJs(indexOrCriteria),
      ]);
      return DexieCollection<T, TKey, TInsertType>._(
        _database,
        tableName,
        collection,
      );
    }

    throw ArgumentError(
      'where() expects a String index, a List of compound index parts, or a Map criteria.',
    );
  }

  @override
  DexieCollection<T, TKey, TInsertType> filter(bool Function(T obj) fn) {
    final jsFilter = ((JSAny? value) => fn(_jsToDart(value) as T).toJS).toJS;
    return DexieCollection<T, TKey, TInsertType>._(
      _database,
      tableName,
      _invokeObject(_table, 'filter', [jsFilter]),
    );
  }

  @override
  Future<int> count() async {
    final result = await _invokePromise(_table, 'count');
    return _toInt(result, 'Table.count()');
  }

  @override
  DexieCollection<T, TKey, TInsertType> offset(int n) {
    return DexieCollection<T, TKey, TInsertType>._(
      _database,
      tableName,
      _invokeObject(_table, 'offset', [n.toJS]),
    );
  }

  @override
  DexieCollection<T, TKey, TInsertType> limit(int n) {
    return DexieCollection<T, TKey, TInsertType>._(
      _database,
      tableName,
      _invokeObject(_table, 'limit', [n.toJS]),
    );
  }

  @override
  Future<void> each(void Function(T obj, dynamic cursor) callback) async {
    final jsCallback = ((JSAny? value, JSAny? cursor) {
      callback(_jsToDart(value) as T, _jsToDart(cursor));
    }).toJS;
    await _invokePromise(_table, 'each', [jsCallback]);
  }

  @override
  Future<List<T>> toArray() async {
    final result = await _invokePromise(_table, 'toArray');
    return _toTypedList<T>(result, 'Table.toArray()');
  }

  @override
  DexieCollection<T, TKey, TInsertType> toCollection() {
    return DexieCollection<T, TKey, TInsertType>._(
      _database,
      tableName,
      _invokeObject(_table, 'toCollection'),
    );
  }

  @override
  DexieCollection<T, TKey, TInsertType> orderBy(dynamic indexOrIndexes) {
    if (indexOrIndexes is String) {
      _database._ensureKnownIndex(tableName, indexOrIndexes);
    }
    return DexieCollection<T, TKey, TInsertType>._(
      _database,
      tableName,
      _invokeObject(_table, 'orderBy', [_dartToJs(indexOrIndexes)]),
    );
  }

  @override
  DexieCollection<T, TKey, TInsertType> reverse() {
    return DexieCollection<T, TKey, TInsertType>._(
      _database,
      tableName,
      _invokeObject(_table, 'reverse'),
    );
  }

  @override
  dynamic mapToClass(dynamic constructor) {
    return _invoke(_table, 'mapToClass', [_dartToJs(constructor)]);
  }

  @override
  Future<dynamic> add(TInsertType item, {dynamic key}) async {
    final args = <JSAny?>[_dartToJs(item)];
    if (key != null) {
      args.add(_dartToJs(key));
    }
    return _jsToDart(await _invokePromise(_table, 'add', args));
  }

  @override
  Future<int> update(dynamic keyOrObject, dynamic changes) async {
    final result = await _invokePromise(_table, 'update', [
      _dartToJs(keyOrObject),
      _dartToJs(changes),
    ]);
    return _toInt(result, 'Table.update()');
  }

  @override
  Future<bool> upsert(dynamic keyOrObject, dynamic changes) async {
    final result = await _invokePromise(_table, 'upsert', [
      _dartToJs(keyOrObject),
      _dartToJs(changes),
    ]);
    return _toBool(result, 'Table.upsert()');
  }

  @override
  Future<dynamic> put(TInsertType item, {dynamic key}) async {
    final args = <JSAny?>[_dartToJs(item)];
    if (key != null) {
      args.add(_dartToJs(key));
    }
    return _jsToDart(await _invokePromise(_table, 'put', args));
  }

  @override
  Future<void> delete(dynamic key) async {
    await _invokePromise(_table, 'delete', [_dartToJs(key)]);
  }

  @override
  Future<void> clear() async {
    await _invokePromise(_table, 'clear');
  }

  @override
  Future<List<T?>> bulkGet(List<dynamic> keys) async {
    final result = await _invokePromise(_table, 'bulkGet', [_dartToJs(keys)]);
    return _toTypedList<T?>(result, 'Table.bulkGet()');
  }

  JSObject _allKeysOptions(bool allKeys) {
    final options = JSObject();
    options.setProperty('allKeys'.toJS, allKeys.toJS);
    return options;
  }

  @override
  Future<dynamic> bulkAdd(
    List<TInsertType> items, {
    List<dynamic>? keys,
    bool? allKeys,
  }) async {
    final args = <JSAny?>[_dartToJs(items)];
    if (keys != null) {
      args.add(_dartToJs(keys));
    }
    if (allKeys != null) {
      args.add(_allKeysOptions(allKeys));
    }
    return _jsToDart(await _invokePromise(_table, 'bulkAdd', args));
  }

  @override
  Future<dynamic> bulkPut(
    List<TInsertType> items, {
    List<dynamic>? keys,
    bool? allKeys,
  }) async {
    final args = <JSAny?>[_dartToJs(items)];
    if (keys != null) {
      args.add(_dartToJs(keys));
    }
    if (allKeys != null) {
      args.add(_allKeysOptions(allKeys));
    }
    return _jsToDart(await _invokePromise(_table, 'bulkPut', args));
  }

  @override
  Future<int> bulkUpdate(List<Map<String, dynamic>> keysAndChanges) async {
    final result = await _invokePromise(_table, 'bulkUpdate', [
      _dartToJs(keysAndChanges),
    ]);
    return _toInt(result, 'Table.bulkUpdate()');
  }

  @override
  Future<void> bulkDelete(List<dynamic> keys) async {
    await _invokePromise(_table, 'bulkDelete', [_dartToJs(keys)]);
  }
}

class DexieWhereClause<T, TKey, TInsertType>
    extends stub.DexieWhereClause<T, TKey, TInsertType> {
  DexieWhereClause._(
    this._database,
    super.tableName,
    super.indexName,
    this._clause,
  );

  final DexieDatabase _database;
  final JSObject _clause;

  DexieCollection<T, TKey, TInsertType> _collection(
    String method,
    List<JSAny?> args,
  ) {
    return DexieCollection<T, TKey, TInsertType>._(
      _database,
      tableName,
      _invokeObject(_clause, method, args),
    );
  }

  @override
  DexieCollection<T, TKey, TInsertType> above(dynamic key) {
    return _collection('above', [_dartToJs(key)]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> aboveOrEqual(dynamic key) {
    return _collection('aboveOrEqual', [_dartToJs(key)]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> anyOf(List<dynamic> keys) {
    return _collection('anyOf', [_dartToJs(keys)]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> anyOfIgnoreCase(List<String> keys) {
    return _collection('anyOfIgnoreCase', [_dartToJs(keys)]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> below(dynamic key) {
    return _collection('below', [_dartToJs(key)]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> belowOrEqual(dynamic key) {
    return _collection('belowOrEqual', [_dartToJs(key)]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> between(
    dynamic lower,
    dynamic upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return _collection('between', [
      _dartToJs(lower),
      _dartToJs(upper),
      includeLower.toJS,
      includeUpper.toJS,
    ]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> equals(dynamic key) {
    return _collection('equals', [_dartToJs(key)]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> equalsIgnoreCase(String key) {
    return _collection('equalsIgnoreCase', [key.toJS]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> inAnyRange(
    List<List<dynamic>> ranges, {
    bool includeLowers = true,
    bool includeUppers = false,
  }) {
    final options = JSObject();
    options.setProperty('includeLowers'.toJS, includeLowers.toJS);
    options.setProperty('includeUppers'.toJS, includeUppers.toJS);
    return _collection('inAnyRange', [_dartToJs(ranges), options]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> startsWith(String key) {
    return _collection('startsWith', [key.toJS]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> startsWithAnyOf(List<String> prefixes) {
    return _collection('startsWithAnyOf', [_dartToJs(prefixes)]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> startsWithIgnoreCase(String key) {
    return _collection('startsWithIgnoreCase', [key.toJS]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> startsWithAnyOfIgnoreCase(
    List<String> prefixes,
  ) {
    return _collection('startsWithAnyOfIgnoreCase', [_dartToJs(prefixes)]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> noneOf(List<dynamic> keys) {
    return _collection('noneOf', [_dartToJs(keys)]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> notEqual(dynamic key) {
    return _collection('notEqual', [_dartToJs(key)]);
  }
}

class DexieCollection<T, TKey, TInsertType>
    extends stub.DexieCollection<T, TKey, TInsertType> {
  DexieCollection._(this._database, super.tableName, this._collection);

  final DexieDatabase _database;
  final JSObject _collection;

  DexieCollection<T, TKey, TInsertType> _next(
    String method,
    List<JSAny?> args,
  ) {
    return DexieCollection<T, TKey, TInsertType>._(
      _database,
      tableName,
      _invokeObject(_collection, method, args),
    );
  }

  @override
  DexieCollection<T, TKey, TInsertType> and(bool Function(T obj) filter) {
    final jsFilter = ((JSAny? value) => filter(
      _jsToDart(value) as T,
    ).toJS).toJS;
    return _next('and', [jsFilter]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> clone({Map<String, dynamic>? props}) {
    if (props == null) {
      return _next('clone', const []);
    }
    return _next('clone', [_dartToJs(props)]);
  }

  @override
  Future<int> count() async {
    final result = await _invokePromise(_collection, 'count');
    return _toInt(result, 'Collection.count()');
  }

  @override
  DexieCollection<T, TKey, TInsertType> distinct() {
    return _next('distinct', const []);
  }

  @override
  Future<void> each(void Function(T obj, dynamic cursor) callback) async {
    final jsCallback = ((JSAny? value, JSAny? cursor) {
      callback(_jsToDart(value) as T, _jsToDart(cursor));
    }).toJS;
    await _invokePromise(_collection, 'each', [jsCallback]);
  }

  @override
  Future<void> eachKey(
    void Function(dynamic key, dynamic cursor) callback,
  ) async {
    final jsCallback = ((JSAny? key, JSAny? cursor) {
      callback(_jsToDart(key), _jsToDart(cursor));
    }).toJS;
    await _invokePromise(_collection, 'eachKey', [jsCallback]);
  }

  @override
  Future<void> eachPrimaryKey(
    void Function(dynamic key, dynamic cursor) callback,
  ) async {
    final jsCallback = ((JSAny? key, JSAny? cursor) {
      callback(_jsToDart(key), _jsToDart(cursor));
    }).toJS;
    await _invokePromise(_collection, 'eachPrimaryKey', [jsCallback]);
  }

  @override
  Future<void> eachUniqueKey(
    void Function(dynamic key, dynamic cursor) callback,
  ) async {
    final jsCallback = ((JSAny? key, JSAny? cursor) {
      callback(_jsToDart(key), _jsToDart(cursor));
    }).toJS;
    await _invokePromise(_collection, 'eachUniqueKey', [jsCallback]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> filter(bool Function(T obj) filter) {
    final jsFilter = ((JSAny? value) => filter(
      _jsToDart(value) as T,
    ).toJS).toJS;
    return _next('filter', [jsFilter]);
  }

  @override
  Future<T?> first() async {
    return _jsToDart(await _invokePromise(_collection, 'first')) as T?;
  }

  @override
  Future<dynamic> firstKey() async {
    return _jsToDart(await _invokePromise(_collection, 'firstKey'));
  }

  @override
  Future<List<dynamic>> keys() async {
    return _toTypedList<dynamic>(
      await _invokePromise(_collection, 'keys'),
      'Collection.keys()',
    );
  }

  @override
  Future<List<dynamic>> primaryKeys() async {
    return _toTypedList<dynamic>(
      await _invokePromise(_collection, 'primaryKeys'),
      'Collection.primaryKeys()',
    );
  }

  @override
  Future<T?> last() async {
    return _jsToDart(await _invokePromise(_collection, 'last')) as T?;
  }

  @override
  Future<dynamic> lastKey() async {
    return _jsToDart(await _invokePromise(_collection, 'lastKey'));
  }

  @override
  DexieCollection<T, TKey, TInsertType> limit(int n) {
    return _next('limit', [n.toJS]);
  }

  @override
  DexieCollection<T, TKey, TInsertType> offset(int n) {
    return _next('offset', [n.toJS]);
  }

  @override
  DexieWhereClause<T, TKey, TInsertType> or(String indexOrPrimaryKey) {
    if (indexOrPrimaryKey != ':id') {
      _database._ensureKnownIndex(tableName, indexOrPrimaryKey);
    }
    return DexieWhereClause<T, TKey, TInsertType>._(
      _database,
      tableName,
      indexOrPrimaryKey,
      _invokeObject(_collection, 'or', [indexOrPrimaryKey.toJS]),
    );
  }

  @override
  DexieCollection<T, TKey, TInsertType> raw() {
    return _next('raw', const []);
  }

  @override
  DexieCollection<T, TKey, TInsertType> reverse() {
    return _next('reverse', const []);
  }

  @override
  Future<List<T>> sortBy(String keyPath) async {
    return _toTypedList<T>(
      await _invokePromise(_collection, 'sortBy', [keyPath.toJS]),
      'Collection.sortBy()',
    );
  }

  @override
  Future<List<T>> toArray() async {
    return _toTypedList<T>(
      await _invokePromise(_collection, 'toArray'),
      'Collection.toArray()',
    );
  }

  @override
  Future<List<dynamic>> uniqueKeys() async {
    return _toTypedList<dynamic>(
      await _invokePromise(_collection, 'uniqueKeys'),
      'Collection.uniqueKeys()',
    );
  }

  @override
  DexieCollection<T, TKey, TInsertType> until(
    bool Function(T value) filter, {
    bool includeStopEntry = false,
  }) {
    final jsFilter = ((JSAny? value) => filter(
      _jsToDart(value) as T,
    ).toJS).toJS;
    return _next('until', [jsFilter, includeStopEntry.toJS]);
  }

  @override
  Future<int> delete() async {
    final result = await _invokePromise(_collection, 'delete');
    return _toInt(result, 'Collection.delete()');
  }

  @override
  Future<int> modify(dynamic changeCallbackOrChanges) async {
    if (changeCallbackOrChanges is Function) {
      final jsCallback = ((JSAny? value, JSAny? ctx) {
        final result = Function.apply(changeCallbackOrChanges, [
          _jsToDart(value),
          _jsToDart(ctx),
        ]);
        if (result == null) {
          return null;
        }
        if (result is bool) {
          return result.toJS;
        }
        return _dartToJs(result);
      }).toJS;
      final response = await _invokePromise(_collection, 'modify', [
        jsCallback,
      ]);
      return _toInt(response, 'Collection.modify(callback)');
    }

    final response = await _invokePromise(_collection, 'modify', [
      _dartToJs(changeCallbackOrChanges),
    ]);
    return _toInt(response, 'Collection.modify(changes)');
  }
}
