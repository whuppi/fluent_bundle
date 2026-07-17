import 'package:fluent_bundle/src/backend/format_context.dart';
import 'package:fluent_bundle/src/backend/plural_category.dart';
import 'package:fluent_bundle/src/errors/fluent_error.dart';
import 'package:fluent_bundle/src/values/fluent_value.dart';

/// The `NUMBER()` Fluent built-in. Always registered on a bundle; a
/// backend renders the resulting value's options in its locale.
///
/// Composition (spec): `NUMBER(FluentNumber)` merges the named args onto
/// the value's existing options (named win); `NUMBER(FluentDateTime)`
/// wraps the epoch milliseconds; `NUMBER(FluentNone)` propagates the
/// reason; anything else is a `FluentNone`.
FluentValue numberBuiltin(
  List<FluentValue> positional,
  Map<String, FluentValue> named,
  FluentFormatContext context,
) {
  if (positional.isEmpty) {
    return const FluentNone('NUMBER: missing argument');
  }
  final arg = positional.first;
  final opts = parseNumberOptions(named, context.errors);

  if (arg is FluentNone) {
    return FluentNone('NUMBER(${arg.reason})');
  }
  if (arg is FluentNumber) {
    return FluentNumber(arg.value, arg.options.merge(opts));
  }
  if (arg is FluentDateTime) {
    return FluentNumber(arg.value.millisecondsSinceEpoch, opts);
  }
  return const FluentNone('NUMBER: invalid argument');
}

