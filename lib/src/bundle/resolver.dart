import 'package:fluent_bundle/src/backend/plural_category.dart';
import 'package:fluent_bundle/src/bundle/fluent_function.dart';
import 'package:fluent_bundle/src/bundle/scope.dart';
import 'package:fluent_bundle/src/compiled/compiled_expression.dart';
import 'package:fluent_bundle/src/compiled/compiled_message.dart';
import 'package:fluent_bundle/src/compiled/compiled_pattern.dart';
import 'package:fluent_bundle/src/compiled/compiled_term.dart';
import 'package:fluent_bundle/src/errors/fluent_error.dart';
import 'package:fluent_bundle/src/syntax/unescape.dart';
import 'package:fluent_bundle/src/values/fluent_value.dart';

/// Unicode First Strong Isolate (U+2068). Opens a directional isolate
/// whose embedding direction is determined by the first strong
/// character INSIDE it, so a placeable's content can't bleed direction
/// into the surrounding pattern text.
const String _fsi = '\u2068';

/// Unicode Pop Directional Isolate (U+2069). Closes the most recent
/// directional isolate.
const String _pdi = '\u2069';

/// The resolver: writes a [CompiledPattern] under a given [Scope] into a
/// shared [StringBuffer] (the "writer").
///
/// Streaming through one buffer — instead of returning a string from
/// every recursion level — is what lets the cap-hit path preserve
/// every byte rendered up to the failure point. When the cap fires,
/// the loop short-circuits but the buffer keeps its accumulated text;
/// each outer placeable sees [Scope.dirty] and emits its source-form
/// fallback (`{lol1}`, `{$arg}`, …) so the user can see which slots
/// were skipped.
///
/// The shared writer also avoids the allocate-then-glue cost of
/// returning intermediate strings at every level. A pattern with N
/// nested message refs goes through one buffer, not N+1 buffers that
/// each get joined into the next.
class Resolver {
  /// Creates a resolver over the bundle's compiled messages and
  /// terms.
  Resolver({
    required this.lookupMessage,
    required this.lookupTerm,
    required this.lookupFunction,
  });

  /// Lookup of `name → CompiledMessage` for resolving message references.
  final CompiledMessage? Function(String name) lookupMessage;

  /// Lookup of `name → CompiledTerm` for resolving term references.
  final CompiledTerm? Function(String name) lookupTerm;

  /// Lookup of `name → FluentFunction` for resolving function calls.
  final FluentFunction? Function(String name) lookupFunction;

  /// Top-level entry point. Writes the rendered form of [pattern] into
  /// [out] under [scope]. Errors accumulate on `scope.errors`; the
  /// writer always carries a usable string when the call returns, even
  /// if the cap fired or a cycle was hit.
  ///
  /// When [pattern] is the entry node and self-cycles before producing
  /// any content, `{???}` is written as a generic placeholder — the
  /// bundle has no message id at this layer to surface in the
  /// fallback. (Inner cycles produced from `{ messageRef }` slots get
  /// the proper `{messageId}` form via `_resolveMessageRef`.)
  void resolvePattern(Scope scope, CompiledPattern pattern, StringBuffer out) {
    if (pattern is CompiledStringPattern) {
      final txfm = scope.transform;
      out.write(txfm == null ? pattern.value : txfm(pattern.value));
      return;
    }

    if (scope.traveled.contains(pattern)) {
      scope.errors.add(const FluentCyclicReferenceError());
      out.write('{???}');
      return;
    }

    scope.traveled.add(pattern);
    try {
      final complex = pattern as CompiledComplexPattern;
      // A single-element pattern needs no bidi isolation — there is no
      // surrounding text whose direction the placeable's content could
      // leak into.
      final mayWrap = scope.useIsolating && complex.elements.length > 1;

      for (final element in complex.elements) {
        // Once the cap has fired, abandon the rest of this pattern
        // immediately — no more text runs, no more placeable resolves.
        // Whatever was already written stays in [out].
        if (scope.dirty) return;

        switch (element) {
          case CompiledTextElement():
            // Author-written pattern text passes through `Scope.transform`
            // (when set) before reaching the buffer — pseudo-localization
            // hook used for QA. Placeables, string literals, variable
            // values, and variant keys are NOT transformed; only the
            // raw text segments are.
            final txfm = scope.transform;
            out.write(txfm == null ? element.value : txfm(element.value));
          case CompiledPlaceable():
            if (!scope.countPlaceable()) {
              // Cap hit on THIS placeable. `dirty` is now set; abandon
              // without writing anything for this slot. The outer
              // pattern's [_writePlaceable] will see dirty after its
              // recursive call returns and append the source-form
              // fallback for whichever slot was holding us.
              return;
            }
            _writePlaceable(scope, out, element.expression, mayWrap);
        }
      }
    } finally {
      scope.traveled.remove(pattern);
    }
  }

