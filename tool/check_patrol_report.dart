import 'dart:convert';
import 'dart:io';

Map<String, dynamic> _object(Object? value, String where) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$where must be an object.');
  }
  return value;
}

List<dynamic> _list(Object? value, String where) {
  if (value is! List) throw FormatException('$where must be an array.');
  return value;
}

String _text(Object? value, String where) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$where must be a nonempty string.');
  }
  return value;
}

void _require(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

Iterable<Map<String, dynamic>> _specs(Object? value) sync* {
  for (final item in _list(value, 'suites')) {
    final suite = _object(item, 'suite');
    for (final spec in _list(suite['specs'] ?? [], 'specs')) {
      yield _object(spec, 'spec');
    }
    yield* _specs(suite['suites'] ?? []);
  }
}

/// Require both browser success and the selected Dart test's own result.
/// Patrol 4.1's web runner can return success after a Dart matcher failure.
int validatePatrolReport(
  Object? reportValue,
  Object? inventoryValue, {
  required DateTime startedAfter,
  required DateTime finishedBefore,
}) {
  final inventory = _object(inventoryValue, 'inventory');
  final suite = _text(inventory['suite'], 'inventory suite');
  final expected = <String, String>{};
  for (final value in _list(inventory['tests'], 'inventory tests')) {
    final name = _text(value, 'inventory test');
    final title = '$suite $name';
    _require(!expected.containsKey(title), 'Duplicate inventory test: $title');
    expected[title] = name;
  }
  _require(expected.isNotEmpty, 'The test inventory is empty.');
  final report = _object(reportValue, 'report');
  _require(
    _list(report['errors'], 'report errors').isEmpty,
    'Browser runner errors.',
  );
  final stats = _object(report['stats'], 'stats');
  final started = DateTime.parse(
    _text(stats['startTime'], 'report start time'),
  );
  _require(
    !started.isBefore(startedAfter) && !started.isAfter(finishedBefore),
    'The report is stale or has an invalid start time.',
  );
  _require(
    stats['expected'] == expected.length &&
        stats['unexpected'] == 0 &&
        stats['skipped'] == 0 &&
        stats['flaky'] == 0,
    'Browser results are missing, failed, skipped, or retried.',
  );
  final seen = <String>{};
  for (final spec in _specs(report['suites'])) {
    final title = _text(spec['title'], 'test title');
    _require(expected.containsKey(title), 'Unknown test: $title');
    _require(seen.add(title), 'Duplicate test: $title');
    final tests = _list(spec['tests'], 'browser tests');
    _require(
      spec['ok'] == true && tests.length == 1,
      'Invalid browser test: $title',
    );
    final test = _object(tests.single, 'browser test');
    final results = _list(test['results'], 'test results');
    _require(
      test['expectedStatus'] == 'passed' &&
          test['status'] == 'expected' &&
          results.length == 1,
      'Failed, skipped, or retried browser test: $title',
    );
    final result = _object(results.single, 'test result');
    _require(
      result['status'] == 'passed' &&
          result['retry'] == 0 &&
          _list(result['errors'], 'test errors').isEmpty,
      'Browser execution failed: $title',
    );
    final outputBytes = <int>[];
    for (final value in _list(result['stdout'], 'test stdout')) {
      final chunk = _object(value, 'stdout chunk');
      _require(
        chunk.length == 1 &&
            ((chunk['text'] is String) || (chunk['buffer'] is String)),
        'Invalid stdout chunk: $title',
      );
      outputBytes.addAll(
        chunk['text'] is String
            ? utf8.encode(chunk['text'] as String)
            : base64Decode(chunk['buffer'] as String),
      );
    }
    final output = utf8.decode(outputBytes);
    var starts = 0;
    var successes = 0;
    for (final line in const LineSplitter().convert(output)) {
      if (!line.startsWith('PATROL_LOG ')) continue;
      final event = _object(jsonDecode(line.substring(11)), 'Patrol event');
      _require(event['type'] != 'error', 'Dart error reported: $title');
      if (event['type'] != 'test') continue;
      final status = event['status'];
      _require(
        status == 'start' || status == 'success',
        'Dart test failed or skipped: $title',
      );
      if (status == 'start') {
        _require(
          event['name'] == expected[title],
          'Unexpected Dart start: $title',
        );
        starts++;
        _require(
          starts == 1 && successes == 0,
          'Duplicate or late Dart start: $title',
        );
      } else {
        _require(event['name'] == title, 'Unexpected Dart result: $title');
        _require(
          event['error'] == null,
          'Dart success contains an error: $title',
        );
        successes++;
        _require(
          starts == 1 && successes == 1,
          'Duplicate or early Dart result: $title',
        );
      }
    }
    _require(starts == 1 && successes == 1, 'Missing Dart completion: $title');
  }
  _require(seen.length == expected.length, 'Missing declared test cases.');
  return seen.length;
}

Object? _readJson(String path, int maxBytes) {
  final input = File(path).openSync();
  try {
    final bytes = input.readSync(maxBytes + 1);
    _require(bytes.length <= maxBytes, 'Input exceeds its size limit: $path');
    return jsonDecode(utf8.decode(bytes));
  } finally {
    input.closeSync();
  }
}

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'Usage: check_patrol_report.dart REPORT.json INVENTORY.json STARTED_AT',
    );
    exitCode = 1;
    return;
  }
  try {
    final count = validatePatrolReport(
      _readJson(args[0], 16 * 1024 * 1024),
      _readJson(args[1], 64 * 1024),
      startedAfter: DateTime.parse(args[2]),
      finishedBefore: DateTime.now(),
    );
    stdout.writeln('Patrol Dart result check passed: $count tests.');
  } on FormatException catch (error) {
    stderr.writeln('Patrol Dart result check failed: $error');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Patrol report is unavailable: $error');
    exitCode = 1;
  }
}
