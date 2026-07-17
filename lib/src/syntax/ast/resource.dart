part of 'ast.dart';

/// A complete parsed `.ftl` file.
///
/// Holds every entry from the source: messages, terms, standalone comments,
/// and any junk (entries that failed to parse). Keeping junk preserves
/// recoverability — one bad entry doesn't break the whole resource.
final class Resource extends SyntaxNode {
  /// Wraps the parsed [body].
  const Resource(this.body, {this.span});

  /// Every top-level entry — messages, terms, comments, junk — in
  /// source order.
  final List<Entry> body;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! Resource) return false;
    if (other.body.length != body.length) return false;
    for (var i = 0; i < body.length; i++) {
      if (!body[i].equals(other.body[i], ignoreSpans: ignoreSpans)) {
        return false;
      }
    }
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  Resource clone() => Resource([for (final e in body) e.clone()], span: span);

  @override
  String toString() => 'Resource(${body.length} entries)';
}
