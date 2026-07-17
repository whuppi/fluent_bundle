import 'package:fluent_bundle/src/backend/format_context.dart';
import 'package:fluent_bundle/src/errors/fluent_error.dart';
import 'package:fluent_bundle/src/values/fluent_value.dart';

/// The `DATETIME()` Fluent built-in. Always registered on a bundle; a
/// backend renders the resulting value's options in its locale.
///
/// Composition (spec): `DATETIME(FluentDateTime)` merges the named args
/// onto the value's options (named win); `DATETIME(FluentNumber)`
/// interprets the number as epoch milliseconds; `DATETIME(FluentNone)`
/// propagates the reason; anything else is a `FluentNone`.
FluentValue dateTimeBuiltin(
  List<FluentValue> positional,
  Map<String, FluentValue> named,
  FluentFormatContext context,
) {
  if (positional.isEmpty) {
    return const FluentNone('DATETIME: missing argument');
  }
  final arg = positional.first;
  final opts = parseDateTimeOptions(named, context.errors);

  if (arg is FluentNone) {
    return FluentNone('DATETIME(${arg.reason})');
  }
  if (arg is FluentDateTime) {
    return FluentDateTime(arg.value, arg.options.merge(opts));
  }
  if (arg is FluentNumber) {
    return FluentDateTime(
      DateTime.fromMillisecondsSinceEpoch(arg.value.toInt()),
      opts,
    );
  }
  return const FluentNone('DATETIME: invalid argument');
}

/// Build [FluentDateTimeOptions] from FTL named args, recording a
/// [FluentFormatError] on [errors] for any recognized option whose value
/// can't be used. Exposed for reuse by conformance tests.
FluentDateTimeOptions parseDateTimeOptions(
  Map<String, FluentValue> named,
  List<FluentError> errors,
) {
  String? str(String key) {
    final v = named[key];
    if (v == null) return null;
    if (v is FluentString) return v.value;
    errors.add(FluentFormatError('DATETIME: "$key" expects a string'));
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
        'DATETIME: "$key" expects one of ${allowed.join(", ")} (got "$v")',
      ),
    );
    return null;
  }

  bool? boolean(String key) {
    final v = named[key];
    if (v == null) return null;
    if (v is FluentString) {
      if (v.value == 'true') return true;
      if (v.value == 'false') return false;
    }
    errors.add(FluentFormatError('DATETIME: "$key" expects "true" or "false"'));
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
    errors.add(FluentFormatError('DATETIME: "$key" expects an integer'));
    return null;
  }

  // hourCycle folds into the locale's -u-hc- extension, so an out-of-set
  // value must not pass through; record and drop (Fluent never throws).
  var hourCycle = str('hourCycle');
  if (hourCycle != null &&
      !const {'h11', 'h12', 'h23', 'h24'}.contains(hourCycle)) {
    errors.add(
      FluentFormatError(
        'DATETIME: "hourCycle" expects one of h11, h12, h23, h24 '
        '(got "$hourCycle")',
      ),
    );
    hourCycle = null;
  }

  const styleValues = {'full', 'long', 'medium', 'short'};
  const nameWidths = {'narrow', 'short', 'long'};
  const numericWidths = {'numeric', '2-digit'};

  // ECMA-402 allows 1-3 fractional second digits.
  var fractionalSecondDigits = integer('fractionalSecondDigits');
  if (fractionalSecondDigits != null &&
      (fractionalSecondDigits < 1 || fractionalSecondDigits > 3)) {
    errors.add(
      FluentFormatError(
        'DATETIME: "fractionalSecondDigits" expects 1, 2, or 3 '
        '(got $fractionalSecondDigits)',
      ),
    );
    fractionalSecondDigits = null;
  }

  // calendar / numberingSystem fold into -u- locale extensions, so an
  // invalid shape must not pass through (subtag sequences of 3-8
  // alphanumerics, e.g. "gregory", "islamic-civil", "latn").
  String? extensionSubtags(String key) {
    final v = str(key);
    if (v == null ||
        RegExp(r'^[a-zA-Z0-9]{3,8}(-[a-zA-Z0-9]{3,8})*$').hasMatch(v)) {
      return v;
    }
    errors.add(
      FluentFormatError(
        'DATETIME: "$key" is not a valid Unicode extension value (got "$v")',
      ),
    );
    return null;
  }

  return FluentDateTimeOptions(
    dateStyle: strOf('dateStyle', styleValues),
    timeStyle: strOf('timeStyle', styleValues),
    weekday: strOf('weekday', nameWidths),
    era: strOf('era', nameWidths),
    dayPeriod: strOf('dayPeriod', nameWidths),
    timeZoneName: strOf('timeZoneName', const {
      'short', 'long', 'shortOffset', 'longOffset', //
      'shortGeneric', 'longGeneric',
    }),
    year: strOf('year', numericWidths),
    month: strOf('month', const {
      'numeric', '2-digit', 'narrow', 'short', 'long', //
    }),
    day: strOf('day', numericWidths),
    hour: strOf('hour', numericWidths),
    minute: strOf('minute', numericWidths),
    second: strOf('second', numericWidths),
    fractionalSecondDigits: fractionalSecondDigits,
    hour12: boolean('hour12'),
    hourCycle: hourCycle,
    timeZone: str('timeZone'),
    calendar: extensionSubtags('calendar'),
    numberingSystem: extensionSubtags('numberingSystem'),
  );
}