  /// Resolve [expr] and write the result into [out]. Detects whether
  /// the recursion left the scope in a dirty state; if so, the slot's
  /// source-form fallback is written instead of the resolved text.
  void _writePlaceable(
    Scope scope,
    StringBuffer out,
    CompiledExpression expr,
    bool mayWrap,
  ) {
    // Isolate placeables EXCEPT message references, term references, and
    // string literals. This is fluent-rs (production Firefox) behavior —
    // those three resolve to author-controlled, direction-correct
    // content, so marks around them would be noise (FSI/PDI inside a
    // brand-name term breaks string matching and rendering). fluent.js
    // isolates ALL placeables; the two reference implementations
    // deliberately diverge here, and the vendored corpus keeps
    // fluent.js's cases as upstream-skipped fixtures. Do not "fix" this
    // to match them — that would diverge from production Fluent.
    final wrap = mayWrap && _shouldIsolate(expr);

    // For expressions that produce a value (variables, numbers,
    // strings, function calls, selects, references that resolve to a
    // FluentValue), evaluate to a FluentValue first, then render to
    // text. For message and term references that reach foreign
    // patterns, the inner [resolvePattern] call writes directly into
    // our buffer — no intermediate string.
    if (wrap) out.write(_fsi);
    _writeExpression(scope, expr, out);
    if (wrap) out.write(_pdi);

    if (scope.dirty) {
      // Cap fired during downstream resolution. Whatever the placeable
      // managed to render before going dirty is already in [out]; we
      // append the source-form fallback so the abandoned slot is
      // visible in the final output.
      out.write(_placeableFallback(expr));
    }
  }

  /// Render [expr] into [out]. Splits into "expressions whose result
  /// is a [FluentValue] that needs locale-aware rendering" (numbers,
  /// dates, variables, function calls, literals) and "expressions
  /// that recurse into another pattern" (message and term refs,
  /// select). The first kind goes through [_render]; the second kind
  /// recurses into [resolvePattern] writing straight to [out].
  void _writeExpression(
    Scope scope,
    CompiledExpression expr,
    StringBuffer out,
  ) {
    switch (expr) {
      case CompiledMessageReference():
        _writeMessageRef(scope, expr, out);
      case CompiledTermReference():
        _writeTermRef(scope, expr, out);
      case CompiledSelectExpression():
        _writeSelect(scope, expr, out);
      case CompiledStringLiteral() ||
          CompiledNumberLiteral() ||
          CompiledVariableReference() ||
          CompiledFunctionReference():
        // These resolve to a FluentValue we then render through the
        // bundle's locale-aware formatters.
        out.write(_render(scope, resolveExpression(scope, expr)));
    }
  }

  /// Resolve [expr] to a [FluentValue]. Used for the value-producing
  /// expression kinds — variables, numbers, strings, function calls.
  /// Reference-style expressions (message, term, select) write
  /// directly through [_writeExpression] and never round-trip through
  /// this method during placeable rendering; this path is reachable
  /// for nested expression evaluation (term named-arg values, function
  /// arguments, select selectors).
  FluentValue resolveExpression(Scope scope, CompiledExpression expr) {
    return switch (expr) {
      // String literals carry their raw, escape-preserved source
      // content — decode it to actual codepoints when materializing
      // the value.
      CompiledStringLiteral() => FluentString(unescapeFluentString(expr.value)),
      // Number-literal precision flows into the value's formatting opts
      // so `{ 3.14 }` formats with two fractional digits even after the
      // decimal value would round to fewer.
      CompiledNumberLiteral() => FluentNumber(
        num.parse(expr.value),
        FluentNumberOptions(minimumFractionDigits: expr.precision),
      ),
      CompiledVariableReference() => _resolveVariable(scope, expr),
      CompiledFunctionReference() => _resolveFunctionRef(scope, expr),
      CompiledMessageReference() => _resolveMessageRefAsValue(scope, expr),
      CompiledTermReference() => _resolveTermRefAsValue(scope, expr),
      CompiledSelectExpression() => _resolveSelectAsValue(scope, expr),
    };
  }

