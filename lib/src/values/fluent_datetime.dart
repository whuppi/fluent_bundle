part of 'fluent_value.dart';

/// Options accepted by [FluentDateTime] and the `DATETIME()` builtin.
///
/// Every field is nullable so partial overrides compose cleanly via
/// [merge]. The locale-aware adapter translates this option bag into its
/// underlying date/time formatter.
@immutable
final class FluentDateTimeOptions {
  /// Bundles the ECMA-402 DATETIME option surface; every field
  /// nullable, null meaning "not requested".
  const FluentDateTimeOptions({
    this.dateStyle,
    this.timeStyle,
    this.weekday,
    this.era,
    this.dayPeriod,
    this.timeZoneName,
    this.year,
    this.month,
    this.day,
    this.hour,
    this.minute,
    this.second,
    this.fractionalSecondDigits,
    this.hour12,
    this.hourCycle,
    this.timeZone,
    this.calendar,
    this.numberingSystem,
  });

  /// `'full'`, `'long'`, `'medium'`, `'short'`.
  final String? dateStyle;

  /// ECMA `timeStyle`: full / long / medium / short.
  final String? timeStyle;

  /// `'narrow'`, `'short'`, `'long'`.
  final String? weekday;

  /// ECMA `era`: long / short / narrow.
  final String? era;

  /// ECMA `dayPeriod`: long / short / narrow.
  final String? dayPeriod;

  /// ECMA `timeZoneName`: long / short / shortOffset / longOffset /
  /// shortGeneric / longGeneric.
  final String? timeZoneName;

  /// `'numeric'` or `'2-digit'` (and for `month`: also `'narrow'`,
  /// `'short'`, `'long'`).
  final String? year;

  /// ECMA `month`: numeric / 2-digit / long / short / narrow.
  final String? month;

  /// ECMA `day`: numeric / 2-digit.
  final String? day;

  /// ECMA `hour`: numeric / 2-digit.
  final String? hour;

  /// ECMA `minute`: numeric / 2-digit.
  final String? minute;

  /// ECMA `second`: numeric / 2-digit.
  final String? second;

  /// Number of fractional second digits (0-3).
  final int? fractionalSecondDigits;

  /// Whether to use 12-hour clock.
  final bool? hour12;

  /// `'h11'`, `'h12'`, `'h23'`, `'h24'`. Finer-grained than [hour12];
  /// when both are set, `hourCycle` wins.
  final String? hourCycle;

  /// IANA timezone identifier (e.g. `'Europe/Berlin'`).
  final String? timeZone;

  /// Calendar identifier (`'gregory'`, `'islamic'`, …).
  final String? calendar;

  /// Numbering system identifier (`'latn'`, `'arab'`, …).
  final String? numberingSystem;

  /// True when no option is set.
  bool get isEmpty =>
      dateStyle == null &&
      timeStyle == null &&
      weekday == null &&
      era == null &&
      dayPeriod == null &&
      timeZoneName == null &&
      year == null &&
      month == null &&
      day == null &&
      hour == null &&
      minute == null &&
      second == null &&
      fractionalSecondDigits == null &&
      hour12 == null &&
      hourCycle == null &&
      timeZone == null &&
      calendar == null &&
      numberingSystem == null;

  /// Merge, [other]'s non-null fields winning.
  FluentDateTimeOptions merge(FluentDateTimeOptions other) {
    return FluentDateTimeOptions(
      dateStyle: other.dateStyle ?? dateStyle,
      timeStyle: other.timeStyle ?? timeStyle,
      weekday: other.weekday ?? weekday,
      era: other.era ?? era,
      dayPeriod: other.dayPeriod ?? dayPeriod,
      timeZoneName: other.timeZoneName ?? timeZoneName,
      year: other.year ?? year,
      month: other.month ?? month,
      day: other.day ?? day,
      hour: other.hour ?? hour,
      minute: other.minute ?? minute,
      second: other.second ?? second,
      fractionalSecondDigits:
          other.fractionalSecondDigits ?? fractionalSecondDigits,
      hour12: other.hour12 ?? hour12,
      hourCycle: other.hourCycle ?? hourCycle,
      timeZone: other.timeZone ?? timeZone,
      calendar: other.calendar ?? calendar,
      numberingSystem: other.numberingSystem ?? numberingSystem,
    );
  }
}

/// A wall-clock instant plus its formatting options.
///
/// Auto-coerced from a host-language [DateTime]. Variant matching by date
/// equality is uncommon; if needed it falls through to the
/// [FluentValue] string-equality default.
@immutable
class FluentDateTime extends FluentValue {
  /// Wraps [value] with its formatting [options].
  const FluentDateTime(
    this.value, [
    this.options = const FluentDateTimeOptions(),
  ]);

  /// The instant to format.
  final DateTime value;

  /// The DATETIME options carried by this value.
  final FluentDateTimeOptions options;

  /// Locale-blind ISO-8601 string. Used for diagnostics and as a
  /// fallback; real rendering routes through the bundle's date-time
  /// formatter.
  @override
  String get rawString => value.toIso8601String();

  @override
  String format(FluentFormatContext context) =>
      context.backend.formatDateTime(this, context);

  @override
  String toString() => 'FluentDateTime($value)';
}
