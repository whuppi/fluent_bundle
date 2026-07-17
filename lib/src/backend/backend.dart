import 'package:fluent_bundle/src/backend/format_context.dart';
import 'package:fluent_bundle/src/backend/plural_category.dart';
import 'package:fluent_bundle/src/values/fluent_value.dart';

/// Everything locale-aware the resolver needs: how to format a number, how
/// to format a date, and which plural category a number falls into.
///
/// The base class IS the Fluent spec fallback — plurals are always `other`,
/// numbers render digit-correct but locale-blind (honoring every
/// [FluentNumberOptions] digit field), dates render ISO-8601. A bundle with
/// no backend is fully spec-compliant; it just has no CLDR knowledge.
///
/// Extend it and override any subset. An unoverridden method keeps spec
/// behavior, so `super.formatNumber(value, context)` is always a valid
/// fallback for a backend that can't handle a particular value or option.
/// CLDR-aware backends (`IntlBackend`, `IcuBackend`) live in the
/// `fluent_intl` and `fluent_icu` satellite packages.
class FluentBackend {
  /// Creates the spec-fallback backend.
  const FluentBackend();

  /// Classify [value] into a CLDR plural category under [context]'s locale
  /// and the requested rule [type]. The base returns [PluralCategory.other]
  /// for everything (spec-minimum: `*[other]` variants always win).
  PluralCategory pluralCategory(
    FluentNumber value,
    PluralRuleType type,
    FluentFormatContext context,
  ) => PluralCategory.other;

  /// Render [value] to a string under [context]. The base is locale-blind
  /// but digit-correct: it applies every digit option (min/max fraction,
  /// significant digits, minimum integer digits) via
  /// `FluentNumber.resolveDigits`, without grouping separators or a
  /// locale-specific decimal mark.
  String formatNumber(FluentNumber value, FluentFormatContext context) =>
      value.resolveDigits().digits;

  /// Render [value] to a string under [context]. The base returns ISO-8601.
  String formatDateTime(FluentDateTime value, FluentFormatContext context) =>
      value.value.toIso8601String();
}
