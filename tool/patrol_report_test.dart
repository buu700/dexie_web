import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'check_patrol_report.dart';

const inventory = {
  'suite': 'fixture',
  'tests': ['integrity', 'persistence'],
};

Map<String, dynamic> report() => jsonDecode(
  jsonEncode({
    'errors': [],
    'stats': {
      'startTime': '2026-09-08T12:00:00Z',
      'expected': 2,
      'unexpected': 0,
      'skipped': 0,
      'flaky': 0,
    },
    'suites': [
      {
        'specs': [
          for (final name in ['integrity', 'persistence'])
            {
              'title': 'fixture $name',
              'ok': true,
              'tests': [
                {
                  'expectedStatus': 'passed',
                  'status': 'expected',
                  'results': [
                    {
                      'status': 'passed',
                      'retry': 0,
                      'errors': [],
                      'stdout': [
                        {
                          'text':
                              'PATROL_LOG ' +
                              jsonEncode({
                                'type': 'test',
                                'name': name,
                                'status': 'start',
                              }) +
                              '\n',
                        },
                        {
                          'text':
                              'PATROL_LOG ' +
                              jsonEncode({
                                'type': 'test',
                                'name': 'fixture $name',
                                'status': 'success',
                                'error': null,
                              }) +
                              '\n',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
        ],
      },
    ],
  }),
);

List<dynamic> specs(Map<String, dynamic> value) => value['suites'][0]['specs'];
Map<String, dynamic> result(Map<String, dynamic> value) =>
    specs(value)[0]['tests'][0]['results'][0];

int check(Object? value, Object? declared) => validatePatrolReport(
  value,
  declared,
  startedAfter: DateTime.utc(2026, 9, 8, 11, 59),
  finishedBefore: DateTime.utc(2026, 9, 8, 12, 1),
);

void main() {
  test('requires both browser and Dart success for the declared inventory', () {
    expect(check(report(), inventory), 2);
  });

  test('accepts exact qualified starts from newer Patrol reporters', () {
    final value = report();
    for (final spec in specs(value)) {
      spec['tests'][0]['results'][0]['stdout'][0]['text'] =
          'PATROL_LOG ' +
          jsonEncode({
            'type': 'test',
            'name': spec['title'],
            'status': 'start',
          }) +
          '\n';
    }
    expect(check(value, inventory), 2);
  });

  test('rejects other declared names and near matches in Dart starts', () {
    for (final name in [
      'persistence',
      'fixture persistence',
      'other integrity',
      'fixture integrity suffix',
      'fixture fixture integrity',
    ]) {
      final value = report();
      result(value)['stdout'][0]['text'] =
          'PATROL_LOG ' +
          jsonEncode({'type': 'test', 'name': name, 'status': 'start'}) +
          '\n';
      expect(() => check(value, inventory), throwsFormatException);
    }
  });

  test('rejects duplicate starts across both supported name forms', () {
    final value = report();
    result(value)['stdout'].insert(1, {
      'text':
          'PATROL_LOG ' +
          jsonEncode({
            'type': 'test',
            'name': 'fixture integrity',
            'status': 'start',
          }) +
          '\n',
    });
    expect(() => check(value, inventory), throwsFormatException);
  });

  test('qualified start cannot hide a false-green Dart failure', () {
    final value = report();
    result(value)['stdout'][0]['text'] =
        'PATROL_LOG ' +
        jsonEncode({
          'type': 'test',
          'name': 'fixture integrity',
          'status': 'start',
        }) +
        '\n';
    result(value)['stdout'][1]['text'] =
        'PATROL_LOG ' +
        jsonEncode({
          'type': 'test',
          'name': 'fixture integrity',
          'status': 'failure',
          'error': 'SRI mismatch',
        }) +
        '\n';
    expect(() => check(value, inventory), throwsFormatException);
  });

  test('accepts text and binary chunks split within structured events', () {
    final value = report();
    final output = (result(value)['stdout'] as List)
        .map((chunk) => chunk['text'] as String)
        .join();
    result(value)['stdout'] = [
      {'text': output.substring(0, 5)},
      {'buffer': base64Encode(utf8.encode(output.substring(5, 40)))},
      {'text': output.substring(40)},
    ];
    expect(check(value, inventory), 2);
  });

  test('rejects malformed, ambiguous and non UTF-8 stdout chunks', () {
    for (final chunk in [
      {},
      {'text': 3},
      {'buffer': '!!!'},
      {
        'buffer': base64Encode([255]),
      },
      {'text': '', 'buffer': ''},
    ]) {
      final value = report();
      result(value)['stdout'].add(chunk);
      expect(() => check(value, inventory), throwsFormatException);
    }
  });

  test('rejects stale, future and missing report start times', () {
    for (final started in [
      null,
      'broken',
      '2026-09-07T12:00:00Z',
      '2026-09-09T12:00:00Z',
    ]) {
      final value = report();
      value['stats']['startTime'] = started;
      expect(() => check(value, inventory), throwsFormatException);
    }
  });

  test('rejects Dart failure even when every browser result says passed', () {
    final value = report();
    result(value)['stdout'][1]['text'] =
        'PATROL_LOG ' +
        jsonEncode({
          'type': 'test',
          'name': 'fixture integrity',
          'status': 'failure',
          'error': 'SRI mismatch',
        }) +
        '\n';
    expect(() => check(value, inventory), throwsFormatException);
  });

  test('rejects unknown, duplicate and missing cases', () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (value) => specs(value)[0]['title'] = 'fixture unexpected',
      (value) => specs(value).add(specs(value)[0]),
      (value) => specs(value).removeLast(),
    ]) {
      final value = report();
      change(value);
      expect(() => check(value, inventory), throwsFormatException);
    }
  });

  test('rejects incomplete, duplicated, misplaced and malformed Dart events', () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (value) => result(value)['stdout'].removeLast(),
      (value) => result(value)['stdout'].add(result(value)['stdout'][1]),
      (value) =>
          result(value)['stdout'] = result(value)['stdout'].reversed.toList(),
      (value) => result(value)['stdout'][1]['text'] = 'PATROL_LOG {broken}\n',
      (value) => result(value)['stdout'].add({
        'text': 'PATROL_LOG {"type":"error","message":"failure"}\n',
      }),
      (value) => result(value)['stdout'][1]['text'] =
          'PATROL_LOG {"type":"test","name":"fixture other","status":"success"}\n',
    ]) {
      final value = report();
      change(value);
      expect(() => check(value, inventory), throwsFormatException);
    }
  });

  test('rejects browser errors, skips and retries', () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (value) => value['errors'].add({'message': 'browser crash'}),
      (value) => value['stats']['skipped'] = 1,
      (value) => specs(value)[0]['tests'][0]['expectedStatus'] = 'skipped',
      (value) => result(value)['status'] = 'timedOut',
      (value) => result(value)['retry'] = 1,
    ]) {
      final value = report();
      change(value);
      expect(() => check(value, inventory), throwsFormatException);
    }
  });

  test('rejects malformed or empty report and inventory', () {
    for (final value in [
      null,
      [],
      {},
      {'errors': []},
    ]) {
      expect(() => check(value, inventory), throwsFormatException);
    }
    expect(
      () => check(report(), {'suite': 'fixture', 'tests': []}),
      throwsFormatException,
    );
    expect(
      () => check(report(), {
        'suite': 'fixture',
        'tests': ['integrity', 'integrity'],
      }),
      throwsFormatException,
    );
  });
}
