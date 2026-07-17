part of 'ast.dart';

/// A position in the source text. Inclusive `start`, exclusive `end`.
///
/// Only present on a node when the parser was constructed with span
/// tracking enabled.
@immutable
final class Span {
  /// Creates the half-open range [start]..[end].
  const Span(this.start, this.end);

  /// Byte offset of the first character.
  final int start;

  /// Byte offset one past the last character.
  final int end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Span && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Span($start, $end)';
}

/// Base type for every Fluent Syntax 1.0 AST node.
@immutable
abstract class FluentNode {
  /// Base constructor for the sealed node family.
  const FluentNode();

  /// Structural equality.
  ///
  /// When [ignoreSpans] is true (the default), two ASTs from differently-
  /// positioned sources compare equal as long as their structure matches —
  /// useful for testing parser output against expected shapes regardless
  /// of whitespace placement. Set false for a strict, position-aware
  /// comparison that requires every [Span] to match.
  bool equals(FluentNode other, {bool ignoreSpans = true});

  /// Deep clone of this node.
  FluentNode clone();
}

/// Compare two [Span]s under the [ignoreSpans] flag. Returns true when
/// `ignoreSpans` is true OR the spans are structurally equal (both null
/// counts as equal). Implementations of [FluentNode.equals] call this on
/// every concrete node that carries a span.
bool _spansEqual(Span? a, Span? b, {required bool ignoreSpans}) {
  if (ignoreSpans) return true;
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a == b;
}

/// A node that may carry source-position information.
///
/// Most concrete AST nodes extend this. Spans are only attached when the
/// parser is configured to track them (via `withSpans: true`).
abstract class SyntaxNode extends FluentNode {
  /// Base constructor for the sealed syntax-node family.
  const SyntaxNode();

  /// Source range this node covers; null when spans were off.
  Span? get span;
}