  // ── Streaming reference resolvers ─────────────────────────────────────

  /// Write the resolved form of `{ name }` / `{ name.attr }` into [out].
  /// On cycle, writes `{name}` / `{name.attr}` as the fallback.
  void _writeMessageRef(
    Scope scope,
    CompiledMessageReference expr,
    StringBuffer out,
  ) {
    final fullRef =
        expr.attribute == null ? expr.name : '${expr.name}.${expr.attribute}';
    final msg = lookupMessage(expr.name);
    if (msg == null) {
      scope.errors.add(FluentReferenceError(fullRef));
      out.write('{$fullRef}');
      return;
    }
    final pattern =
        expr.attribute == null ? msg.value : msg.attributes[expr.attribute];
    if (pattern == null) {
      scope.errors.add(FluentReferenceError(fullRef));
      out.write('{$fullRef}');
      return;
    }
    if (scope.traveled.contains(pattern)) {
      // Cycle origin: emit the source-form fallback at the entry-point
      // ref's name. This is what the user sees when `foo = { foo }` is
      // resolved — `{foo}` rather than some inner pattern preview.
      scope.errors.add(const FluentCyclicReferenceError());
      out.write('{$fullRef}');
      return;
    }
    resolvePattern(scope, pattern, out);
  }

  /// Write the resolved form of `{ -name }` / `{ -name.attr }` /
  /// `{ -name(args) }` into [out].
  void _writeTermRef(
    Scope scope,
    CompiledTermReference expr,
    StringBuffer out,
  ) {
    final fullRef =
        expr.attribute == null
            ? '-${expr.name}'
            : '-${expr.name}.${expr.attribute}';
    final term = lookupTerm(expr.name);
    if (term == null) {
      scope.errors.add(FluentReferenceError(fullRef));
      out.write('{$fullRef}');
      return;
    }
    final pattern =
        expr.attribute == null ? term.value : term.attributes[expr.attribute];
    if (pattern == null) {
      scope.errors.add(FluentReferenceError(fullRef));
      out.write('{$fullRef}');
      return;
    }

    // Push the term's named arguments as the new $variable scope. Term
    // bodies resolve their `$x` references from this frame ONLY —
    // caller args do not leak into the term.
    final frame = <String, FluentValue>{};
    if (expr.arguments != null) {
      expr.arguments!.named.forEach((key, valueExpr) {
        frame[key] = resolveExpression(scope, valueExpr);
      });
    }
    scope.pushTermFrame(frame);
    try {
      if (scope.traveled.contains(pattern)) {
        scope.errors.add(const FluentCyclicReferenceError());
        out.write('{$fullRef}');
        return;
      }
      resolvePattern(scope, pattern, out);
    } finally {
      scope.popTermFrame();
    }
  }

  /// Write the matching variant's body into [out].
  void _writeSelect(
    Scope scope,
    CompiledSelectExpression expr,
    StringBuffer out,
  ) {
    final selectorValue = resolveExpression(scope, expr.selector);
    for (final variant in expr.variants) {
      final keyValue = resolveExpression(scope, variant.key);
      if (_match(scope, selectorValue, keyValue)) {
        resolvePattern(scope, variant.value, out);
        return;
      }
    }
    resolvePattern(scope, expr.variants[expr.defaultIndex].value, out);
  }

  // ── Value-producing reference resolvers ───────────────────────────────

  /// Variant of [_writeMessageRef] that returns a [FluentValue]
  /// instead of streaming. Used when a message ref appears inside an
  /// expression slot whose result is consumed as a value (term
  /// arguments, function arguments, selector positions). The trip
  /// through a temporary buffer is unavoidable here — a value-typed
  /// consumer can't read partial bytes from the main writer.
  FluentValue _resolveMessageRefAsValue(
    Scope scope,
    CompiledMessageReference expr,
  ) {
    final tmp = StringBuffer();
    _writeMessageRef(scope, expr, tmp);
    return FluentString(tmp.toString());
  }

  /// Variant of [_writeTermRef] that returns a [FluentValue].
  FluentValue _resolveTermRefAsValue(Scope scope, CompiledTermReference expr) {
    final tmp = StringBuffer();
    _writeTermRef(scope, expr, tmp);
    return FluentString(tmp.toString());
  }

