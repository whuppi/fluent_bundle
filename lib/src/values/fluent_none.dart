part of 'fluent_value.dart';

/// A fallback value returned when resolution can't produce a real one
/// (missing variable, unknown reference, uncoerceable host value).
///
/// Two flavors, distinguished by [bare]:
///
///   - **Wrapped (default).** [reason] is treated as a missing-
///     reference identifier and rendered with surrounding braces:
///     `{$name}`, `{-brand}`, `{NAME($missing)}`. This is the form
///     for "I tried to look up `reason` and didn't find it" — the
///     classic FluentNone.
///   - **Bare.** [reason] is rendered verbatim, no braces. Used by
///     built-in or user-supplied functions to signal "this call
///     itself failed; render the source-form reference inline."
///     Example: `IDENTITY()` called with no args returns
///     `FluentNone.bare('IDENTITY()')`, which renders as the literal
///     string `IDENTITY()` inside the surrounding pattern.
///
/// Resolvers should ALSO record an associated runtime
/// [FluentError](../errors/fluent_error.dart) on the scope's error
/// list — `FluentNone` is the visible fallback, the error list is
/// the diagnostic channel.
@immutable
final class FluentNone extends FluentValue {
  /// Creates the placeholder for a failed resolution of [reason].
  const FluentNone(this.reason) : bare = false;

  /// A FluentNone whose [rawString] is [reason] verbatim, no braces.
  /// Returned by functions to signal a call-time failure that should
  /// surface as the bare source-form reference (e.g. `IDENTITY()`).
  const FluentNone.bare(this.reason) : bare = true;

  /// A short, developer-facing description of what went missing. Often
  /// the original reference syntax (e.g. `$name`, `-brand`) so the
  /// rendered output points at the failing slot.
  final String reason;

  /// When true, [rawString] returns [reason] verbatim — no surrounding
  /// braces. Used for function-call "this call failed" signals where
  /// the source-form `NAME()` is the user-facing fallback. The default
  /// (false) renders `{$name}`-style fallbacks for missing references.
  final bool bare;

  @override
  String get rawString => bare ? reason : '{$reason}';

  @override
  String toString() =>
      bare ? 'FluentNone.bare($reason)' : 'FluentNone($reason)';
}
