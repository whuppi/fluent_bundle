import 'package:fluent_bundle/src/backend/backend.dart';
import 'package:fluent_bundle/src/builtins/builtins.dart';
import 'package:fluent_bundle/src/bundle/fluent_function.dart';
import 'package:fluent_bundle/src/bundle/resolver.dart';
import 'package:fluent_bundle/src/bundle/scope.dart';
import 'package:fluent_bundle/src/compiled/compiled_message.dart';
import 'package:fluent_bundle/src/compiled/compiled_pattern.dart';
import 'package:fluent_bundle/src/compiled/compiled_term.dart';
import 'package:fluent_bundle/src/compiled/compiler.dart';
import 'package:fluent_bundle/src/errors/fluent_error.dart';
import 'package:fluent_bundle/src/syntax/ast/ast.dart';
import 'package:fluent_bundle/src/syntax/parser/parser.dart';

/// A localization bundle: a set of compiled messages and terms in one
/// locale (or ordered locale fallback chain), plus the functions that
/// expressions may call.
///
/// Construct a bundle with a locale (or [FluentBundle.locales] for a
/// fallback chain), load resources via [addResource], then format messages
/// with [formatMessage] or [formatPattern]. Errors during resolution are
/// collected on the optional `errors` list rather than thrown.
///
/// `NUMBER` and `DATETIME` are always available. A bare `FluentBundle('en')`
/// renders them digit-correct but locale-blind; pass a `backend:` from
/// `package:fluent_intl` or `package:fluent_icu` for CLDR-aware formatting
/// and real plural rules.
class FluentBundle {
  /// Creates a bundle for a single [locale].
  FluentBundle(
    String locale, {
    this.backend = const FluentBackend(),
    Map<String, FluentFunction>? functions,
    this.useIsolating = true,
    this.transform,
  }) : locales = List<String>.unmodifiable([locale]),
       functions = Map.unmodifiable({...coreBuiltins(), ...?functions});

  /// Creates a bundle with a [locales] fallback chain, most specific first.
  FluentBundle.locales(
    List<String> locales, {
    this.backend = const FluentBackend(),
    Map<String, FluentFunction>? functions,
    this.useIsolating = true,
    this.transform,
  }) : locales = List<String>.unmodifiable(locales),
       functions = Map.unmodifiable({...coreBuiltins(), ...?functions});

  /// Locales for this bundle, in priority order. The first locale drives
  /// number / date formatting and plural-category lookup.
  final List<String> locales;

  /// The backend that formats numbers and dates and classifies plurals.
  /// Defaults to the spec-fallback [FluentBackend].
  final FluentBackend backend;

  /// Functions callable from FTL expressions. Always contains `NUMBER` and
  /// `DATETIME`; user-supplied functions are merged over them (a
  /// user-provided `NUMBER` overrides the built-in).
  final Map<String, FluentFunction> functions;

  /// Whether to wrap placeable output in Unicode bidi-isolation marks
  /// (FSI U+2068 / PDI U+2069) when the rendered value is a string. The
  /// safe default for production UIs is ON; turn off only for tests where
  /// the wrapping interferes with assertions.
  final bool useIsolating;

  /// Optional pre-display text transform applied to every literal
  /// `TextElement` in a resolved pattern. String literals (`{ "X" }`),
  /// variant keys, and `$variable` substitutions are NOT transformed —
  /// only author-written pattern text. Useful for pseudo-localization
  /// (uppercasing, accent-padding, length expansion) during QA.
  ///
  /// `null` (the default) skips the transform pass entirely; text
  /// elements are written verbatim.
  final String Function(String text)? transform;

  final Map<String, CompiledMessage> _messages = {};
  final Map<String, CompiledTerm> _terms = {};
  final List<Junk> _parseJunk = [];

  /// Parse and load FTL [source] into this bundle.
  ///
  /// By default, redefining a message that already exists is a no-op
  /// (the existing message wins) and a [FluentOverrideError] is recorded in
  /// the returned [LoadResult]. Pass `allowOverrides: true` to replace
  /// existing definitions.
  ///
  /// Junk entries are accumulated separately so callers can inspect parse
  /// errors without losing the entries that did parse.
  LoadResult addResource(String source, {bool allowOverrides = false}) {
    final parser = FluentParser(
      options: const FluentParserOptions(withSpans: false),
    );
    final compiled = Compiler().compile(parser.parse(source));

    final errors = <FluentError>[];
    compiled.messages.forEach((id, msg) {
      if (!allowOverrides && _messages.containsKey(id)) {
        errors.add(FluentOverrideError(id));
        return;
      }
      _messages[id] = msg;
    });
    compiled.terms.forEach((id, term) {
      if (!allowOverrides && _terms.containsKey(id)) {
        errors.add(FluentOverrideError(id, isTerm: true));
        return;
      }
      _terms[id] = term;
    });
    _parseJunk.addAll(compiled.junk);
    return LoadResult(
      junk: List.unmodifiable(compiled.junk),
      errors: List.unmodifiable(errors),
    );
  }

