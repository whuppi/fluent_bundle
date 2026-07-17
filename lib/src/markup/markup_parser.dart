// Span parser — resolved string → List<FluentSpan>.
//
// Hands the string to package:html (Dart team's HTML5 parser) and
// walks the resulting DOM, converting to the FluentSpan tree.
//
// Why we use a real HTML5 parser instead of writing our own:
//
//   * HTML5 has hundreds of named character entities (`&amp;`,
//     `&copy;`, `&hellip;`, …), three quote styles for attributes
//     (`"`, `'`, none), and a long list of malformed-tag recovery
//     rules. The browser does this; package:html does this; a hand-
//     rolled parser would have bugs forever.
//
//   * Translators write what their HTML intuition expects. Browsers
//     and package:html share semantics — case-insensitive tags,
//     entity decoding, recovery — so what looks right in a browser
//     parses identically here.
//
//   * Mozilla's own non-browser Fluent integrations (Firefox C++
//     DOM Overlays, fluent-react SSR) all reach for HTML parsers
//     when markup support is needed. Our `package:html` choice
//     mirrors that practice for Dart.
//
// Bidi-isolation marks (FSI U+2068 / PDI U+2069) are stripped from
// attribute values after parsing. The resolver wraps every
// interpolation in those marks so RTL/LTR rendering stays correct
// in display text — but inside an attribute value (e.g. `href`),
// the marks would corrupt URLs and similar machine-consumed values.
// Text spans keep the marks; attribute values lose them.

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import 'fluent_span.dart';

/// Parse a resolved Fluent message string into a span tree.
///
/// `resolvedText` is the output of `FluentBundle.formatMessage` — all
/// placeholders interpolated, plurals selected, terms expanded, bidi-
/// isolation marks added. Tags inside that string (`<bold>foo</bold>`,
/// `<a href="x">y</a>`, `<br/>`) are parsed as HTML5 markup; the rest
/// remains plain text.
///
/// The returned list always contains at least one span — an empty
/// resolved string produces `[FluentTextSpan('')]`. This keeps
/// downstream renderers' empty-list handling out of the hot path.
///
/// HTML5 conformance is inherited from `package:html`:
///
///   * Tag names case-folded to lowercase: `<Bold>` ⇒ `tag = "bold"`.
///   * Both quote styles work: `href="x"`, `href='x'`, `href=x`.
///   * Named character entities decoded: `&amp;` ⇒ `&`, `&#39;` ⇒ `'`.
///   * Self-closing: `<br/>`, `<br>`, `<br></br>` are equivalent.
///   * Malformed-tag recovery: unclosed `<bold>oops` closes implicitly;
///     stray `</bold>` is dropped; mismatched `<b><i>x</b></i>` is
///     restructured per HTML5 rules.
///   * Comments (`<!-- … -->`) are dropped.
///   * Whitespace is preserved.
///
/// Bidi-isolation marks (FSI U+2068, PDI U+2069) are stripped from
/// attribute values; text spans keep them.
List<FluentSpan> parseFluentMarkup(String resolvedText) {
  // Empty string short-circuit. parseFragment('') returns a fragment
  // with zero child nodes, which would yield an empty list — but the
  // contract is that callers always get at least one span.
  if (resolvedText.isEmpty) {
    return const [FluentTextSpan('')];
  }

  // package:html's parseFragment treats input as HTML5 markup in a
  // body context. The result is a `DocumentFragment` whose `nodes`
  // are the top-level elements + text nodes.
  final fragment = html.parseFragment(resolvedText);
  final spans = <FluentSpan>[];
  for (final node in fragment.nodes) {
    final converted = _nodeToSpan(node);
    if (converted != null) spans.add(converted);
  }

  // If the resolved string had no parseable content (only comments,
  // dropped junk, etc.), surface a single empty text span so callers
  // don't have to special-case empty lists.
  if (spans.isEmpty) {
    return const [FluentTextSpan('')];
  }

  return spans;
}

/// Convert a single DOM node to a `FluentSpan`. Returns `null` for
/// nodes that should be dropped (comments, doctypes).
FluentSpan? _nodeToSpan(dom.Node node) {
  if (node is dom.Text) {
    // package:html already decoded character entities and applied
    // HTML5 whitespace rules; we take the text exactly as it gives.
    // Bidi-isolation marks in text spans are preserved on purpose.
    // `Text.text` is non-nullable in package:html, so no fallback.
    return FluentTextSpan(node.text);
  }
  if (node is dom.Element) {
    // Tag name is already lowercase per HTML5 normalization; the
    // `localName` property is what we want (no namespace prefix).
    final tag = node.localName ?? '';
    final attrs = _extractAttributes(node);
    final children = <FluentSpan>[];
    for (final child in node.nodes) {
      final converted = _nodeToSpan(child);
      if (converted != null) children.add(converted);
    }
    return FluentMarkupSpan(tag: tag, attrs: attrs, children: children);
  }
  // Comments, processing instructions, doctypes — dropped on
  // purpose. They have no representation in a Fluent message.
  return null;
}

/// Extract attribute key/value pairs from a DOM element, stripping
/// any bidi-isolation marks from the values.
///
/// Returns `const {}` when the element has no attributes — keeps the
/// resulting `FluentMarkupSpan` const-friendly and avoids a fresh
/// empty map per element on the common case.
Map<String, String> _extractAttributes(dom.Element element) {
  if (element.attributes.isEmpty) return const {};

  final result = <String, String>{};
  for (final entry in element.attributes.entries) {
    // package:html's attribute keys are AttributeName objects in
    // namespaced cases or plain Strings otherwise. We coerce to
    // String — for HTML5 fragments without XML namespaces, the keys
    // are always String.
    final key = entry.key.toString();
    final value = _stripIsolationMarks(entry.value);
    result[key] = value;
  }
  return result;
}

/// Strip Unicode bidi-isolation marks from a string.
///
/// FSI (First Strong Isolate, U+2068) and PDI (Pop Directional
/// Isolate, U+2069) are inserted by the resolver around every
/// interpolated value to keep RTL/LTR text rendering correct. They
/// have zero visible width and zero meaning inside attribute values
/// — so we strip them when an interpolation lands in an attribute
/// position. Text spans are unaffected; this helper is only called
/// for attribute values.
String _stripIsolationMarks(String s) {
  // Fast path: no marks present, return original string unchanged.
  // Most attribute values in real-world messages don't interpolate
  // anything, so most calls hit this branch.
  if (!s.contains('\u{2068}') && !s.contains('\u{2069}')) {
    return s;
  }
  return s.replaceAll('\u{2068}', '').replaceAll('\u{2069}', '');
}
