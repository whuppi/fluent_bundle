import 'package:fluent_bundle/src/backend/format_context.dart';
import 'package:fluent_bundle/src/backend/plural_category.dart';
import 'package:meta/meta.dart';

part 'digit_resolution.dart';
part 'fluent_string.dart';
part 'fluent_number.dart';
part 'fluent_datetime.dart';
part 'fluent_none.dart';

/// The runtime representation of any value Fluent can format or compare.
///
/// Concrete subclasses live in `part` files in this directory:
///   - [FluentString] — string literals and host `String` args
///   - [FluentNumber] — host `num` args + numeric literals
///   - [FluentDateTime] — host `DateTime` args
///   - [FluentNone] — fallback for unresolved or coercion-failed values
///
/// [coerce] turns common host types into the matching wrapper. Pass an
/// existing [FluentValue] through unchanged. Anything else returns a
/// [FluentNone] tagged with the original value's `runtimeType` for
/// diagnostics.
/// This class is open for extension: user-supplied functions may return
/// custom [FluentValue] subclasses that override [format] to render
/// themselves however they like (a relative-time value, a list, a color).
/// The built-in subclasses cover strings, numbers, dates, and the missing
/// fallback; anything else is user code.
@immutable
abstract class FluentValue {
  /// Base constructor for value subtypes.
  const FluentValue();

  /// Render this value to its final string under [context].
  ///
  /// The default returns [rawString]. [FluentNumber] and [FluentDateTime]
  /// override it to route through `context.backend`, so their output is
  /// locale-aware. Custom subclasses override it to define their own
  /// rendering.
  String format(FluentFormatContext context) => rawString;

  /// Convert a host-language value into a [FluentValue]. Recognises:
  ///   - [FluentValue] (returned unchanged)
  ///   - [String] → [FluentString]
  ///   - [num]    → [FluentNumber]
  ///   - [DateTime] → [FluentDateTime]
  /// Anything else returns `FluentNone(reason)` so callers can detect
  /// and report uncoerceable inputs.
  static FluentValue coerce(Object? value) {
    if (value is FluentValue) return value;
    if (value is String) return FluentString(value);
    if (value is num) return FluentNumber(value);
    if (value is DateTime) return FluentDateTime(value);
    final tag = value == null ? 'null' : value.runtimeType.toString();
    return FluentNone('Unsupported argument type: $tag');
  }

  /// Render this value's host-language string form. Plain string-like
  /// values use this directly; [FluentNumber] and [FluentDateTime] are
  /// rendered through the bundle's locale-aware formatter callables, so
  /// callers route through the resolver rather than calling this.
  String get rawString;
}