  /// Variant of [_writeSelect] that returns a [FluentValue].
  FluentValue _resolveSelectAsValue(
    Scope scope,
    CompiledSelectExpression expr,
  ) {
    final tmp = StringBuffer();
    _writeSelect(scope, expr, tmp);
    return FluentString(tmp.toString());
  }

  // ── Resolution helpers ───────────────────────────────────────────────

  FluentValue _resolveVariable(Scope scope, CompiledVariableReference expr) {
    final value = scope.lookupVariable(expr.name);
    if (value != null) return value;
    scope.errors.add(FluentReferenceError('\$${expr.name}'));
    return _none('\$${expr.name}');
  }

  FluentValue _resolveFunctionRef(Scope scope, CompiledFunctionReference expr) {
    // Two failure shapes:
    //   - Function NOT registered → wrapped fallback `{NAME()}`. The
    //     missing-reference render style: braces signal "this slot
    //     points at something that doesn't exist."
    //   - Function registered but threw / explicitly returned a bare
    //     `FluentNone` → bare source-form `NAME()`. The function
    //     itself owns that distinction by returning `FluentNone.bare`
    //     instead of `FluentNone(reason)`.
    final fnRef = '${expr.name}()';
    final fn = lookupFunction(expr.name);
    if (fn == null) {
      scope.errors.add(FluentReferenceError(fnRef));
      return FluentNone(fnRef);
    }
    final positional = <FluentValue>[];
    for (final arg in expr.arguments.positional) {
      positional.add(resolveExpression(scope, arg));
    }
    final named = <String, FluentValue>{};
    expr.arguments.named.forEach((key, valueExpr) {
      named[key] = resolveExpression(scope, valueExpr);
    });
    try {
      return fn(positional, named, scope.context);
    } catch (e) {
      scope.errors.add(FluentTypeError('${expr.name}: $e'));
      return FluentNone.bare(fnRef);
    }
  }

  /// Spec-shaped variant matching: a [selector] matches a [key] iff
  ///
  ///   1. both are strings and equal, OR
  ///   2. both are numbers and equal, OR
  ///   3. selector is a number, key is a string, and the key names the
  ///      CLDR plural category of the selector under the bundle's
  ///      locale and the selector's plural type (cardinal / ordinal).
  bool _match(Scope scope, FluentValue selector, FluentValue key) {
    if (selector is FluentString && key is FluentString) {
      return selector.value == key.value;
    }
    if (selector is FluentNumber && key is FluentNumber) {
      return selector.value == key.value;
    }
    if (selector is FluentNumber && key is FluentString) {
      final ruleType = selector.options.type ?? PluralRuleType.cardinal;
      final category = scope.backend.pluralCategory(
        selector,
        ruleType,
        scope.context,
      );
      return key.value == category.name;
    }
    return false;
  }

  /// Render a value to its string form for inclusion in a pattern.
  /// Every value renders through its own [FluentValue.format], which
  /// routes numbers and date-times through the backend and everything
  /// else through [FluentValue.rawString].
  String _render(Scope scope, FluentValue value) => value.format(scope.context);

  /// Render the source-style fallback for an unresolved placeable —
  /// `{name}`, `{-name}`, `{$name}`, `{NAME(…)}`, etc. Used when the
  /// cap halts placeable expansion: each remaining placeable surfaces
  /// with its source reference so the user can still see what was
  /// supposed to go there.
  String _placeableFallback(CompiledExpression expr) {
    return switch (expr) {
      CompiledStringLiteral() => '{"${expr.value}"}',
      CompiledNumberLiteral() => '{${expr.value}}',
      CompiledVariableReference() => '{\$${expr.name}}',
      CompiledMessageReference() =>
        expr.attribute == null
            ? '{${expr.name}}'
            : '{${expr.name}.${expr.attribute}}',
      CompiledTermReference() =>
        expr.attribute == null
            ? '{-${expr.name}}'
            : '{-${expr.name}.${expr.attribute}}',
      CompiledFunctionReference() => '{${expr.name}()}',
      CompiledSelectExpression() => '{???}',
    };
  }

  /// True when [expr] needs FSI/PDI wrapping under `useIsolating`.
  /// Message references, term references, and string literals do not —
  /// see the divergence note at the call site in [_writePlaceable].
  static bool _shouldIsolate(CompiledExpression expr) {
    return !(expr is CompiledMessageReference ||
        expr is CompiledTermReference ||
        expr is CompiledStringLiteral);
  }

  FluentNone _none(String reason) => FluentNone(reason);
}
