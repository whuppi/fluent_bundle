import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_bundle/src/testing/expectations.dart';
import 'package:fluent_bundle/src/testing/harness.dart';

const _plural = 'p = { \$n ->\n [one] one\n *[other] other\n}';

/// The baseline every backend must clear regardless of flags (NUMBER and
/// DATETIME render at all), plus the plural-selection fundamentals.
List<ConformanceCheck> coreChecks(
  ConformanceHarness h,
  BackendExpectations expectations,
) {
  final checks = <ConformanceCheck>[
    (
      name: 'NUMBER renders digit-correct',
      run: () {
        final b = h.bundleWith('en', 'm = { NUMBER(\$n) }');
        final out = b.formatMessage('m', args: {'n': 1234});
        // Grouping is backend-specific; assert the digits are present.
        h.eq(out.replaceAll(RegExp('[^0-9]'), ''), '1234', 'NUMBER digits');
      },
    ),
    (
      name: 'DATETIME renders',
      run: () {
        final b = h.bundleWith('en', 'm = { DATETIME(\$d) }');
        final out = b.formatMessage('m', args: {'d': DateTime.utc(2026, 1, 2)});
        if (out.isEmpty) throw StateError('DATETIME rendered empty');
      },
    ),
  ];

  if (expectations.localeAwarePlurals) {
    checks.add((
      name: 'plural: English 1 => one, 2 => other',
      run: () {
        final b = h.bundleWith('en', _plural);
        h.eq(b.formatMessage('p', args: {'n': 1}), 'one', 'plural(1)');
        h.eq(b.formatMessage('p', args: {'n': 2}), 'other', 'plural(2)');
      },
    ));
  }

  if (expectations.operandAwarePlurals) {
    checks.add((
      name: 'F8 regression: 1 with minFrac 1 (=> "1.0") selects other',
      run: () {
        final b = h.bundleWith('en', _plural);
        final out = b.formatMessage(
          'p',
          args: {
            'n': const FluentNumber(
              1,
              FluentNumberOptions(minimumFractionDigits: 1),
            ),
          },
        );
        h.eq(out, 'other', 'F8 visible-fraction-digit plural');
      },
    ));
  }

  return checks;
}