/// Build [FluentNumberOptions] from FTL named args, recording a
/// [FluentFormatError] on [errors] for any recognized option whose value
/// can't be used. Exposed for reuse by conformance tests.
FluentNumberOptions parseNumberOptions(
  Map<String, FluentValue> named,
  List<FluentError> errors,
) {
  String? str(String key) {
    final v = named[key];
    if (v == null) return null;
    if (v is FluentString) return v.value;
    errors.add(FluentFormatError('NUMBER: "$key" expects a string'));
    return null;
  }

  // A string option restricted to a fixed ECMA-402 value set. An
  // out-of-set value records an error and is dropped (Fluent never
  // throws), so formatting proceeds with the option's default.
  String? strOf(String key, Set<String> allowed) {
    final v = str(key);
    if (v == null || allowed.contains(v)) return v;
    errors.add(
      FluentFormatError(
        'NUMBER: "$key" expects one of ${allowed.join(", ")} (got "$v")',
      ),
    );
    return null;
  }

  int? integer(String key) {
    final v = named[key];
    if (v == null) return null;
    if (v is FluentNumber) return v.value.toInt();
    if (v is FluentString) {
      final parsed = int.tryParse(v.value);
      if (parsed != null) return parsed;
    }
    errors.add(FluentFormatError('NUMBER: "$key" expects an integer'));
    return null;
  }

  PluralRuleType? ruleType() {
    final v = named['type'];
    if (v == null) return null;
    if (v is FluentString) {
      switch (v.value) {
        case 'cardinal':
          return PluralRuleType.cardinal;
        case 'ordinal':
          return PluralRuleType.ordinal;
      }
    }
    errors.add(
      const FluentFormatError('NUMBER: "type" expects "cardinal" or "ordinal"'),
    );
    return null;
  }

  // ECMA-402 valid rounding increments: {1, 2, 5, 25} × 10^k.
  const validIncrements = {
    1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500, 5000, //
  };

  final minFrac = integer('minimumFractionDigits');
  final maxFrac = integer('maximumFractionDigits');
  final minSig = integer('minimumSignificantDigits');
  final maxSig = integer('maximumSignificantDigits');

  var roundingIncrement = integer('roundingIncrement');
  if (roundingIncrement != null) {
    if (!validIncrements.contains(roundingIncrement)) {
      errors.add(
        FluentFormatError(
          'NUMBER: "roundingIncrement" expects one of '
          '${validIncrements.join(", ")} (got $roundingIncrement)',
        ),
      );
      roundingIncrement = null;
    } else if (roundingIncrement != 1 &&
        (minSig != null ||
            maxSig != null ||
            (minFrac != null && maxFrac != null && minFrac != maxFrac))) {
      // ECMA-402: an increment other than 1 requires fraction-digit
      // rounding with equal minimum/maximum fraction digits, and is
      // incompatible with significant-digit options. Where ECMA throws a
      // RangeError, Fluent records the error and drops the option. When a
      // fraction bound is unset its default is style-dependent, so that
      // half of the constraint is enforced by the backend after it
      // resolves digit defaults — only the unambiguous violations are
      // caught here.
      errors.add(
        const FluentFormatError(
          'NUMBER: "roundingIncrement" requires equal minimumFractionDigits '
          'and maximumFractionDigits, and no significant-digit options',
        ),
      );
      roundingIncrement = null;
    }
  }

  // ECMA-402 v3's useGrouping is polymorphic: booleans AND the strings
  // "auto" / "always" / "min2" ("true" normalizes to "always" per spec).
  // One FTL key feeds two typed fields: booleans → useGrouping, strategy
  // strings → groupingStrategy.
  bool? useGrouping;
  String? groupingStrategy;
  final rawGrouping = named['useGrouping'];
  if (rawGrouping != null) {
    final v = rawGrouping is FluentString ? rawGrouping.value : null;
    switch (v) {
      case 'true':
        groupingStrategy = 'always';
      case 'false':
        useGrouping = false;
      case 'auto' || 'always' || 'min2':
        groupingStrategy = v;
      default:
        errors.add(
          const FluentFormatError(
            'NUMBER: "useGrouping" expects "auto", "always", "min2", '
            '"true", or "false"',
          ),
        );
    }
  }

  // Numbering systems are single Unicode extension subtags (3-8
  // alphanumerics, e.g. "latn", "arab"). Backends fold the value into the
  // locale's -u-nu- extension, so an invalid shape must not pass through.
  var numberingSystem = str('numberingSystem');
  if (numberingSystem != null &&
      !RegExp(r'^[a-zA-Z0-9]{3,8}$').hasMatch(numberingSystem)) {
    errors.add(
      FluentFormatError(
        'NUMBER: "numberingSystem" is not a valid numbering system '
        'identifier (got "$numberingSystem")',
      ),
    );
    numberingSystem = null;
  }

  return FluentNumberOptions(
    type: ruleType(),
    style: strOf('style', const {'decimal', 'percent', 'currency', 'unit'}),
    currency: str('currency'),
    currencyDisplay: strOf('currencyDisplay', const {
      'code', 'symbol', 'narrowSymbol', 'name', //
    }),
    unit: str('unit'),
    unitDisplay: strOf('unitDisplay', const {'short', 'narrow', 'long'}),
    notation: strOf('notation', const {
      'standard', 'scientific', 'engineering', 'compact', //
    }),
    compactDisplay: strOf('compactDisplay', const {'short', 'long'}),
    signDisplay: strOf('signDisplay', const {
      'auto', 'always', 'never', 'exceptZero', 'negative', //
    }),
    currencySign: strOf('currencySign', const {'standard', 'accounting'}),
    roundingMode: strOf('roundingMode', const {
      'ceil', 'floor', 'expand', 'trunc', //
      'halfCeil', 'halfFloor', 'halfExpand', 'halfTrunc', 'halfEven',
    }),
    roundingIncrement: roundingIncrement,
    trailingZeroDisplay: strOf('trailingZeroDisplay', const {
      'auto', 'stripIfInteger', //
    }),
    numberingSystem: numberingSystem,
    useGrouping: useGrouping,
    groupingStrategy: groupingStrategy,
    minimumIntegerDigits: integer('minimumIntegerDigits'),
    minimumFractionDigits: minFrac,
    maximumFractionDigits: maxFrac,
    minimumSignificantDigits: minSig,
    maximumSignificantDigits: maxSig,
  );
}
