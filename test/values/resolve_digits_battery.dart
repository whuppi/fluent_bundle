import 'package:fluent_bundle/src/values/fluent_value.dart';
import 'package:test/test.dart';

void registerResolveDigitsTests() {
  group('FluentNumber.resolveDigits — ECMA-402 digit resolution', () {
    void expectDigits(FluentNumber n, String digits, int frac) {
      final r = n.resolveDigits();
      expect(r.digits, digits, reason: 'digits for ${n.value} ${n.options}');
      expect(r.fractionDigits, frac, reason: 'v for ${n.value} ${n.options}');
    }

    test(
      'integer, no options',
      () => expectDigits(const FluentNumber(1), '1', 0),
    );
    test(
      'the F8 case: 1 with minFrac 1 -> 1.0 v=1',
      () => expectDigits(
        const FluentNumber(1, FluentNumberOptions(minimumFractionDigits: 1)),
        '1.0',
        1,
      ),
    );
    test(
      'decimal passthrough',
      () => expectDigits(const FluentNumber(1.5), '1.5', 1),
    );
    test(
      'minFrac pads',
      () => expectDigits(
        const FluentNumber(1.5, FluentNumberOptions(minimumFractionDigits: 2)),
        '1.50',
        2,
      ),
    );
    test(
      'maxFrac rounds',
      () => expectDigits(
        const FluentNumber(
          1.2345,
          FluentNumberOptions(maximumFractionDigits: 2),
        ),
        '1.23',
        2,
      ),
    );
    test(
      'zero with minFrac',
      () => expectDigits(
        const FluentNumber(0, FluentNumberOptions(minimumFractionDigits: 2)),
        '0.00',
        2,
      ),
    );
    test('negative', () => expectDigits(const FluentNumber(-1.5), '-1.5', 1));
    test(
      'minIntegerDigits pads',
      () => expectDigits(
        const FluentNumber(1000, FluentNumberOptions(minimumIntegerDigits: 5)),
        '01000',
        0,
      ),
    );
    test(
      'literal precision 3.14',
      () => expectDigits(
        const FluentNumber(3.14, FluentNumberOptions(minimumFractionDigits: 2)),
        '3.14',
        2,
      ),
    );
    test(
      'minSignificant pads fraction',
      () => expectDigits(
        const FluentNumber(1, FluentNumberOptions(minimumSignificantDigits: 3)),
        '1.00',
        2,
      ),
    );
    test(
      'maxSignificant rounds',
      () => expectDigits(
        const FluentNumber(
          1.23456,
          FluentNumberOptions(maximumSignificantDigits: 3),
        ),
        '1.23',
        2,
      ),
    );
    test(
      'integer maxFrac no trailing',
      () => expectDigits(
        const FluentNumber(100, FluentNumberOptions(maximumFractionDigits: 2)),
        '100',
        0,
      ),
    );

    test(
      'PluralRules default: minFrac 1 keeps the 3-digit maximum',
      // ECMA: mxfd defaults to max(mnfd, 3) — a bare minimum must not
      // shrink the maximum (1.25 renders "1.25", not "1.3").
      () => expectDigits(
        const FluentNumber(1.25, FluentNumberOptions(minimumFractionDigits: 1)),
        '1.25',
        2,
      ),
    );

    test(
      'explicit maximum wins over a larger minimum',
      () => expectDigits(
        const FluentNumber(
          1.239,
          FluentNumberOptions(
            minimumFractionDigits: 3,
            maximumFractionDigits: 1,
          ),
        ),
        '1.2',
        1,
      ),
    );

    test('exponent-form doubles decompose exactly', () {
      expectDigits(const FluentNumber(1.5e-7), '0', 0);
      expectDigits(
        const FluentNumber(
          1.5e-7,
          FluentNumberOptions(maximumFractionDigits: 8),
        ),
        '0.00000015',
        8,
      );
      expectDigits(const FluentNumber(1e21), '1000000000000000000000', 0);
    });
  });

  group('FluentNumber.resolveDigits — rounding modes', () {
    void expectDigits(FluentNumber n, String digits) {
      expect(
        n.resolveDigits().digits,
        digits,
        reason: 'digits for ${n.value} ${n.options}',
      );
    }

    FluentNumber n(num v, String mode, {int maxFrac = 0}) => FluentNumber(
      v,
      FluentNumberOptions(roundingMode: mode, maximumFractionDigits: maxFrac),
    );

    test('floor / ceil / trunc / expand on positive magnitudes', () {
      expectDigits(n(1.9, 'floor'), '1');
      expectDigits(n(1.1, 'ceil'), '2');
      expectDigits(n(1.9, 'trunc'), '1');
      expectDigits(n(1.1, 'expand'), '2');
    });

    test('directed modes flip on negatives (floor grows magnitude)', () {
      expectDigits(n(-1.1, 'floor'), '-2');
      expectDigits(n(-1.9, 'ceil'), '-1');
      expectDigits(n(-1.9, 'trunc'), '-1');
      expectDigits(n(-1.1, 'expand'), '-2');
    });

    test('the five half modes on exact ties', () {
      expectDigits(n(2.5, 'halfExpand'), '3');
      expectDigits(n(2.5, 'halfTrunc'), '2');
      expectDigits(n(2.5, 'halfEven'), '2');
      expectDigits(n(3.5, 'halfEven'), '4');
      expectDigits(n(-2.5, 'halfCeil'), '-2');
      expectDigits(n(-2.5, 'halfFloor'), '-3');
    });

    test('non-tie half cases round by the first discarded digit', () {
      expectDigits(n(2.451, 'halfEven', maxFrac: 1), '2.5');
      expectDigits(n(2.44, 'halfExpand', maxFrac: 1), '2.4');
    });

    test('carry propagates across the decimal point', () {
      // minFrac defaults to 0, so the carried zeros strip afterwards.
      expectDigits(n(9.99, 'halfExpand', maxFrac: 1), '10');
      expectDigits(n(0.999, 'halfExpand', maxFrac: 2), '1');
    });

    test('rounding modes apply to significant digits too', () {
      expect(
        const FluentNumber(
          1.25,
          FluentNumberOptions(
            maximumSignificantDigits: 2,
            roundingMode: 'floor',
          ),
        ).resolveDigits().digits,
        '1.2',
      );
      expect(
        const FluentNumber(
          999.9,
          FluentNumberOptions(maximumSignificantDigits: 3),
        ).resolveDigits().digits,
        '1000',
      );
    });
  });

  group('FluentNumber.resolveDigits — increment + trailing zeros', () {
    test('roundingIncrement rounds to the multiple, keeps the bounds', () {
      const opts = FluentNumberOptions(
        roundingIncrement: 25,
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      );
      expect(const FluentNumber(1.13, opts).resolveDigits(), (
        digits: '1.25',
        fractionDigits: 2,
      ));
      expect(const FluentNumber(1.12, opts).resolveDigits(), (
        digits: '1.00',
        fractionDigits: 2,
      ));
    });

    test('increment 5 at 0 fraction digits (the engine parity case)', () {
      const opts = FluentNumberOptions(
        roundingIncrement: 5,
        minimumFractionDigits: 0,
        maximumFractionDigits: 0,
      );
      expect(const FluentNumber(1.1, opts).resolveDigits().digits, '0');
      expect(const FluentNumber(3.2, opts).resolveDigits().digits, '5');
    });

    test('stripIfInteger drops the fraction — and its plural operand', () {
      // NUMBER(1, minFrac: 2, stripIfInteger) renders "1": v must be 0
      // so English selects `one`, matching the render.
      expect(
        const FluentNumber(
          1,
          FluentNumberOptions(
            minimumFractionDigits: 2,
            trailingZeroDisplay: 'stripIfInteger',
          ),
        ).resolveDigits(),
        (digits: '1', fractionDigits: 0),
      );
      expect(
        const FluentNumber(
          1.5,
          FluentNumberOptions(
            minimumFractionDigits: 2,
            trailingZeroDisplay: 'stripIfInteger',
          ),
        ).resolveDigits(),
        (digits: '1.50', fractionDigits: 2),
      );
    });
  });
}
