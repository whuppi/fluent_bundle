part of 'ast.dart';

/// Anything that can appear at the top level of a Resource.
sealed class Entry extends SyntaxNode {
  const Entry();

  @override
  Entry clone();
}

/// A regular Fluent message: `id = value`, optionally with attributes
/// and a leading comment.
///
///     hello = Hello, World!
///     greet = Hi, { $name }
///         .label = Greeting
///         .accesskey = G
final class Message extends Entry {
  /// Bundles the message's [id], optional [value], [attributes],
  /// and attached [comment].
  const Message({
    required this.id,
    this.value,
    this.attributes = const [],
    this.comment,
    this.span,
  });

  /// The message id.
  final Identifier id;

  /// The value pattern; null for attribute-only messages.
  final Pattern? value;

  /// The message's attributes, in source order.
  final List<Attribute> attributes;

  /// The `#` comment directly above the message, when present.
  final Comment? comment;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! Message) return false;
    if (!id.equals(other.id, ignoreSpans: ignoreSpans)) return false;
    if ((value == null) != (other.value == null)) return false;
    if (value != null &&
        !value!.equals(other.value!, ignoreSpans: ignoreSpans)) {
      return false;
    }
    if (attributes.length != other.attributes.length) return false;
    for (var i = 0; i < attributes.length; i++) {
      if (!attributes[i].equals(
        other.attributes[i],
        ignoreSpans: ignoreSpans,
      )) {
        return false;
      }
    }
    if ((comment == null) != (other.comment == null)) return false;
    if (comment != null &&
        !comment!.equals(other.comment!, ignoreSpans: ignoreSpans)) {
      return false;
    }
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  Message clone() => Message(
    id: id.clone(),
    value: value?.clone(),
    attributes: [for (final a in attributes) a.clone()],
    comment: comment?.clone(),
    span: span,
  );

  @override
  String toString() => 'Message(${id.name}, ${attributes.length} attrs)';
}

/// A term: `-id = value`, only callable from other patterns via `{ -id }`.
/// Cannot be displayed directly to the user.
final class Term extends Entry {
  /// Bundles the term's [id], [value], [attributes], and attached
  /// [comment].
  const Term({
    required this.id,
    required this.value,
    this.attributes = const [],
    this.comment,
    this.span,
  });

  /// The term id without the leading `-`.
  final Identifier id;

  /// The value pattern (terms always have one).
  final Pattern value;

  /// The term's attributes, in source order.
  final List<Attribute> attributes;

  /// The `#` comment directly above the term, when present.
  final Comment? comment;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! Term) return false;
    if (!id.equals(other.id, ignoreSpans: ignoreSpans)) return false;
    if (!value.equals(other.value, ignoreSpans: ignoreSpans)) return false;
    if (attributes.length != other.attributes.length) return false;
    for (var i = 0; i < attributes.length; i++) {
      if (!attributes[i].equals(
        other.attributes[i],
        ignoreSpans: ignoreSpans,
      )) {
        return false;
      }
    }
    if ((comment == null) != (other.comment == null)) return false;
    if (comment != null &&
        !comment!.equals(other.comment!, ignoreSpans: ignoreSpans)) {
      return false;
    }
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  Term clone() => Term(
    id: id.clone(),
    value: value.clone(),
    attributes: [for (final a in attributes) a.clone()],
    comment: comment?.clone(),
    span: span,
  );

  @override
  String toString() => 'Term(-${id.name}, ${attributes.length} attrs)';
}

/// `.label = ...` attached to a [Message] or [Term].
final class Attribute extends SyntaxNode {
  /// Pairs the attribute [id] with its [value] pattern.
  const Attribute({required this.id, required this.value, this.span});

  /// The attribute name (after the `.`).
  final Identifier id;

  /// The pattern this attribute renders.
  final Pattern value;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! Attribute) return false;
    if (!id.equals(other.id, ignoreSpans: ignoreSpans)) return false;
    if (!value.equals(other.value, ignoreSpans: ignoreSpans)) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  Attribute clone() =>
      Attribute(id: id.clone(), value: value.clone(), span: span);

  @override
  String toString() => 'Attribute(.${id.name})';
}

/// A comment line in the source. Three levels:
///
///     # regular
///     ## group
///     ### resource
///
/// Standalone comments are top-level [Entry]s. Comments attached to a
/// [Message] / [Term] live on that node's `comment` field instead.
final class Comment extends Entry {
  /// Bundles the comment's [level] and [content].
  const Comment({required this.level, required this.content, this.span});

  /// How many `#` marks introduced the comment.
  final CommentLevel level;

  /// The comment text without the `#` markers.
  final String content;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! Comment) return false;
    if (other.level != level || other.content != content) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  Comment clone() => Comment(level: level, content: content, span: span);

  @override
  String toString() => 'Comment($level, ${content.length} chars)';
}

/// How many `#` marks introduced a comment.
enum CommentLevel {
  /// `#` — attaches to the following message or term.
  regular,

  /// `##` — a standalone section heading.
  group,

  /// `###` — a standalone file-level comment.
  resource,
}

/// Source text that failed to parse as an [Entry] but was preserved so
/// the surrounding entries can still load.
final class Junk extends Entry {
  /// Wraps the unparseable [content].
  const Junk({required this.content, this.span});

  /// The source stretch the parser skipped.
  final String content;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! Junk) return false;
    if (other.content != content) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  Junk clone() => Junk(content: content, span: span);

  @override
  String toString() => 'Junk(${content.length} chars)';
}
