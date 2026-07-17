part of 'ast.dart';

/// A pattern: the value of a Message, Term, or Attribute.
///
/// A pattern is a list of elements — runs of literal text alternated with
/// `{ ... }` placeables (expressions to substitute at format time).
final class Pattern extends SyntaxNode {
  /// Wraps the pattern's [elements].
  const Pattern(this.elements, {this.span});

  /// Text runs and placeables, in source order.
  final List<PatternElement> elements;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! Pattern) return false;
    if (other.elements.length != elements.length) return false;
    for (var i = 0; i < elements.length; i++) {
      if (!elements[i].equals(other.elements[i], ignoreSpans: ignoreSpans)) {
        return false;
      }
    }
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  Pattern clone() => Pattern([for (final e in elements) e.clone()], span: span);

  @override
  String toString() => 'Pattern(${elements.length} elements)';
}

/// One piece of a [Pattern]: either a literal text run, or a `{ ... }`
/// placeable.
sealed class PatternElement extends SyntaxNode {
  const PatternElement();

  @override
  PatternElement clone();
}

/// A literal text run inside a pattern.
final class TextElement extends PatternElement {
  /// Wraps the literal text [value].
  const TextElement(this.value, {this.span});

  /// The text run with multiline indentation already stripped.
  final String value;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! TextElement) return false;
    if (other.value != value) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  TextElement clone() => TextElement(value, span: span);

  @override
  String toString() => 'TextElement(${value.length} chars)';
}

/// A `{ ... }` placeable. Wraps an [Expression] and appears in two
/// positions in the AST:
///
///   - As an element inside a [Pattern] (the common case — that's how
///     placeables interleave with pattern text).
///   - As an [InlineExpression] inside ANOTHER placeable's expression
///     slot — i.e. nested placeables `{ {"x"} }`.
///
/// The dual role is required by the Fluent Syntax 1.0 spec. It only
/// works because every AST file is part of one Dart library, so the
/// sealed `PatternElement` and sealed `InlineExpression` boundaries can
/// both legally cover this class.
final class Placeable extends PatternElement implements InlineExpression {
  /// Wraps the placeable's [expression].
  const Placeable(this.expression, {this.span});

  /// The expression inside the `{ … }`.
  final Expression expression;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! Placeable) return false;
    if (!expression.equals(other.expression, ignoreSpans: ignoreSpans)) {
      return false;
    }
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  /// Deep-copies this node.
  Placeable clone() => Placeable(expression.clone(), span: span);

  @override
  String toString() => 'Placeable(${expression.runtimeType})';
}
