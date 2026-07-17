part of 'ast.dart';

/// Anything that can appear inside a `{ ... }` placeable.
sealed class Expression extends SyntaxNode {
  const Expression();

  @override
  Expression clone();
}

/// An expression that can sit alone in a pattern or as a selector input.
///
/// Distinguishes from [SelectExpression], which must be the only element
/// of its placeable's pattern. [InlineExpression] is also the type that
/// can be NESTED inside another placeable — `{ {"x"} }` — because
/// [Placeable] implements this interface.
sealed class InlineExpression extends Expression {
  const InlineExpression();

  @override
  InlineExpression clone();
}

/// A double-quoted string literal used as a placeable expression.
final class StringLiteralExpression extends InlineExpression {
  /// Wraps the [literal].
  const StringLiteralExpression(this.literal, {this.span});

  /// The wrapped string literal.
  final StringLiteral literal;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! StringLiteralExpression) return false;
    if (!literal.equals(other.literal, ignoreSpans: ignoreSpans)) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  StringLiteralExpression clone() =>
      StringLiteralExpression(literal.clone(), span: span);

  @override
  String toString() => 'StringLiteralExpression("${literal.value}")';
}

/// A numeric literal used as a placeable expression.
final class NumberLiteralExpression extends InlineExpression {
  /// Wraps the [literal].
  const NumberLiteralExpression(this.literal, {this.span});

  /// The wrapped number literal.
  final NumberLiteral literal;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! NumberLiteralExpression) return false;
    if (!literal.equals(other.literal, ignoreSpans: ignoreSpans)) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  NumberLiteralExpression clone() =>
      NumberLiteralExpression(literal.clone(), span: span);

  @override
  String toString() => 'NumberLiteralExpression(${literal.value})';
}

/// A reference to an externally-supplied argument: `$name`.
final class VariableReference extends InlineExpression {
  /// References the variable named by [id].
  const VariableReference(this.id, {this.span});

  /// The variable name without the leading `$`.
  final Identifier id;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! VariableReference) return false;
    if (!id.equals(other.id, ignoreSpans: ignoreSpans)) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  VariableReference clone() => VariableReference(id.clone(), span: span);

  @override
  String toString() => 'VariableReference(\$${id.name})';
}

/// A reference to another message: `name` or `name.attr`.
final class MessageReference extends InlineExpression {
  /// References the message [id] (+ optional [attribute]).
  const MessageReference(this.id, {this.attribute, this.span});

  /// The referenced message's id.
  final Identifier id;

  /// The referenced attribute, for `{ msg.attr }` forms.
  final Identifier? attribute;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! MessageReference) return false;
    if (!id.equals(other.id, ignoreSpans: ignoreSpans)) return false;
    if ((attribute == null) != (other.attribute == null)) return false;
    if (attribute != null &&
        !attribute!.equals(other.attribute!, ignoreSpans: ignoreSpans)) {
      return false;
    }
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  MessageReference clone() =>
      MessageReference(id.clone(), attribute: attribute?.clone(), span: span);

  @override
  String toString() =>
      attribute == null
          ? 'MessageReference(${id.name})'
          : 'MessageReference(${id.name}.${attribute!.name})';
}

/// A reference to a term: `-name`, `-name.attr`, or `-name(arg, key: value)`.
final class TermReference extends InlineExpression {
  /// References the term [id] (+ optional [attribute] and
  /// call [arguments]).
  const TermReference(this.id, {this.attribute, this.arguments, this.span});

  /// The referenced term's id without the leading `-`.
  final Identifier id;

  /// The referenced attribute, for `{ -term.attr }` forms.
  final Identifier? attribute;

  /// Call arguments; named ones become the term's variable scope.
  final CallArguments? arguments;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! TermReference) return false;
    if (!id.equals(other.id, ignoreSpans: ignoreSpans)) return false;
    if ((attribute == null) != (other.attribute == null)) return false;
    if (attribute != null &&
        !attribute!.equals(other.attribute!, ignoreSpans: ignoreSpans)) {
      return false;
    }
    if ((arguments == null) != (other.arguments == null)) return false;
    if (arguments != null &&
        !arguments!.equals(other.arguments!, ignoreSpans: ignoreSpans)) {
      return false;
    }
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  TermReference clone() => TermReference(
    id.clone(),
    attribute: attribute?.clone(),
    arguments: arguments?.clone(),
    span: span,
  );

  @override
  String toString() {
    final base =
        attribute == null ? '-${id.name}' : '-${id.name}.${attribute!.name}';
    return 'TermReference($base${arguments == null ? '' : '(...)'})';
  }
}

/// A call to a built-in function: `NUMBER($n, style: "currency")`.
///
/// Function names match `[A-Z][A-Z0-9_-]*`.
final class FunctionReference extends InlineExpression {
  /// Calls the function [id] with [arguments].
  const FunctionReference(this.id, this.arguments, {this.span});

  /// The function name as written (`NUMBER`, `DATETIME`, custom).
  final Identifier id;

  /// The call's positional + named arguments.
  final CallArguments arguments;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! FunctionReference) return false;
    if (!id.equals(other.id, ignoreSpans: ignoreSpans)) return false;
    if (!arguments.equals(other.arguments, ignoreSpans: ignoreSpans)) {
      return false;
    }
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  FunctionReference clone() =>
      FunctionReference(id.clone(), arguments.clone(), span: span);

  @override
  String toString() => 'FunctionReference(${id.name}(...))';
}

/// Positional and named arguments to a `TermReference` or `FunctionReference`.
///
/// Positional arguments must precede all named arguments at parse time;
/// the order of named arguments is preserved as written.
final class CallArguments extends SyntaxNode {
  /// Bundles [positional] and [named] argument lists.
  const CallArguments({
    this.positional = const [],
    this.named = const [],
    this.span,
  });

