import 'package:fluent_bundle/src/compiled/compiled_pattern.dart';
import 'package:meta/meta.dart';

/// Compact runtime form of any expression that can appear in a placeable.
@immutable
sealed class CompiledExpression {
  const CompiledExpression();
}

/// A `"..."` string literal — the value is the already-unescaped string.
@immutable
final class CompiledStringLiteral extends CompiledExpression {
  /// Wraps the raw, escape-preserved [value].
  const CompiledStringLiteral(this.value);

  /// Raw string content; unescaped at resolution time.
  final String value;
}

/// A numeric literal — `value` is the source representation (e.g. `'3.14'`).
/// `precision` is the number of digits after the decimal point.
@immutable
final class CompiledNumberLiteral extends CompiledExpression {
  /// Wraps the source [value] and its fraction-digit [precision].
  const CompiledNumberLiteral(this.value, this.precision);

  /// The number exactly as written in the FTL source.
  final String value;

  /// Fraction digits written in the source (`3.14` → 2) — feeds the
  /// minimum-fraction-digits default.
  final int precision;
}

/// A reference to an externally-supplied argument: `$name`.
@immutable
final class CompiledVariableReference extends CompiledExpression {
  /// Wraps the referenced variable [name].
  const CompiledVariableReference(this.name);

  /// The variable name without the leading `$`.
  final String name;
}

/// A reference to another message: `name` or `name.attribute`.
@immutable
final class CompiledMessageReference extends CompiledExpression {
  /// Wraps the referenced message [name] (+ optional [attribute]).
  const CompiledMessageReference(this.name, {this.attribute});

  /// The referenced message id.
  final String name;

  /// The referenced attribute, for `{ msg.attr }` forms.
  final String? attribute;
}

/// A reference to a term: `-name`, `-name.attribute`, optionally with args.
@immutable
final class CompiledTermReference extends CompiledExpression {
  /// Wraps the referenced term [name] (+ optional [attribute] and
  /// call [arguments]).
  const CompiledTermReference(this.name, {this.attribute, this.arguments});

  /// The referenced term id without the leading `-`.
  final String name;

  /// The referenced attribute, for `{ -term.attr }` forms.
  final String? attribute;

  /// Call arguments; only the named ones affect resolution (they
  /// become the term's variable scope).
  final CompiledCallArguments? arguments;
}

/// A call to a built-in function: `NUMBER($n, style: "currency")`.
@immutable
final class CompiledFunctionReference extends CompiledExpression {
  /// Wraps the called function [name] and its [arguments].
  const CompiledFunctionReference(this.name, this.arguments);

  /// The function name as written (`NUMBER`, `DATETIME`, custom).
  final String name;

  /// Positional + named arguments of the call.
  final CompiledCallArguments arguments;
}

/// Positional and named arguments passed to a function or term.
///
/// Named values are restricted to literal forms — at compile time a
/// `CompiledNumberLiteral` or `CompiledStringLiteral` is the only thing accepted.
@immutable
final class CompiledCallArguments {
  /// Bundles [positional] and [named] argument lists.
  const CompiledCallArguments({
    this.positional = const [],
    this.named = const {},
  });

  /// Positional arguments, in call order.
  final List<CompiledExpression> positional;

  /// Named arguments by name.
  final Map<String, CompiledExpression> named;
}

/// A pattern selection: chooses one variant of [variants] based on the
/// resolved value of [selector].
///
/// `defaultIndex` is the position of the variant marked `*[key]` in the
/// source. The resolver falls back to that variant when no other variant
/// matches.
@immutable
final class CompiledSelectExpression extends CompiledExpression {
  /// Bundles the [selector], [variants], and the [defaultIndex].
  const CompiledSelectExpression({
    required this.selector,
    required this.variants,
    required this.defaultIndex,
  });

  /// The expression whose value picks a variant.
  final CompiledExpression selector;

  /// Every variant, in source order.
  final List<CompiledVariant> variants;

  /// Index into [variants] of the `*`-marked default.
  final int defaultIndex;
}

/// One arm of a [CompiledSelectExpression]: a `[key] pattern` pair.
///
/// At runtime the key is just another expression — specifically a literal:
/// either an [CompiledStringLiteral] (for `[one]`, `[masculine]`, …) or an
/// [CompiledNumberLiteral] (for `[0]`, `[42]`). The resolver evaluates the key
/// through the same path as any other expression so variant matching uses
/// a single unified comparison rule against the resolved selector value.
@immutable
final class CompiledVariant {
  /// Bundles one variant's key and pattern.
  const CompiledVariant({required this.key, required this.value});

  /// The key expression. Only [CompiledStringLiteral] and [CompiledNumberLiteral] are
  /// valid here; the parser rejects anything else with a Junk recovery.
  final CompiledExpression key;

  /// The pattern returned when this variant is selected.
  final CompiledPattern value;
}
