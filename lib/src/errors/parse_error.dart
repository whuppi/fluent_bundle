import 'package:meta/meta.dart';

/// A failure during Fluent Syntax parsing.
///
/// Codes are stable (`E0001` .. `E0028`) and match the Fluent reference
/// implementation, so callers can group / localize errors by code.
@immutable
sealed class FluentParseError implements Exception {
  const FluentParseError();

  /// Stable identifier (e.g. `E0003`).
  String get code;

  /// Human-readable description of what went wrong.
  String get message;

  /// Byte offset within the source where parsing failed.
  int get offset;

  @override
  String toString() => 'FluentParseError($code) at $offset: $message';
}

/// E0003 — a specific token was expected (`=`, `}`, …).
final class ExpectedTokenError extends FluentParseError {
  /// Creates the error for the missing [token] at [offset].
  const ExpectedTokenError(this.token, this.offset);
  @override
  final String code = 'E0003';

  /// The token the parser expected to find.
  final String token;
  @override
  final int offset;

  @override
  String get message => 'Expected token: "$token"';
}

/// E0004 — a character in a specific range was expected.
final class ExpectedCharRangeError extends FluentParseError {
  /// Creates the error for the expected [range] at [offset].
  const ExpectedCharRangeError(this.range, this.offset);
  @override
  final String code = 'E0004';

  /// Human-readable description of the accepted range.
  final String range;
  @override
  final int offset;

  @override
  String get message => 'Expected a character from range: "$range"';
}

/// E0005 — a message needs a value or attributes.
final class ExpectedMessageFieldError extends FluentParseError {
  /// Creates the error for the incomplete message [entryId].
  const ExpectedMessageFieldError(this.entryId, this.offset);
  @override
  final String code = 'E0005';

  /// The id of the message missing both value and attributes.
  final String entryId;
  @override
  final int offset;

  @override
  String get message =>
      'Expected message "$entryId" to have a value or attributes';
}

/// E0006 — a term needs a value.
final class ExpectedTermFieldError extends FluentParseError {
  /// Creates the error for the value-less term [entryId].
  const ExpectedTermFieldError(this.entryId, this.offset);
  @override
  final String code = 'E0006';

  /// The id of the term missing its value.
  final String entryId;
  @override
  final int offset;

  @override
  String get message => 'Expected term "-$entryId" to have a value';
}

/// A spec error raised mid-production with its own code.
final class CallbackParseError extends FluentParseError {
  /// Creates the error with its spec [code], [message], and [offset].
  const CallbackParseError(this.code, this.message, this.offset);
  @override
  final String code;
  @override
  final String message;
  @override
  final int offset;
}

/// E0025 — a backslash escape the spec doesn't define.
final class UnknownEscapeSequenceError extends FluentParseError {
  /// Creates the error for the unknown [sequence] at [offset].
  const UnknownEscapeSequenceError(this.sequence, this.offset);
  @override
  final String code = 'E0025';

  /// The escape sequence as written (e.g. `\\q`).
  final String sequence;
  @override
  final int offset;

  @override
  String get message => 'Unknown escape sequence: $sequence';
}

/// E0026 — a malformed `\\uXXXX` / `\\UXXXXXX` escape.
final class InvalidUnicodeEscapeSequenceError extends FluentParseError {
  /// Creates the error for the invalid [sequence] at [offset].
  const InvalidUnicodeEscapeSequenceError(this.sequence, this.offset);
  @override
  final String code = 'E0026';

  /// The unicode escape as written.
  final String sequence;
  @override
  final int offset;

  @override
  String get message => 'Invalid Unicode escape sequence: $sequence';
}

/// E0020 — a string literal ran to end of line unterminated.
final class UnterminatedStringError extends FluentParseError {
  /// Creates the error at [offset].
  const UnterminatedStringError(this.offset);
  @override
  final String code = 'E0020';
  @override
  final int offset;

  @override
  String get message => 'Unterminated string expression';
}

/// E0027 — a `}` with no matching `{`.
final class UnbalancedClosingBraceError extends FluentParseError {
  /// Creates the error at [offset].
  const UnbalancedClosingBraceError(this.offset);
  @override
  final String code = 'E0027';
  @override
  final int offset;

  @override
  String get message => 'Unbalanced closing brace in placeable';
}