  /// Positional arguments, in call order.
  final List<InlineExpression> positional;

  /// Named arguments, in call order. Values are literal-only per
  /// the Fluent EBNF.
  final List<NamedArgument> named;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! CallArguments) return false;
    if (positional.length != other.positional.length) return false;
    for (var i = 0; i < positional.length; i++) {
      if (!positional[i].equals(
        other.positional[i],
        ignoreSpans: ignoreSpans,
      )) {
        return false;
      }
    }
    if (named.length != other.named.length) return false;
    for (var i = 0; i < named.length; i++) {
      if (!named[i].equals(other.named[i], ignoreSpans: ignoreSpans)) {
        return false;
      }
    }
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  CallArguments clone() => CallArguments(
    positional: positional.map((e) => e.clone()).toList(),
    named: named.map((n) => n.clone()).toList(),
    span: span,
  );
}

/// A pattern selection: chooses one of several `[key] pattern` variants
/// based on the value of [selector].
///
/// Exactly one variant must be marked as the default (chosen when no
/// other variant matches at runtime). Per spec, [SelectExpression] is
/// itself an [Expression] but NOT an [InlineExpression] — it cannot be
/// nested inside another expression position; it can only appear as
/// the sole expression of a placeable.
final class SelectExpression extends Expression {
  /// Selects among [variants] by the [selector]'s value.
  const SelectExpression(this.selector, this.variants, {this.span});

  /// The expression whose value picks a variant.
  final InlineExpression selector;

  /// Every variant, in source order; exactly one is the default.
  final List<Variant> variants;
  @override
  final Span? span;

  /// The default variant. Asserts that exactly one is marked default.
  Variant get defaultVariant => variants.firstWhere((v) => v.isDefault);

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! SelectExpression) return false;
    if (!selector.equals(other.selector, ignoreSpans: ignoreSpans)) {
      return false;
    }
    if (variants.length != other.variants.length) return false;
    for (var i = 0; i < variants.length; i++) {
      if (!variants[i].equals(other.variants[i], ignoreSpans: ignoreSpans)) {
        return false;
      }
    }
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  SelectExpression clone() => SelectExpression(
    selector.clone(),
    variants.map((v) => v.clone()).toList(),
    span: span,
  );

  @override
  String toString() => 'SelectExpression(${variants.length} variants)';
}

/// One arm of a [SelectExpression]: a `[key] pattern` pair.
///
/// `isDefault` is true for the variant marked with `*[key]`. Exactly one
/// variant per [SelectExpression] is the default.
final class Variant extends SyntaxNode {
  /// Bundles one variant's [key], [value] pattern, and default flag.
  const Variant({
    required this.key,
    required this.value,
    required this.isDefault,
    this.span,
  });

  /// The variant key (`[one]`, `[windows]`, `[3]`).
  final VariantKey key;

  /// The pattern this variant renders.
  final Pattern value;

  /// True for the `*`-marked default variant.
  final bool isDefault;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! Variant) return false;
    if (other.isDefault != isDefault) return false;
    if (!key.equals(other.key, ignoreSpans: ignoreSpans)) return false;
    if (!value.equals(other.value, ignoreSpans: ignoreSpans)) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  Variant clone() => Variant(
    key: key.clone(),
    value: value.clone(),
    isDefault: isDefault,
    span: span,
  );

  @override
  String toString() =>
      isDefault ? 'Variant(*$key → ...)' : 'Variant($key → ...)';
}

/// A variant's match key: an [Identifier] (CLDR plural category like
/// `one` / `other`, or any free-form name) or a [NumberLiteral] (numeric
/// match).
sealed class VariantKey extends SyntaxNode {
  const VariantKey();

  @override
  VariantKey clone();
}

/// A variant key matching by identifier (e.g. `[one]`, `[other]`,
/// `[masculine]`).
final class IdentifierKey extends VariantKey {
  /// Wraps the identifier-shaped key [id].
  const IdentifierKey(this.id, {this.span});

  /// The key as an identifier (plural category or literal string).
  final Identifier id;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! IdentifierKey) return false;
    if (!id.equals(other.id, ignoreSpans: ignoreSpans)) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  IdentifierKey clone() => IdentifierKey(id.clone(), span: span);

  @override
  String toString() => id.name;
}

/// A variant key matching by number literal (e.g. `[1]`, `[3.14]`).
final class NumberLiteralKey extends VariantKey {
  /// Wraps the number-literal key [value].
  const NumberLiteralKey(this.value, {this.span});

  /// The key as a number literal.
  final NumberLiteral value;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! NumberLiteralKey) return false;
    if (!value.equals(other.value, ignoreSpans: ignoreSpans)) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  NumberLiteralKey clone() => NumberLiteralKey(value.clone(), span: span);

  @override
  String toString() => value.value;
}

/// A `name: value` argument inside `CallArguments`.
///
/// `value` is restricted to literals at parse time.
final class NamedArgument extends SyntaxNode {
  /// Pairs the argument [name] with its literal [value].
  const NamedArgument(this.name, this.value, {this.span});

  /// The argument name.
  final Identifier name;

  /// The argument value — literal-only per the Fluent EBNF.
  final Literal value;
  @override
  final Span? span;

  @override
  bool equals(FluentNode other, {bool ignoreSpans = true}) {
    if (other is! NamedArgument) return false;
    if (!name.equals(other.name, ignoreSpans: ignoreSpans)) return false;
    if (!value.equals(other.value, ignoreSpans: ignoreSpans)) return false;
    return _spansEqual(span, other.span, ignoreSpans: ignoreSpans);
  }

  @override
  NamedArgument clone() =>
      NamedArgument(name.clone(), value.clone(), span: span);
}
