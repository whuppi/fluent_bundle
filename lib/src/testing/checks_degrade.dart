import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_bundle/src/testing/expectations.dart';
import 'package:fluent_bundle/src/testing/harness.dart';

/// The uniform-degrade contract: every unsupported option (a `false`
/// flag) still renders a usable string AND records an error — never a
/// throw, never a silent drop.
List<ConformanceCheck> degradeChecks(
  ConformanceHarness h,
  BackendExpectations expectations,
) {
  if (!expectations.recordsUnsupportedOptionErrors) return const [];

  final unsupported = <String, String>{
    if (!expectations.scientificNotation)
      'scientific notation': r'{ NUMBER($n, notation: "scientific") }',
    if (!expectations.accountingCurrencySign)
      'accounting sign':
          r'{ NUMBER($n, style: "currency", '
          r'currency: "USD", currencySign: "accounting") }',
    if (!expectations.signDisplay)
      'signDisplay': r'{ NUMBER($n, signDisplay: "always") }',
    if (!expectations.compactNotation)
      'compact notation': r'{ NUMBER($n, notation: "compact") }',
    if (!expectations.groupingStrategies)
      'grouping strategy min2': r'{ NUMBER($n, useGrouping: "min2") }',
    if (!expectations.calendar)
      'calendar': r'{ DATETIME($d, year: "numeric", calendar: "buddhist") }',
    if (!expectations.timeZone)
      'timeZone':
          r'{ DATETIME($d, hour: "numeric", '
          r'timeZone: "Asia/Tokyo") }',
  };

  return [
    for (final entry in unsupported.entries)
      (
        name: 'degrade contract: ${entry.key} renders + records an error',
        run: () {
          final args = {'n': -1234, 'd': DateTime.utc(2026, 1, 2, 12)};
          // ONE bundle, TWO calls: errors must record on every call,
          // not just the first — recording inside a cached formatter
          // builder silences the degrade on cache hits, and that bug
          // class is exactly what the second call catches.
          final b = h.bundleWith('en', 'm = ${entry.value}');
          for (var call = 0; call < 2; call++) {
            final errors = <FluentError>[];
            final out = b.formatMessage('m', args: args, errors: errors);
            if (out.isEmpty) {
              throw StateError('${entry.key}: degraded to empty output');
            }
            if (errors.isEmpty) {
              throw StateError(
                '${entry.key}: degraded silently (call ${call + 1})',
              );
            }
          }
        },
      ),
  ];
}
