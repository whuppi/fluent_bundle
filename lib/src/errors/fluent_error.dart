import 'package:meta/meta.dart';

/// A runtime error during Fluent message resolution.
///
/// `FluentBundle.formatPattern` and `FluentBundle.formatMessage` never throw
/// these — they collect them in the optional `errors` out-list passed by the
/// caller and always produce a fallback string. This keeps a single missing
/// translation from breaking the rendered UI.
@immutable
sealed class FluentError implements Exception {
  const FluentError();

  /// Human-readable description of what went wrong.
  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A reference to an entity (message, term, attribute, variable, function)
/// that does not exist in the bundle.
final class FluentReferenceError extends FluentError {
  /// Creates the error for the unresolvable [reference].
  const FluentReferenceError(this.reference);

  /// Identifier of the missing entity.
  final String reference;

  @override
  String get message => 'Unknown reference: $reference';
}

/// A built-in function received an argument of an incompatible type.
final class FluentTypeError extends FluentError {
  /// Creates the error with a description of the type mismatch.
  const FluentTypeError(this.message);

  /// The uniform-degrade contract's error shape: a backend that cannot
  /// honor [option] still renders (per [effect]) and records THIS error.
  /// One factory so every satellite degrades with the same sentence —
  /// the conformance harness asserts the contract; this pins the wording.
  FluentTypeError.unsupportedOption({
    required String builtin,
    required String option,
    required String backend,
    required String effect,
    String? hint,
  }) : message =
           '$builtin $option is not supported by the $backend '
               'backend; $effect.${hint == null ? '' : ' $hint'}';

  /// ECMA-402 throws a TypeError for `style: currency` without a valid
  /// currency code; Fluent records this and degrades to decimal. Shared
  /// so both the message and the degrade target stay identical across
  /// backends (see [isValidCurrencyCode]).
  FluentTypeError.invalidCurrencyCode(String? code)
    : message =
          'NUMBER style: "currency" requires a 3-letter currency '
              'code (got: ${code ?? "null"}); degrading to decimal';
  @override
  final String message;
}

/// Whether [code] is a well-formed ISO 4217 alphabetic currency code.
/// The shared half of the currency guard — a backend seeing
/// `style: currency` with an invalid code records
/// [FluentTypeError.invalidCurrencyCode] and renders decimal instead.
bool isValidCurrencyCode(String? code) =>
    code != null && RegExp(r'^[a-zA-Z]{3}$').hasMatch(code);

/// Caller-provided value can't be coerced into a FluentValue.
final class FluentArgumentError extends FluentError {
  /// Creates the error for the missing/invalid argument [argName].
  const FluentArgumentError(this.argName);

  /// Name of the offending argument.
  final String argName;

  @override
  String get message => 'Argument "$argName" is not a supported type';
}

/// The bundle hit `MAX_PLACEABLES` (Billion Laughs / Quadratic Blowup guard).
final class FluentResolutionLimitError extends FluentError {
  /// Creates the error — the placeable-expansion cap was hit.
  const FluentResolutionLimitError();
  @override
  final String message =
      'Too many placeables in a single resolution (likely a cyclic or expanding reference)';
}

/// A pattern referenced itself transitively (cycle detected via Scope.dirty).
final class FluentCyclicReferenceError extends FluentError {
  /// Creates the error — a reference cycle was detected.
  const FluentCyclicReferenceError();
  @override
  final String message = 'Cyclic reference detected during resolution';
}

/// `addResource` tried to redefine an existing message or term while
/// `allowOverrides` was false. The existing definition wins; this records
/// the conflict.
final class FluentOverrideError extends FluentError {
  /// Creates the error for a duplicate [id] (term when [isTerm]).
  const FluentOverrideError(this.id, {this.isTerm = false});

  /// Identifier of the entry that would have been overridden.
  final String id;

  /// Whether the conflict was a term (`-id`) rather than a message.
  final bool isTerm;

  @override
  String get message =>
      'Attempt to override existing ${isTerm ? 'term' : 'message'}: '
      '${isTerm ? '-' : ''}$id';
}

/// A backend could not honor a formatting request under the current
/// locale chain — an unsupported option, missing locale data, or an
/// invalid option value. The value still rendered (via a fallback); this
/// records what could not be done so it surfaces during dev.
final class FluentFormatError extends FluentError {
  /// Creates the error with a description of the bad option value.
  const FluentFormatError(this.message);
  @override
  final String message;
}
