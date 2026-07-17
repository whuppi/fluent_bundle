part of 'fluent_value.dart';

/// Options accepted by [FluentNumber] and the `NUMBER()` builtin.
///
/// Every field is nullable so partial overrides compose cleanly via
/// [merge]. `type` (`'cardinal'` / `'ordinal'`) is the only Fluent-side
/// extension; the rest are formatting knobs the locale-aware adapter
/// translates into its underlying number formatter.
@immutable
final class FluentNumberOptions {
  /// Bundles the ECMA-402 NUMBER option surface; every field
  /// nullable, null meaning "not requested".
  const FluentNumberOptions({
    this.type,
    this.style,
    this.currency,
    this.currencyDisplay,
    this.unit,
    this.unitDisplay,
    this.notation,
    this.compactDisplay,
    this.signDisplay,
    this.currencySign,
    this.roundingMode,
    this.roundingIncrement,
    this.trailingZeroDisplay,
    this.numberingSystem,
    this.useGrouping,
    this.groupingStrategy,
    this.minimumIntegerDigits,
    this.minimumFractionDigits,
    this.maximumFractionDigits,
    this.minimumSignificantDigits,
    this.maximumSignificantDigits,
  });

  /// The plural-rule table for select matching. `null` means cardinal.
  /// Set by `NUMBER($n, type: "ordinal")`.
  final PluralRuleType? type;

  /// `'decimal'` (default), `'currency'`, `'percent'`, `'unit'`.
  final String? style;

  /// ISO 4217 currency code (`USD`, `EUR`, …). Required when style is
  /// `'currency'`; ignored otherwise.
  final String? currency;

  /// `'symbol'` (default), `'narrowSymbol'`, `'code'`, `'name'`.
  final String? currencyDisplay;

  /// Unit identifier (e.g. `'kilogram'`). Required when style is `'unit'`.
  final String? unit;

  /// `'short'` (default), `'narrow'`, `'long'`.
  final String? unitDisplay;

  /// `'standard'` (default), `'scientific'`, `'engineering'`, `'compact'`.
  final String? notation;

  /// `'short'` (default) or `'long'`. Only meaningful with
  /// `notation: 'compact'`.
  final String? compactDisplay;

  /// `'auto'` (default), `'always'`, `'never'`, `'exceptZero'`,
  /// `'negative'`. The sign reflects the value AFTER rounding.
  final String? signDisplay;

  /// `'standard'` (default) or `'accounting'`. Only meaningful when style
  /// is `'currency'`.
  final String? currencySign;

  /// One of the nine ECMA-402 modes: `'ceil'`, `'floor'`, `'expand'`,
  /// `'trunc'`, `'halfCeil'`, `'halfFloor'`, `'halfExpand'` (default),
  /// `'halfTrunc'`, `'halfEven'`.
  final String? roundingMode;

  /// One of 1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000,
  /// 2500, 5000. Requires equal minimum/maximum fraction digits and is
  /// incompatible with significant-digit options.
  final int? roundingIncrement;

  /// `'auto'` (default) or `'stripIfInteger'`.
  final String? trailingZeroDisplay;

  /// Numbering system (e.g. `'latn'`, `'arab'`, `'deva'`). Folded into the
  /// locale's `-u-nu-` extension by the backend.
  final String? numberingSystem;

  /// Whether to use grouping separators. Defaults to true.
  final bool? useGrouping;

  /// `'auto'`, `'always'`, `'min2'` — ECMA-402 v3's string forms of
  /// `useGrouping`. In FTL both spellings share the one `useGrouping`
  /// key (`useGrouping: "min2"`); the parser routes booleans here vs
  /// strings there. When both are set, [groupingStrategy] wins.
  final String? groupingStrategy;

  /// ECMA `minimumIntegerDigits` (1-21).
  final int? minimumIntegerDigits;

  /// ECMA `minimumFractionDigits` (0-100).
  final int? minimumFractionDigits;

  /// ECMA `maximumFractionDigits` (0-100).
  final int? maximumFractionDigits;

  /// ECMA `minimumSignificantDigits` (1-21).
  final int? minimumSignificantDigits;

  /// ECMA `maximumSignificantDigits` (1-21).
  final int? maximumSignificantDigits;

  /// Whether this value carries any non-default option.
  bool get isEmpty =>
      type == null &&
      style == null &&
      currency == null &&
      currencyDisplay == null &&
      unit == null &&
      unitDisplay == null &&
      notation == null &&
      compactDisplay == null &&
      signDisplay == null &&
      currencySign == null &&
      roundingMode == null &&
      roundingIncrement == null &&
      trailingZeroDisplay == null &&
      numberingSystem == null &&
      useGrouping == null &&
      groupingStrategy == null &&
      minimumIntegerDigits == null &&
      minimumFractionDigits == null &&
      maximumFractionDigits == null &&
      minimumSignificantDigits == null &&
      maximumSignificantDigits == null;

