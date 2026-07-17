import 'package:fluent_bundle/src/testing/expectations.dart';
import 'package:fluent_bundle/src/testing/harness.dart';

/// The per-option NUMBER capability checks: each ECMA-402 flag runs a
/// structural rendering check when the backend declares support.
/// Assertions are digit/marker-shaped, not exact strings — CLDR versions
/// differ between backends.
List<ConformanceCheck> numberChecks(
  ConformanceHarness h,
  BackendExpectations expectations,
) {
  final checks = <ConformanceCheck>[];

  if (expectations.signDisplay) {
    checks.add((
      name: 'signDisplay: always shows +, never hides -',
      run: () {
        final plus = h.fmt(r'{ NUMBER($n, signDisplay: "always") }', {'n': 5});
        if (!plus.contains('+')) {
          throw StateError('signDisplay always: no "+" in "$plus"');
        }
        final none = h.fmt(r'{ NUMBER($n, signDisplay: "never") }', {'n': -5});
        if (none.contains('-') || none.contains('−')) {
          throw StateError('signDisplay never: sign leaked in "$none"');
        }
      },
    ));
  }

  if (expectations.roundingMode) {
    checks.add((
      name: 'roundingMode: ceil rounds 1.1 up, floor rounds 1.9 down',
      run: () {
        final up = h.fmt(
          r'{ NUMBER($n, roundingMode: "ceil", maximumFractionDigits: 0) }',
          {'n': 1.1},
        );
        h.eq(up.replaceAll(RegExp('[^0-9]'), ''), '2', 'ceil(1.1, 0fd)');
        final down = h.fmt(
          r'{ NUMBER($n, roundingMode: "floor", maximumFractionDigits: 0) }',
          {'n': 1.9},
        );
        h.eq(down.replaceAll(RegExp('[^0-9]'), ''), '1', 'floor(1.9, 0fd)');
      },
    ));
  }

  if (expectations.roundingIncrement) {
    checks.add((
      name: 'roundingIncrement: 25 with 2 fraction digits (nickel-style)',
      run: () {
        final out = h.fmt(
          r'{ NUMBER($n, roundingIncrement: 25, '
          r'minimumFractionDigits: 2, maximumFractionDigits: 2) }',
          {'n': 1.13},
        );
        h.eq(
          out.replaceAll(RegExp('[^0-9]'), ''),
          '125',
          'increment-25 round of 1.13',
        );
      },
    ));
  }

  if (expectations.roundingMode && expectations.operandAwarePlurals) {
    checks.add((
      name: 'plural agrees with roundingMode: floor(1.9) selects one',
      run: () {
        // The render shows "1"; a plural operand rounded half-style
        // would say "2" => other — the render/plural mismatch W-class.
        final b = h.bundleWith(
          'en',
          'p = { NUMBER(\$n, maximumFractionDigits: 0, '
              'roundingMode: "floor") ->\n [one] one\n *[other] other\n}',
        );
        h.eq(
          b.formatMessage('p', args: {'n': 1.9}),
          'one',
          'floor(1.9) plural',
        );
      },
    ));
  }

  if (expectations.trailingZeroDisplay && expectations.operandAwarePlurals) {
    checks.add((
      name: 'plural agrees with stripIfInteger: NUMBER(1, minFrac 2) => one',
      run: () {
        // Renders "1" (fraction stripped), so v=0 must select one —
        // NOT the padded "1.00" operand (v=2 => other).
        final b = h.bundleWith(
          'en',
          'p = { NUMBER(\$n, minimumFractionDigits: 2, '
              'trailingZeroDisplay: "stripIfInteger") ->\n'
              ' [one] one\n *[other] other\n}',
        );
        h.eq(
          b.formatMessage('p', args: {'n': 1}),
          'one',
          'stripIfInteger plural',
        );
      },
    ));
  }

  if (expectations.trailingZeroDisplay) {
    checks.add((
      name: 'trailingZeroDisplay: stripIfInteger drops .00 on integers only',
      run: () {
        final intOut = h.fmt(
          r'{ NUMBER($n, minimumFractionDigits: 2, '
          r'trailingZeroDisplay: "stripIfInteger") }',
          {'n': 5},
        );
        h.eq(
          intOut.replaceAll(RegExp('[^0-9]'), ''),
          '5',
          'stripIfInteger on 5',
        );
        final fracOut = h.fmt(
          r'{ NUMBER($n, minimumFractionDigits: 2, '
          r'trailingZeroDisplay: "stripIfInteger") }',
          {'n': 5.5},
        );
        h.eq(
          fracOut.replaceAll(RegExp('[^0-9]'), ''),
          '550',
          'stripIfInteger on 5.5',
        );
      },
    ));
  }

  if (expectations.numberingSystem) {
    checks.add((
      name: 'numberingSystem: arab renders Arabic-Indic digits',
      run: () {
        final out = h.fmt(r'{ NUMBER($n, numberingSystem: "arab") }', {'n': 5});
        if (!out.contains('٥')) {
          throw StateError('numberingSystem arab: expected ٥ in "$out"');
        }
      },
    ));
  }

  if (expectations.groupingStrategies) {
    checks.add((
      name: 'useGrouping: min2 skips 4-digit groups, groups 5-digit',
      run: () {
        // English "auto" groups 1000 → "1,000"; min2 leaves 4-digit
        // integers ungrouped and only kicks in at 5 digits.
        final four = h.fmt(r'{ NUMBER($n, useGrouping: "min2") }', {'n': 1000});
        if (four.replaceAll(RegExp('[0-9]'), '').isNotEmpty) {
          throw StateError('min2 grouped a 4-digit integer: "$four"');
        }
        final five = h.fmt(r'{ NUMBER($n, useGrouping: "min2") }', {
          'n': 10000,
        });
        if (five.replaceAll(RegExp('[0-9]'), '').isEmpty) {
          throw StateError('min2 left a 5-digit integer ungrouped: "$five"');
        }
      },
    ));
  }

  if (expectations.compactNotation) {
    checks.add((
      name: 'notation: compact abbreviates 1.2M',
      run: () {
        final out = h.fmt(r'{ NUMBER($n, notation: "compact") }', {
          'n': 1200000,
        });
        if (!out.contains('M')) {
          throw StateError('compact notation: expected "M" in "$out"');
        }
        if (out.contains('1,200,000')) {
          throw StateError('compact notation: not compacted: "$out"');
        }
      },
    ));
  }

  if (expectations.scientificNotation) {
    checks.add((
      name: 'notation: scientific renders an exponent',
      run: () {
        final out = h.fmt(r'{ NUMBER($n, notation: "scientific") }', {
          'n': 123456,
        });
        if (!RegExp('[eE]|×10').hasMatch(out)) {
          throw StateError('scientific notation: no exponent in "$out"');
        }
      },
    ));
  }

  if (expectations.accountingCurrencySign) {
    checks.add((
      name: 'currencySign: accounting wraps negatives in parentheses',
      run: () {
        final out = h.fmt(
          r'{ NUMBER($n, style: "currency", currency: "USD", '
          r'currencySign: "accounting") }',
          {'n': -5},
        );
        if (!out.contains('(')) {
          throw StateError('accounting sign: no parenthesis in "$out"');
        }
      },
    ));
  }

  if (expectations.ecmaDefaultDigits) {
    checks.add((
      name: 'ECMA default digits: decimal 3fd, percent 0fd, currency 2fd',
      run: () {
        final dec = h.fmt(r'{ NUMBER($n) }', {'n': 1.23456789});
        h.eq(
          dec.replaceAll(RegExp('[^0-9]'), ''),
          '1235',
          'default decimal digits',
        );
        final pct = h.fmt(r'{ NUMBER($n, style: "percent") }', {'n': 0.1234});
        h.eq(
          pct.replaceAll(RegExp('[^0-9]'), ''),
          '12',
          'default percent digits',
        );
        final cur = h.fmt(
          r'{ NUMBER($n, style: "currency", currency: "USD") }',
          {'n': 5},
        );
        h.eq(
          cur.replaceAll(RegExp('[^0-9]'), ''),
          '500',
          'default currency digits',
        );
        // Per-currency minor units (ECMA CurrencyDigits): yen has none.
        final jpy = h.fmt(
          r'{ NUMBER($n, style: "currency", currency: "JPY") }',
          {'n': 500},
        );
        h.eq(
          jpy.replaceAll(RegExp('[^0-9]'), ''),
          '500',
          'JPY zero minor-unit digits',
        );
      },
    ));
  }

  return checks;
}
