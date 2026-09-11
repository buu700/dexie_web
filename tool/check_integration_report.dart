/// Validate the browser's completed SDK report against an independent inventory.
/// The driver calls this only after Flutter has received the test completion.
int validateIntegrationReport(Object? data, Object? inventory, String runId) {
  Never invalid(String message) => throw FormatException(message);
  if (runId.isEmpty ||
      data is! Map<String, dynamic> ||
      data['runId'] != runId) {
    invalid('Missing report or report from a different invocation.');
  }
  if (inventory is! Map<String, dynamic> || inventory['tests'] is! List) {
    invalid('Invalid test inventory.');
  }
  final declared = inventory['tests'] as List;
  if (declared.isEmpty || declared.any((n) => n is! String || n.isEmpty)) {
    invalid('The test inventory must contain nonempty names.');
  }
  final expected = declared.toSet();
  if (expected.length != declared.length) invalid('Duplicate inventory names.');
  final executed = data['executed'];
  final results = data['results'];
  if (executed is! List || results is! Map<String, dynamic>) {
    invalid('Missing invocations or framework results.');
  }
  if (executed.length != expected.length ||
      executed.toSet().length != expected.length ||
      !executed.toSet().containsAll(expected) ||
      results.length != expected.length ||
      !results.keys.toSet().containsAll(expected)) {
    invalid('Missing, skipped, repeated, or unexpected test cases.');
  }
  if (results.values.any((result) => result != 'success')) {
    invalid('Flutter reported a failed or incomplete test.');
  }
  return expected.length;
}