  /// Return a new options object with values from [other] overriding
  /// non-null fields here.
  FluentNumberOptions merge(FluentNumberOptions other) {
    return FluentNumberOptions(
      type: other.type ?? type,
      style: other.style ?? style,
      currency: other.currency ?? currency,
      currencyDisplay: other.currencyDisplay ?? currencyDisplay,
      unit: other.unit ?? unit,
      unitDisplay: other.unitDisplay ?? unitDisplay,
      notation: other.notation ?? notation,
      compactDisplay: other.compactDisplay ?? compactDisplay,
      signDisplay: other.signDisplay ?? signDisplay,
      currencySign: other.currencySign ?? currencySign,
      roundingMode: other.roundingMode ?? roundingMode,
      roundingIncrement: other.roundingIncrement ?? roundingIncrement,
      trailingZeroDisplay: other.trailingZeroDisplay ?? trailingZeroDisplay,
      numberingSystem: other.numberingSystem ?? numberingSystem,
      useGrouping: other.useGrouping ?? useGrouping,
      groupingStrategy: other.groupingStrategy ?? groupingStrategy,
      minimumIntegerDigits: other.minimumIntegerDigits ?? minimumIntegerDigits,
      minimumFractionDigits:
          other.minimumFractionDigits ?? minimumFractionDigits,
      maximumFractionDigits:
          other.maximumFractionDigits ?? maximumFractionDigits,
      minimumSignificantDigits:
          other.minimumSignificantDigits ?? minimumSignificantDigits,
      maximumSignificantDigits:
          other.maximumSignificantDigits ?? maximumSignificantDigits,
    );
  }
}

/// A numeric value plus its formatting options.
///
/// Auto-coerced from any host-language `num` (or its subtypes `int` /
/// `double`). Numeric variant keys (`[1]`, `[42]`) match by numeric
/// equality; identifier keys (`[one]`, `[other]`) match by CLDR plural
/// category, supplied by the bundle's backend. Use `IntlBackend` from
/// `package:fluent_intl` (or `IcuBackend` from `package:fluent_icu`) for
/// real CLDR matching.
@immutable
class FluentNumber extends FluentValue {
  /// Wraps [value] with its formatting [options].
  const FluentNumber(this.value, [this.options = const FluentNumberOptions()]);

  /// The number to format and plural-select on.
  final num value;

  /// The NUMBER options carried by this value.
  final FluentNumberOptions options;

  /// Locale-blind string form. Used for diagnostics and as a fallback;
  /// real rendering routes through the bundle's number formatter.
  @override
  String get rawString => value.toString();

  @override
  String format(FluentFormatContext context) =>
      context.backend.formatNumber(this, context);

  /// Resolve this value against its digit options into an exact decimal
  /// digit string plus the count of visible fraction digits.
  ///
  /// This is `Intl.PluralRules` digit resolution (ECMA-402): significant-
  /// digit rules when present, otherwise min/max fraction rules with the
  /// PluralRules defaults (minimum 0, maximum `max(minimum, 3)`), honoring
  /// `roundingMode`, `roundingIncrement`, and `trailingZeroDisplay` — the
  /// same knobs the backends render with, so plural selection agrees with
  /// the rendered string on any backend that supports the option (and
  /// stays consistent ACROSS backends when one degrades the render: the
  /// selection follows the requested options, and the degrade error flags
  /// the render). `notation` is deliberately ignored: `Intl.PluralRules`
  /// accepts rounding options but not notation, so compact abbreviation
  /// never changes a plural category.
  ///
  /// All arithmetic is exact (digit strings + BigInt carries) on the
  /// value's shortest decimal representation — the same source both
  /// ICU4X and package:intl round from. The result carries NO grouping
  /// separators and NO locale-specific decimal mark.
  ///
  /// `fractionDigits` is the CLDR plural operand `v` (visible fraction
  /// digits): it is why `NUMBER($n, minimumFractionDigits: 1)` with `n = 1`
  /// selects `other` in English, not `one`.
  ({String digits, int fractionDigits}) resolveDigits() {
    final o = options;
    if (value is double && !(value as double).isFinite) {
      return (digits: value.toString(), fractionDigits: 0);
    }
    final negative = value.isNegative && value != 0;
    final abs = value.abs();
    final mode = o.roundingMode ?? 'halfExpand';

    var (intPart, fracPart) = _decompose(abs);
    if (o.minimumSignificantDigits != null ||
        o.maximumSignificantDigits != null) {
      (intPart, fracPart) = _roundSignificant(
        intPart,
        fracPart,
        minSig: o.minimumSignificantDigits ?? 1,
        maxSig: o.maximumSignificantDigits ?? 21,
        mode: mode,
        negative: negative,
      );
    } else {
      var minFrac = o.minimumFractionDigits ?? 0;
      final maxFrac = o.maximumFractionDigits ?? (minFrac > 3 ? minFrac : 3);
      // An explicit maximum wins over a larger minimum (the backends
      // record the conflict; operands must match what they render).
      if (minFrac > maxFrac) minFrac = maxFrac;
      final inc = o.roundingIncrement;
      if (inc != null && inc != 1 && minFrac == maxFrac) {
        (intPart, fracPart) = _roundToIncrement(
          intPart,
          fracPart,
          maxFrac,
          inc,
          mode,
          negative,
        );
      } else {
        (intPart, fracPart) = _roundAtFraction(
          intPart,
          fracPart,
          maxFrac,
          mode,
          negative,
        );
        fracPart = _padOrStripFraction(fracPart, minFrac);
      }
    }

    if (o.trailingZeroDisplay == 'stripIfInteger' &&
        fracPart.isNotEmpty &&
        !fracPart.contains(RegExp('[1-9]'))) {
      fracPart = '';
    }

    intPart = intPart.padLeft(o.minimumIntegerDigits ?? 1, '0');
    final body = fracPart.isEmpty ? intPart : '$intPart.$fracPart';
    return (
      digits: negative ? '-$body' : body,
      fractionDigits: fracPart.length,
    );
  }

  @override
  String toString() => 'FluentNumber($value)';
}
