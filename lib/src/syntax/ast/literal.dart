part of 'ast.dart';

/// An identifier — used for message names, term names (without leading dash),
/// attribute names, variant keys, function names, and variable names.
///
/// Spec: `[a-zA-Z][a-zA-Z0-9_-]*`
final class Identifier extends SyntaxNode {
  /// Wraps the identifier [name].
  const Identifier(this.name, {this.span});

  /// The identifier text.
  final String name;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! Identifier) return false;
    if (other.name != name) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  Identifier clone() => Identifier(name, span: span);

  @override
  String toString() => 'Identifier($name)';
}

/// A literal value inside a placeable: string or number.
sealed class Literal extends SyntaxNode {
  const Literal();

  @override
  Literal clone();
}

/// A double-quoted string literal: `{ "Hello" }`.
///
/// `value` holds the **raw, escape-preserved** source content. Escape
/// sequences (`\\`, `\"`, `\uXXXX`, `\UXXXXXX`) appear as their literal
/// characters. The runtime resolver decodes them via
/// `unescapeFluentString` when the value is rendered into a pattern.
final class StringLiteral extends Literal {
  /// Wraps the raw, escape-preserved [value].
  const StringLiteral(this.value, {this.span});

  /// Raw string content between the quotes; escapes preserved.
  final String value;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! StringLiteral) return false;
    if (other.value != value) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  StringLiteral clone() => StringLiteral(value, span: span);

  @override
  String toString() => 'StringLiteral("$value")';
}

/// A numeric literal: `{ 5 }`, `{ 3.14 }`, `{ -7 }`.
///
/// Stored as the original source text (`value`) plus the digit count after
/// the decimal point (`precision`). Keeping the source string avoids
/// floating-point rounding during parse and lets formatters honor the
/// author's chosen precision.
final class NumberLiteral extends Literal {
  /// Wraps the source [value] and its fraction [precision].
  const NumberLiteral(this.value, this.precision, {this.span});

  /// The number exactly as written in the FTL source.
  final String value;

  /// Fraction digits written in the source (`3.14` → 2).
  final int precision;
  @override
  final Span? span;

  /// Numeric value as a Dart `double` (or `int`, callers can downcast).
  double toDouble() => double.parse(value);

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! NumberLiteral) return false;
    if (other.value != value || other.precision != precision) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  NumberLiteral clone() => NumberLiteral(value, precision, span: span);

  @override
  String toString() => 'NumberLiteral($value, precision=$precision)';
}
