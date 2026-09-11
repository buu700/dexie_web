import 'package:flutter_test/flutter_test.dart';

import 'check_integration_report.dart';

const inventory = {
  'tests': ['integrity', 'persistence'],
};
Map<String, dynamic> report() => {
  'runId': 'current',
  'executed': ['integrity', 'persistence'],
  'results': <String, dynamic>{
    'integrity': 'success',
    'persistence': 'success',
  },
};

void main() {
  test('requires actual invocations and framework success for every case', () {
    expect(validateIntegrationReport(report(), inventory, 'current'), 2);
  });
  test('rejects prior, missing, and malformed reports', () {
    for (final value in [
      null,
      [],
      {},
      {...report(), 'runId': 'old'},
    ]) {
      expect(
        () => validateIntegrationReport(value, inventory, 'current'),
        throwsFormatException,
      );
    }
    expect(
      () => validateIntegrationReport(report(), inventory, ''),
      throwsFormatException,
    );
  });
  test('rejects empty, duplicate, and malformed inventories', () {
    for (final value in [
      null,
      {},
      {'tests': []},
      {
        'tests': ['integrity', 'integrity'],
      },
      {
        'tests': [null],
      },
    ]) {
      expect(
        () => validateIntegrationReport(report(), value, 'current'),
        throwsFormatException,
      );
    }
  });
  test(
    'rejects skipped, missing, duplicate, unknown, and unfinished cases',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (r) => r['executed'].removeLast(),
        (r) => r['executed'].add('integrity'),
        (r) => r['executed'][1] = 'integrity',
        (r) => r['executed'][1] = 'unknown',
        (r) => r['results'].remove('persistence'),
        (r) => r['results']['unknown'] = 'success',
        (r) => r['results']['persistence'] = 'failure',
        (r) => r['results']['persistence'] = 'skipped',
        (r) => r['results']['persistence'] = null,
        (r) => r['results'] = [],
        (r) => r['executed'] = {},
      ]) {
        final value = report();
        change(value);
        expect(
          () => validateIntegrationReport(value, inventory, 'current'),
          throwsFormatException,
        );
      }
    },
  );
}
