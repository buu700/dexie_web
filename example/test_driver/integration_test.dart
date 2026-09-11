import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import '../../tool/check_integration_report.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 10),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    await File('test-results/integration.json').writeAsString(jsonEncode(data));
    final inventory = jsonDecode(
      await File('../tool/integration_test_inventory.json').readAsString(),
    );
    final count = validateIntegrationReport(
      data,
      inventory,
      Platform.environment['E2E_RUN_ID'] ?? '',
    );
    stdout.writeln('Browser integration inventory passed: $count tests.');
  },
);
