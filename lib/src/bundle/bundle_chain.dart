import 'package:fluent_bundle/src/bundle/fluent_bundle.dart';
import 'package:fluent_bundle/src/compiled/compiled_message.dart';
import 'package:fluent_bundle/src/compiled/compiled_pattern.dart';
import 'package:fluent_bundle/src/errors/fluent_error.dart';
import 'package:fluent_bundle/src/syntax/ast/ast.dart';

/// An ordered locale-fallback chain of bundles that IS a [FluentBundle].
///
/// A message missing from the first bundle resolves through the next
/// (`de-CH` → `de` → `en`), so partial translations degrade to the base
/// language instead of rendering literal ids. Because the chain
/// subtypes [FluentBundle], everything built on the bundle surface —
/// generated accessor classes, the `formatMessageAsSpans` markup
/// extension — gains fallback without changing a line.
///
/// Semantics (matching fluent.js's bundle-iterable model):
///
/// - The FIRST member that [hasMessage] owns the id. Formatting runs in
///   that member — its locale, backend, functions, isolation, and
///   transform. An attribute missing on the owning member records the
///   error THERE; later members are not consulted.
/// - An id no member has behaves exactly like a plain bundle miss: the
///   literal id comes back and a [FluentReferenceError] is recorded.
///
/// The chain is a read-only view: load resources into the MEMBER
/// bundles (that is also the hot-reload seam — replace or reload a
/// member, rebuild the chain).
class FluentBundleChain extends FluentBundle {
  /// Chains [bundles] most-specific first. Must be non-empty.
  FluentBundleChain(List<FluentBundle> bundles)
    : assert(bundles.isNotEmpty, 'FluentBundleChain needs >= 1 bundle'),
      bundles = List.unmodifiable(bundles),
      super.locales(_flattenLocales(bundles));

  /// The member bundles, most-specific first.
  final List<FluentBundle> bundles;

  /// Which member served each pattern handed out by [getMessage] — so
  /// [formatPattern] can format in the owning member's context instead
  /// of guessing a locale.
  final Expando<FluentBundle> _patternOwner = Expando<FluentBundle>();

  static List<String> _flattenLocales(List<FluentBundle> bundles) {
    final seen = <String>[];
    for (final bundle in bundles) {
      for (final locale in bundle.locales) {
        if (!seen.contains(locale)) seen.add(locale);
      }
    }
    return seen;
  }

  /// Unsupported — the chain is a read-only view. Load FTL into the
  /// member bundles instead.
  @override
  LoadResult addResource(String source, {bool allowOverrides = false}) {
    throw UnsupportedError(
      'FluentBundleChain is a read-only view — call addResource on the '
      'member bundle that owns the locale instead.',
    );
  }

  /// Every member's parse junk, in chain order.
  @override
  List<Junk> get parseJunk =>
      List.unmodifiable([for (final bundle in bundles) ...bundle.parseJunk]);

  @override
  bool hasMessage(String id) => bundles.any((bundle) => bundle.hasMessage(id));

  @override
  CompiledMessage? getMessage(String id) {
    for (final bundle in bundles) {
      final msg = bundle.getMessage(id);
      if (msg == null) continue;
      final value = msg.value;
      if (value != null) _patternOwner[value] = bundle;
      for (final pattern in msg.attributes.values) {
        _patternOwner[pattern] = bundle;
      }
      return msg;
    }
    return null;
  }

  /// Formats [pattern] in the member that owns it. Patterns must come
  /// from THIS chain's [getMessage] — the chain has no locale of its
  /// own to format a foreign pattern under, so anything else throws.
  @override
  String formatPattern(
    CompiledPattern pattern, {
    Map<String, Object?> args = const {},
    List<FluentError>? errors,
  }) {
    final owner = _patternOwner[pattern];
    if (owner == null) {
      throw StateError(
        'formatPattern on a FluentBundleChain requires a pattern obtained '
        'from this chain\'s getMessage — the owning member decides the '
        'locale and backend.',
      );
    }
    return owner.formatPattern(pattern, args: args, errors: errors);
  }

  @override
  String formatMessage(
    String id, {
    String? attribute,
    Map<String, Object?> args = const {},
    List<FluentError>? errors,
  }) {
    for (final bundle in bundles) {
      if (bundle.hasMessage(id)) {
        return bundle.formatMessage(
          id,
          attribute: attribute,
          args: args,
          errors: errors,
        );
      }
    }
    errors?.add(FluentReferenceError(id));
    return id;
  }
}
