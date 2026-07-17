import 'package:fluent_bundle/src/compiled/compiled_expression.dart';
import 'package:fluent_bundle/src/compiled/compiled_message.dart';
import 'package:fluent_bundle/src/compiled/compiled_pattern.dart';
import 'package:fluent_bundle/src/compiled/compiled_term.dart';
import 'package:fluent_bundle/src/syntax/ast/ast.dart' as ast;

/// Result of compiling a [ast.Resource]: maps of named messages and terms,
/// plus the list of [ast.Junk] entries the parser preserved.
class CompilationResult {
  /// Bundles everything one compilation pass produced.
  const CompilationResult({
    required this.messages,
    required this.terms,
    required this.junk,
  });

  /// Compiled messages by id.
  final Map<String, CompiledMessage> messages;

  /// Compiled terms by id (no leading `-`).
  final Map<String, CompiledTerm> terms;

  /// Source stretches the parser could not make sense of.
  final List<ast.Junk> junk;
}

/// Lowers a syntax AST [ast.Resource] into the compact runtime form
/// consumed by the resolver.
///
/// The compiler preserves all source-language semantics. The two visible
/// shape changes are:
///   - patterns with no placeables collapse to [CompiledStringPattern]
///   - variant keys precompute their numeric form when the source key is
///     a number literal, avoiding repeated parses at format time
class Compiler {
  /// Compile a parsed resource. Junk entries are returned alongside the
  /// compiled output so callers can surface parse errors without losing
  /// the messages and terms that did parse.
  CompilationResult compile(ast.Resource resource) {
    final messages = <String, CompiledMessage>{};
    final terms = <String, CompiledTerm>{};
    final junk = <ast.Junk>[];

    for (final entry in resource.body) {
      switch (entry) {
        case ast.Message():
          messages[entry.id.name] = _compileMessage(entry);
        case ast.Term():
          terms[entry.id.name] = _compileTerm(entry);
        case ast.Comment():
          // Standalone comments carry no runtime meaning.
          break;
        case ast.Junk():
          junk.add(entry);
      }
    }

    return CompilationResult(messages: messages, terms: terms, junk: junk);
  }

  CompiledMessage _compileMessage(ast.Message m) {
    return CompiledMessage(
      id: m.id.name,
      value: m.value == null ? null : _compilePattern(m.value!),
      attributes: _compileAttributes(m.attributes),
    );
  }

  CompiledTerm _compileTerm(ast.Term t) {
    return CompiledTerm(
      id: t.id.name,
      value: _compilePattern(t.value),
      attributes: _compileAttributes(t.attributes),
    );
  }

  Map<String, CompiledPattern> _compileAttributes(List<ast.Attribute> attrs) {
    if (attrs.isEmpty) return const {};
    final out = <String, CompiledPattern>{};
    for (final a in attrs) {
      out[a.id.name] = _compilePattern(a.value);
    }
    return out;
  }

  // ── Pattern lowering ────────────────────────────────────────────────────

  CompiledPattern _compilePattern(ast.Pattern p) {
    // Empty pattern → empty string (parser rejects this in normal flow,
    // but be defensive in the lowering pass).
    if (p.elements.isEmpty) return const CompiledStringPattern('');

    // Fast path: every element is text. Concatenate and return a literal.
    final allText = p.elements.every((e) => e is ast.TextElement);
    if (allText) {
      final buffer = StringBuffer();
      for (final e in p.elements) {
        buffer.write((e as ast.TextElement).value);
      }
      return CompiledStringPattern(buffer.toString());
    }

    // Slow path: lower each element.
    final elements = <CompiledElement>[];
    for (final e in p.elements) {
      switch (e) {
        case ast.TextElement():
          elements.add(CompiledTextElement(e.value));
        case ast.Placeable():
          elements.add(CompiledPlaceable(_compileExpression(e.expression)));
      }
    }
    return CompiledComplexPattern(elements);
  }

  // ── Expression lowering ─────────────────────────────────────────────────

  CompiledExpression _compileExpression(ast.Expression expr) {
    return switch (expr) {
      ast.StringLiteralExpression() => CompiledStringLiteral(
        expr.literal.value,
      ),
      ast.NumberLiteralExpression() => CompiledNumberLiteral(
        expr.literal.value,
        expr.literal.precision,
      ),
      ast.VariableReference() => CompiledVariableReference(expr.id.name),
      ast.MessageReference() => CompiledMessageReference(
        expr.id.name,
        attribute: expr.attribute?.name,
      ),
      ast.TermReference() => CompiledTermReference(
        expr.id.name,
        attribute: expr.attribute?.name,
        arguments:
            expr.arguments == null
                ? null
                : _compileCallArguments(expr.arguments!),
      ),
      ast.FunctionReference() => CompiledFunctionReference(
        expr.id.name,
        _compileCallArguments(expr.arguments),
      ),
      ast.SelectExpression() => _compileSelect(expr),
      // Nested placeable — `{ {"x"} }`. Per spec the inner placeable is
      // structurally just an Expression in the outer placeable's slot.
      // We unwrap and lower the inner expression directly; the surrounding
      // placeable nesting becomes a no-op at runtime since the compiled
      // expression already produces the same value.
      ast.Placeable() => _compileExpression(expr.expression),
    };
  }

  CompiledCallArguments _compileCallArguments(ast.CallArguments args) {
    final positional = <CompiledExpression>[];
    for (final p in args.positional) {
      positional.add(_compileExpression(p));
    }
    final named = <String, CompiledExpression>{};
    for (final n in args.named) {
      named[n.name.name] = _compileLiteralValue(n.value);
    }
    return CompiledCallArguments(positional: positional, named: named);
  }

  CompiledExpression _compileLiteralValue(ast.Literal lit) {
    return switch (lit) {
      ast.StringLiteral() => CompiledStringLiteral(lit.value),
      ast.NumberLiteral() => CompiledNumberLiteral(lit.value, lit.precision),
    };
  }

  CompiledSelectExpression _compileSelect(ast.SelectExpression sel) {
    final variants = <CompiledVariant>[];
    var defaultIndex = -1;
    for (var i = 0; i < sel.variants.length; i++) {
      final v = sel.variants[i];
      if (v.isDefault) {
        // The parser already enforces "exactly one default", so this loop
        // never sees a second default.
        defaultIndex = i;
      }
      variants.add(_compileVariant(v));
    }
    return CompiledSelectExpression(
      selector: _compileExpression(sel.selector),
      variants: variants,
      defaultIndex: defaultIndex,
    );
  }

  CompiledVariant _compileVariant(ast.Variant v) {
    final key = v.key;
    final keyExpr = switch (key) {
      ast.IdentifierKey() => CompiledStringLiteral(key.id.name),
      ast.NumberLiteralKey() => CompiledNumberLiteral(
        key.value.value,
        key.value.precision,
      ),
    };
    return CompiledVariant(key: keyExpr, value: _compilePattern(v.value));
  }
}
