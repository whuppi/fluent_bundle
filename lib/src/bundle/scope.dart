import 'package:fluent_bundle/src/backend/backend.dart';
import 'package:fluent_bundle/src/backend/format_context.dart';
import 'package:fluent_bundle/src/compiled/compiled_pattern.dart';
import 'package:fluent_bundle/src/errors/fluent_error.dart';
import 'package:fluent_bundle/src/values/fluent_value.dart';

/// Per-format-call resolution state.
///
/// Carries the caller-supplied [args], the running [errors] list, and the
/// guards against runaway recursion (cycle detection via [traveled],
/// total placeable count via [placeables] gated by [dirty]).
///
/// `params` is a stack frame: when a Term is invoked with arguments,
/// resolution pushes a frame so `$variable` references inside the term
/// resolve from those arguments instead of the caller's [args]. Pop the
/// frame on return.
class Scope {
  /// Creates the scope for one formatMessage / formatPattern call.
  Scope({
    required this.locales,
    required this.args,
    required this.errors,
    required this.backend,
    required this.useIsolating,
    this.transform,
    this.maxPlaceables = 100,
  });

  /// Locales the bundle was constructed with, in priority order. Used for
  /// locale-aware formatting (numbers, dates) and plural-rule lookup.
  final List<String> locales;

  /// Caller-supplied arguments. Looked up by `$variable` references at
  /// the top frame. Coerced to [FluentValue] on first read; the cache lives
  /// on [_coercedArgs] so repeat lookups don't re-coerce.
  final Map<String, Object?> args;

  /// Term-call frames. Top of stack (`params.last`) is the active frame
  /// when resolving a term's body.
  final List<Map<String, FluentValue>> params = [];

  /// Patterns currently being resolved, used to detect cycles. A pattern
  /// added here is blocked from re-entry; the cycle handler renders the
  /// referencing slot with the entry-point ref name (`{foo}` for a
  /// self-cycling message).
  final Set<CompiledPattern> traveled = {};

  /// Stop signal. Once set, the pattern resolver short-circuits every
  /// remaining placeable in the current pattern body — preserving the
  /// text accumulated so far while substituting unrendered placeables
  /// with their reference fallback. Used by the [maxPlaceables] cap to
  /// halt runaway expansion (Billion Laughs–style attacks) without
  /// throwing across the resolver's recursion.
  bool dirty = false;

  /// Errors accumulated during resolution. Never thrown — the caller may
  /// surface them after `formatPattern` returns.
  final List<FluentError> errors;

  /// Maximum total placeables resolved per format call. Defaults to 100,
  /// the safe limit that prevents quadratic / cyclic expansion blow-ups
  /// without rejecting any realistic real-world message.
  final int maxPlaceables;

  /// Placeables expanded so far — checked against the recursion cap.
  int placeables = 0;

  /// The bundle's backend: formats numbers and dates and classifies
  /// plurals. The spec-fallback base is locale-blind; the intl / icu
  /// satellites provide CLDR-aware subclasses.
  final FluentBackend backend;

  /// When true, every placeable's rendered string is wrapped in Unicode
  /// First-Strong Isolate (U+2068) … Pop Directional Isolate (U+2069)
  /// marks so the placeable's bidi context can't leak into the
  /// surrounding pattern text. Required for safe RTL rendering of mixed
  /// content like `"السلام عليكم { $name }"` with a Latin name.
  final bool useIsolating;

  /// Optional pre-display transform applied to every literal text
  /// element before it's written. Used for pseudo-localization tools.
  /// `null` skips the transform; non-null is applied verbatim with no
  /// further filtering.
  final String Function(String text)? transform;

  /// Cache of coerced [args] entries, populated lazily.
  final Map<String, FluentValue> _coercedArgs = {};

  /// The format context handed to `FluentValue.format`, the backend, and
  /// user functions. Built once per scope from the same locales, errors,
  /// and backend.
  late final FluentFormatContext context = FluentFormatContext(
    locales: locales,
    errors: errors,
    backend: backend,
  );

  /// Resolve a `$name` reference. Inside a term call the top params
  /// frame is the ONLY source — the caller's [args] are isolated out,
  /// so term bodies compose without argument-name collisions. Outside
  /// a term call, resolves from [args] (coercion cached).
  FluentValue? lookupVariable(String name) {
    if (params.isNotEmpty) {
      final frame = params.last;
      final fromFrame = frame[name];
      if (fromFrame != null) return fromFrame;
      // Inside a term call, ONLY the frame is visible — caller args do
      // NOT leak into the term body. This isolation is what makes terms
      // safely composable without callers worrying about argument-name
      // collisions.
      return null;
    }
    final cached = _coercedArgs[name];
    if (cached != null) return cached;
    if (!args.containsKey(name)) return null;
    final coerced = FluentValue.coerce(args[name]);
    _coercedArgs[name] = coerced;
    return coerced;
  }

  /// Push a fresh term-args frame.
  void pushTermFrame(Map<String, FluentValue> frame) {
    params.add(frame);
  }

  /// Pop the top term-args frame.
  void popTermFrame() {
    params.removeLast();
  }

  /// Increment the placeable counter. When the cap is exceeded, set the
  /// [dirty] flag and record a [FluentResolutionLimitError] — the
  /// pattern resolver checks [dirty] after each placeable and stops
  /// expanding further, preserving whatever it has accumulated so far.
  /// Returns true when the placeable should still be rendered, false
  /// when the caller should skip resolution and emit the fallback.
  bool countPlaceable() {
    placeables++;
    if (placeables > maxPlaceables) {
      dirty = true;
      errors.add(const FluentResolutionLimitError());
      return false;
    }
    return true;
  }
}
