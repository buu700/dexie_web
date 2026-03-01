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
const String _dexieHashMarkerKey = '__dexie_web_sha384';
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
    final hashMarker = _readGlobalString(_dexieHashMarkerKey);
    final markerMatches =
        sourceMarker == _dexieSourceMarkerValue &&
        hashMarker == dexieScriptSha384Base64;
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
    final hashMarker = _readGlobalString(_dexieHashMarkerKey);
    final markerMatches =
        sourceMarker == _dexieSourceMarkerValue &&
        hashMarker == dexieScriptSha384Base64;

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

    final script = web.HTMLScriptElement()
      ..src = scriptSrc
      ..integrity = dexieScriptIntegrity
      ..crossOrigin = 'anonymous'
      ..type = 'text/javascript';

    script.onload = ((web.Event _) {
      if (_dexieConstructor != null) {
        _writeGlobalString(_dexieSourceMarkerKey, _dexieSourceMarkerValue);
        _writeGlobalString(_dexieHashMarkerKey, dexieScriptSha384Base64);
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
    r'^[A-Za-z0-9+/]{64}$',
  ).hasMatch(dexieScriptSha384Base64);
  if (!valid) {
    throw StateError(
      'Invalid dexieScriptSha384Base64 format. Expected base64-encoded SHA-384 digest.',
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
    return value.toIso8601String().toJS;
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

@JS('Dexie')
extension type Dexie._(JSObject _) implements JSObject {
  external factory Dexie(JSString name);
  external Version version(JSNumber n);
  external JSPromise<JSAny?> open();
  external Table table(JSString name);
}

extension type Version._(JSObject _) implements JSObject {
  external Version stores(JSObject schema);
}

extension type Table._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> put(JSAny? item);
  external JSPromise<JSAny?> get(JSAny? key);
  external JSPromise<JSArray<JSAny?>> toArray();
  external WhereClause where(JSString index);
}

extension type WhereClause._(JSObject _) implements JSObject {
  external Collection equals(JSAny? value);
}

extension type Collection._(JSObject _) implements JSObject {
  external JSPromise<JSArray<JSAny?>> toArray();
}

class DexieDatabase extends stub.DexieDatabase {
  DexieDatabase(super.name);

  Dexie? _db;

  Dexie get _requireDb {
    final db = _db;
    if (db == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    return db;
  }

  @override
  Future<void> open(Map<String, String> schema) async {
    await ensureDexieInitialized();

    final db = Dexie(name.toJS);
    db.version(1.toJS).stores((schema.jsify() as JSObject?) ?? JSObject());
    await db.open().toDart;
    _db = db;
  }

  @override
  Future<void> put<T>(String tableName, T item) async {
    final table = _requireDb.table(tableName.toJS);
    await table.put(_dartToJs(item)).toDart;
  }

  @override
  Future<T?> get<T>(String tableName, dynamic key) async {
    final table = _requireDb.table(tableName.toJS);
    final result = await table.get(_dartToJs(key)).toDart;
    return _jsToDart(result) as T?;
  }

  @override
  Future<List<T>> getAll<T>(String tableName) async {
    final table = _requireDb.table(tableName.toJS);
    final result = await table.toArray().toDart;
    final list = <T>[];
    final length = result.length;
    for (var i = 0; i < length; i++) {
      list.add(_jsToDart(result[i]) as T);
    }
    return list;
  }

  @override
  Future<List<T>> whereEquals<T>(
    String tableName,
    String index,
    dynamic value,
  ) async {
    final table = _requireDb.table(tableName.toJS);
    final collection = table.where(index.toJS).equals(_dartToJs(value));
    final result = await collection.toArray().toDart;
    final list = <T>[];
    final length = result.length;
    for (var i = 0; i < length; i++) {
      list.add(_jsToDart(result[i]) as T);
    }
    return list;
  }
}
