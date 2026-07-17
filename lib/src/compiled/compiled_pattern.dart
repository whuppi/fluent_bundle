import 'package:fluent_bundle/src/compiled/compiled_expression.dart';
import 'package:meta/meta.dart';

/// A compiled pattern. Either a plain string (when there are no
/// placeables) or a list of elements to evaluate at format time.
@immutable
sealed class CompiledPattern {
  const CompiledPattern();
}

/// A pattern with no placeables — pure literal text.
///
/// The resolver short-circuits this to the contained string without
/// allocating any element list.
@immutable
final class CompiledStringPattern extends CompiledPattern {
  /// Wraps the pre-resolved text [value].
  const CompiledStringPattern(this.value);

  /// The final text — no placeables, nothing left to resolve.
  final String value;
}

/// A pattern that interleaves literal text with [CompiledExpression]
/// placeables.
@immutable
final class CompiledComplexPattern extends CompiledPattern {
  /// Wraps the pattern's [elements].
  const CompiledComplexPattern(this.elements);

  /// Text runs and placeables, in source order.
  final List<CompiledElement> elements;
}

/// One piece of an [CompiledComplexPattern].
@immutable
sealed class CompiledElement {
  const CompiledElement();
}

/// A literal text run.
@immutable
final class CompiledTextElement extends CompiledElement {
  /// Wraps the literal text [value].
  const CompiledTextElement(this.value);

  /// The text run exactly as it renders.
  final String value;
}

/// A placeable element — its [expression] is evaluated at format time and
/// the result substituted into the rendered pattern.
@immutable
final class CompiledPlaceable extends CompiledElement {
  /// Wraps the placeable's [expression].
  const CompiledPlaceable(this.expression);

  /// The expression the resolver evaluates for this `{ … }` slot.
  final CompiledExpression expression;
}