  /// All [Junk] entries accumulated by every prior [addResource] call,
  /// in the order they were parsed.
  List<Junk> get parseJunk => List.unmodifiable(_parseJunk);

  /// True if this bundle has a message with the given [id].
  bool hasMessage(String id) => _messages.containsKey(id);

  /// Look up a compiled message, or `null` if not found. The result is an
  /// opaque handle: pass `message.value` (or `message.attributes[name]`)
  /// to [formatPattern] for pattern-level caching in hot loops.
  CompiledMessage? getMessage(String id) => _messages[id];

  /// Format an arbitrary [pattern]. Most callers go through
  /// [formatMessage] instead; this is the lower-level entry point used
  /// when you've already resolved a pattern via [getMessage].
  String formatPattern(
    CompiledPattern pattern, {
    Map<String, Object?> args = const {},
    List<FluentError>? errors,
  }) {
    final scope = Scope(
      locales: locales,
      args: args,
      errors: errors ?? <FluentError>[],
      backend: backend,
      useIsolating: useIsolating,
      transform: transform,
    );
    final resolver = Resolver(
      lookupMessage: (name) => _messages[name],
      lookupTerm: (name) => _terms[name],
      lookupFunction: (name) => functions[name],
    );
    // The resolver writes everything into a single shared buffer —
    // streaming through one writer instead of returning intermediate
    // strings at every recursion level. That shape preserves whatever
    // partial content was rendered up to a cap-hit or cycle, so the
    // user sees a usable result alongside the recorded errors instead
    // of an empty string.
    final out = StringBuffer();
    resolver.resolvePattern(scope, pattern, out);
    return out.toString();
  }

  /// Format the message identified by [id]. If [attribute] is supplied,
  /// the matching attribute's pattern is formatted instead of the
  /// message's value.
  ///
  /// **Always returns a string.** When the message (or attribute) is
  /// missing the literal id is returned (`'welcome'`, or
  /// `'welcome.title'` for an attribute miss) and a
  /// [FluentReferenceError] is recorded on the [errors] list. The
  /// missing id renders visibly in the UI so the gap surfaces during
  /// dev, instead of silently rendering as empty space.
  ///
  /// To distinguish "missing message" from "successfully rendered",
  /// pass an [errors] list and check it after the call:
  ///
  /// ```dart
  /// final errors = <FluentError>[];
  /// final text = bundle.formatMessage('welcome', errors: errors);
  /// if (errors.any((e) => e is FluentReferenceError)) {
  ///   // Missing message — `text` is the literal id.
  /// }
  /// ```
  ///
  /// Or use [hasMessage] before formatting if you need to branch on
  /// presence without rendering.
  ///
  /// For inline markup rendered to a span tree, see the
  /// `formatMessageAsSpans` extension in `package:fluent_bundle/markup.dart`.
  String formatMessage(
    String id, {
    String? attribute,
    Map<String, Object?> args = const {},
    List<FluentError>? errors,
  }) {
    final msg = _messages[id];
    if (msg == null) {
      errors?.add(FluentReferenceError(id));
      return id;
    }
    final pattern = attribute == null ? msg.value : msg.attributes[attribute];
    if (pattern == null) {
      final ref = attribute == null ? id : '$id.$attribute';
      errors?.add(FluentReferenceError(ref));
      return ref;
    }
    return formatPattern(pattern, args: args, errors: errors);
  }
}

/// Result of [FluentBundle.addResource].
class LoadResult {
  /// Bundles the [junk] and [errors] one addResource call produced.
  const LoadResult({required this.junk, required this.errors});

  /// Entries the parser couldn't make sense of. The bundle keeps these
  /// out of the resolved messages but exposes them so callers can show
  /// them to authors.
  final List<Junk> junk;

  /// Bundle-level errors encountered during load (e.g. duplicate IDs
  /// when `allowOverrides: false`).
  final List<FluentError> errors;

  /// Whether the load produced any junk or any bundle-level error.
  bool get hasErrors => junk.isNotEmpty || errors.isNotEmpty;
}
