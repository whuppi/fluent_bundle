// Serialize a parsed [Resource] AST into the canonical Fluent JSON
// shape used by Mozilla's compliance fixtures. The shape matches
// fluent-rs and fluent.js so byte-equivalent comparison against vendored
// fixtures is meaningful.
//
// This file is test-only — it lives under `test/_corpus/` because it
// only exists to enable corpus testing.

import 'package:fluent_bundle/syntax.dart';

/// Canonical-shape JSON for a parsed [Resource]. Returns a `Map` shaped
/// exactly like the fluent-rs fixture JSON (`{"type": "Resource",
/// "body": [...]}`).
Map<String, Object?> resourceToJson(Resource r) {
  return {
    'type': 'Resource',
    'body': [for (final entry in r.body) _entryToJson(entry)],
  };
}

Map<String, Object?> _entryToJson(Entry entry) {
  return switch (entry) {
    Message() => _messageToJson(entry),
    Term() => _termToJson(entry),
    Comment() => _commentToJson(entry),
    Junk() => _junkToJson(entry),
  };
}

Map<String, Object?> _messageToJson(Message m) {
  return {
    'type': 'Message',
    'id': _identifierToJson(m.id),
    'value': m.value == null ? null : _patternToJson(m.value!),
    'attributes': [for (final a in m.attributes) _attributeToJson(a)],
    'comment': m.comment == null ? null : _commentToJson(m.comment!),
  };
}

Map<String, Object?> _termToJson(Term t) {
  return {
    'type': 'Term',
    'id': _identifierToJson(t.id),
    'value': _patternToJson(t.value),
    'attributes': [for (final a in t.attributes) _attributeToJson(a)],
    'comment': t.comment == null ? null : _commentToJson(t.comment!),
  };
}

Map<String, Object?> _commentToJson(Comment c) {
  // Fluent's three comment levels serialize to three different `type`
  // tags in the canonical JSON, NOT a `level` field on a single type.
  final type = switch (c.level) {
    CommentLevel.regular => 'Comment',
    CommentLevel.group => 'GroupComment',
    CommentLevel.resource => 'ResourceComment',
  };
  return {'type': type, 'content': c.content};
}

Map<String, Object?> _junkToJson(Junk j) {
  // `annotations` is part of the spec shape; we don't yet emit
  // structured annotations on Junk (the fixtures in the corpus all have
  // empty annotation arrays anyway, so this matches them today).
  return {
    'type': 'Junk',
    'annotations': const <Map<String, Object?>>[],
    'content': j.content,
  };
}

Map<String, Object?> _attributeToJson(Attribute a) {
  return {
    'type': 'Attribute',
    'id': _identifierToJson(a.id),
    'value': _patternToJson(a.value),
  };
}

Map<String, Object?> _identifierToJson(Identifier id) {
  return {'type': 'Identifier', 'name': id.name};
}

Map<String, Object?> _patternToJson(Pattern p) {
  return {
    'type': 'Pattern',
    'elements': [for (final e in p.elements) _patternElementToJson(e)],
  };
}

Map<String, Object?> _patternElementToJson(PatternElement e) {
  return switch (e) {
    TextElement() => {'type': 'TextElement', 'value': e.value},
    Placeable() => {
      'type': 'Placeable',
      'expression': _expressionToJson(e.expression),
    },
  };
}

Map<String, Object?> _expressionToJson(Expression expr) {
  return switch (expr) {
    StringLiteralExpression() => _stringLiteralToJson(expr.literal),
    NumberLiteralExpression() => _numberLiteralToJson(expr.literal),
    VariableReference() => {
      'type': 'VariableReference',
      'id': _identifierToJson(expr.id),
    },
    MessageReference() => {
      'type': 'MessageReference',
      'id': _identifierToJson(expr.id),
      'attribute':
          expr.attribute == null ? null : _identifierToJson(expr.attribute!),
    },
    TermReference() => {
      'type': 'TermReference',
      'id': _identifierToJson(expr.id),
      'attribute':
          expr.attribute == null ? null : _identifierToJson(expr.attribute!),
      'arguments':
          expr.arguments == null ? null : _callArgumentsToJson(expr.arguments!),
    },
    FunctionReference() => {
      'type': 'FunctionReference',
      'id': _identifierToJson(expr.id),
      'arguments': _callArgumentsToJson(expr.arguments),
    },
    // A Placeable inside an Expression slot is a nested placeable —
    // `{ {"x"} }`. Serialize with the same shape used at the pattern
    // level: `{"type": "Placeable", "expression": ...}`. The runtime
    // nesting is transparent; the JSON shape preserves it because the
    // canonical fixtures expect to see the wrapping in the parsed AST.
    Placeable() => {
      'type': 'Placeable',
      'expression': _expressionToJson(expr.expression),
    },
    SelectExpression() => {
      'type': 'SelectExpression',
      'selector': _expressionToJson(expr.selector),
      'variants': [for (final v in expr.variants) _variantToJson(v)],
    },
  };
}

Map<String, Object?> _callArgumentsToJson(CallArguments args) {
  return {
    'type': 'CallArguments',
    'positional': [for (final p in args.positional) _expressionToJson(p)],
    'named': [for (final n in args.named) _namedArgumentToJson(n)],
  };
}

Map<String, Object?> _namedArgumentToJson(NamedArgument n) {
  return {
    'type': 'NamedArgument',
    'name': _identifierToJson(n.name),
    'value': _literalToJson(n.value),
  };
}

Map<String, Object?> _literalToJson(Literal lit) {
  return switch (lit) {
    StringLiteral() => _stringLiteralToJson(lit),
    NumberLiteral() => _numberLiteralToJson(lit),
  };
}

Map<String, Object?> _stringLiteralToJson(StringLiteral s) {
  // fluent-rs writes `value` first, `type` last. Order doesn't matter
  // for structural comparison; matched here for readability.
  return {'value': s.value, 'type': 'StringLiteral'};
}

Map<String, Object?> _numberLiteralToJson(NumberLiteral n) {
  return {'value': n.value, 'type': 'NumberLiteral'};
}

Map<String, Object?> _variantToJson(Variant v) {
  return {
    'type': 'Variant',
    'key': _variantKeyToJson(v.key),
    'value': _patternToJson(v.value),
    'default': v.isDefault,
  };
}

Map<String, Object?> _variantKeyToJson(VariantKey key) {
  return switch (key) {
    IdentifierKey() => _identifierToJson(key.id),
    NumberLiteralKey() => _numberLiteralToJson(key.value),
  };
}
