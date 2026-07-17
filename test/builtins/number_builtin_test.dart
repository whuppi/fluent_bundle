// The NUMBER() option parser: every ECMA-402 option key reaches
// FluentNumberOptions, out-of-set values record a FluentFormatError and
// drop to null (Fluent never throws), and the roundingIncrement
// cross-constraints hold. Rendering fidelity per backend is the
// satellites' concern; this file covers parse + validate + merge only.

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_bundle/src/builtins/number_builtin.dart';
import 'package:test/test.dart';

void main() {
  FluentNumberOptions parse(
    Map<String, String> named, [
    List<FluentError>? errors,
  ]) {
    return parseNumberOptions(
      named.map((k, v) => MapEntry(k, FluentString(v))),
      errors ?? <FluentError>[],
    );
  }

  group('parseNumberOptions — the ECMA-402 option surface', () {
    test('every option key parses into its field', () {
      final o = parse({
        'style': 'currency',
        'currency': 'USD',
        'currencyDisplay': 'code',
        'currencySign': 'accounting',
        'notation': 'compact',
        'compactDisplay': 'long',
        'signDisplay': 'exceptZero',
        'roundingMode': 'halfEven',
        'trailingZeroDisplay': 'stripIfInteger',
        'numberingSystem': 'arab',
        'useGrouping': 'false',
      });
      expect(o.style, 'currency');
      expect(o.currency, 'USD');
      expect(o.currencyDisplay, 'code');
      expect(o.currencySign, 'accounting');
      expect(o.notation, 'compact');
      expect(o.compactDisplay, 'long');
      expect(o.signDisplay, 'exceptZero');
      expect(o.roundingMode, 'halfEven');
      expect(o.trailingZeroDisplay, 'stripIfInteger');
      expect(o.numberingSystem, 'arab');
      expect(o.useGrouping, false);
    });

    test('useGrouping is polymorphic: booleans and strategy strings', () {
      expect(parse({'useGrouping': 'false'}).useGrouping, false);
      // ECMA-402 v3 normalizes true to "always".
      expect(parse({'useGrouping': 'true'}).groupingStrategy, 'always');
      expect(parse({'useGrouping': 'min2'}).groupingStrategy, 'min2');
      expect(parse({'useGrouping': 'always'}).groupingStrategy, 'always');
      expect(parse({'useGrouping': 'auto'}).groupingStrategy, 'auto');
      final errors = <FluentError>[];
      final o = parse({'useGrouping': 'maybe'}, errors);
      expect(o.useGrouping, isNull);
      expect(o.groupingStrategy, isNull);
      expect(errors.single, isA<FluentFormatError>());
    });

    test('out-of-set enum values record an error and drop to null', () {
      for (final entry
          in {
            'style': 'weird',
            'currencyDisplay': 'emoji',
            'unitDisplay': 'huge',
            'notation': 'exponential',
            'compactDisplay': 'tiny',
            'signDisplay': 'sometimes',
            'currencySign': 'parens',
            'roundingMode': 'nearest',
            'trailingZeroDisplay': 'strip',
          }.entries) {
        final errors = <FluentError>[];
        final o = parse({entry.key: entry.value}, errors);
        expect(o.isEmpty, isTrue, reason: '${entry.key} should drop');
        expect(errors, hasLength(1), reason: '${entry.key} should error');
        expect(errors.single, isA<FluentFormatError>());
      }
    });

    test('numberingSystem must be a 3-8 alphanumeric subtag', () {
      final errors = <FluentError>[];
      final o = parse({'numberingSystem': 'no-good!'}, errors);
      expect(o.numberingSystem, isNull);
      expect(errors.single, isA<FluentFormatError>());
    });
  });

  group('roundingIncrement validation', () {
    test('a valid increment with equal fraction bounds passes', () {
      final errors = <FluentError>[];
      final o = parse({
        'roundingIncrement': '25',
        'minimumFractionDigits': '2',
        'maximumFractionDigits': '2',
      }, errors);
      expect(o.roundingIncrement, 25);
      expect(errors, isEmpty);
    });

    test('an out-of-set increment records an error and drops', () {
      final errors = <FluentError>[];
      final o = parse({'roundingIncrement': '30'}, errors);
      expect(o.roundingIncrement, isNull);
      expect(errors.single, isA<FluentFormatError>());
    });

    test('unequal explicit fraction bounds record an error and drop', () {
      final errors = <FluentError>[];
      final o = parse({
        'roundingIncrement': '5',
        'minimumFractionDigits': '1',
        'maximumFractionDigits': '2',
      }, errors);
      expect(o.roundingIncrement, isNull);
      expect(errors.single, isA<FluentFormatError>());
    });

    test('significant-digit options record an error and drop', () {
      final errors = <FluentError>[];
      final o = parse({
        'roundingIncrement': '5',
        'maximumSignificantDigits': '3',
      }, errors);
      expect(o.roundingIncrement, isNull);
      expect(errors.single, isA<FluentFormatError>());
    });

    test('a lone explicit fraction bound defers to the backend', () {
      // ECMA resolves the missing bound from style-dependent defaults, so
      // the parser can't judge it — the backend enforces after resolving.
      final errors = <FluentError>[];
      final o = parse({
        'roundingIncrement': '5',
        'maximumFractionDigits': '0',
      }, errors);
      expect(o.roundingIncrement, 5);
      expect(errors, isEmpty);
    });
  });

  group('merge', () {
    test('named args win over existing values for every new field', () {
      const base = FluentNumberOptions(
        notation: 'standard',
        compactDisplay: 'short',
        signDisplay: 'auto',
        currencySign: 'standard',
        roundingMode: 'halfExpand',
        roundingIncrement: 1,
        trailingZeroDisplay: 'auto',
        numberingSystem: 'latn',
      );
      const override = FluentNumberOptions(
        notation: 'compact',
        compactDisplay: 'long',
        signDisplay: 'never',
        currencySign: 'accounting',
        roundingMode: 'ceil',
        roundingIncrement: 25,
        trailingZeroDisplay: 'stripIfInteger',
        numberingSystem: 'arab',
      );
      final merged = base.merge(override);
      expect(merged.notation, 'compact');
      expect(merged.compactDisplay, 'long');
      expect(merged.signDisplay, 'never');
      expect(merged.currencySign, 'accounting');
      expect(merged.roundingMode, 'ceil');
      expect(merged.roundingIncrement, 25);
      expect(merged.trailingZeroDisplay, 'stripIfInteger');
      expect(merged.numberingSystem, 'arab');
      // Null overrides keep the base value.
      expect(base.merge(const FluentNumberOptions()).notation, 'standard');
    });
  });

  group('NUMBER() end to end', () {
    test('options flow from FTL named args onto the value', () {
      final bundle = FluentBundle('en-US', useIsolating: false)..addResource(
        'm = { NUMBER(\$n, notation: "compact", signDisplay: "always") }',
      );
      // The spec-fallback backend renders digits only, but the parse must
      // not error — proving the FTL-side surface accepts the new keys.
      final errors = <FluentError>[];
      bundle.formatMessage('m', args: {'n': 1200000}, errors: errors);
      expect(errors.whereType<FluentFormatError>(), isEmpty);
    });
  });
}
