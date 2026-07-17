// Span tree for messages with inline markup.
//
// The `formatMessageAsSpans` extension (package:fluent_bundle/markup.dart)
// returns a `List<FluentSpan>` instead of a flat `String`. The tree is
// pure-Dart — Flutter is not imported here. The `fluent_flutter`
// satellite ships the adapter that maps these spans to `TextSpan` /
// `WidgetSpan` (`fluentSpansToInline` + the `FluentText` widget).
//
// This mirrors Mozilla's React Overlays pattern from `@fluent/react`,
// adapted to Dart's sealed-class shape. Translators write messages
// with HTML5-shaped tags:
//
// ```ftl
// welcome = Hello, <bold>{ -app }</bold>! Read <a href="/help">our help</a>.
// ```
//
// At the call site you map each tag name to your own widget builder.
// The tag names are arbitrary — Fluent itself doesn't define them.
// They're a translator-facing convention layered on top of the
// resolved string.
//
// The runtime owns three guarantees about the tree:
//
//   * **Pure Dart.** No Flutter import in this file. The whole tree
//     can be built, walked, and tested on the Dart VM.
//   * **Sealed.** Exactly two concrete subclasses; consumers can
//     `switch` exhaustively without fear of a third type appearing.
//   * **Value-equal.** `==` and `hashCode` walk the tree deeply so
//     two spans built from the same source are interchangeable in
//     sets and maps.

/// A piece of a formatted message that may contain inline markup.
///
/// Sealed: every concrete span is either a [FluentTextSpan] or a
/// [FluentMarkupSpan]. Use a `switch` statement to handle the tree
/// exhaustively.
///
/// ```dart
/// String render(List<FluentSpan> spans) {
///   final buffer = StringBuffer();
///   for (final span in spans) {
///     switch (span) {
///       case FluentTextSpan(:final text):
///         buffer.write(text);
///       case FluentMarkupSpan(:final children):
///         buffer.write(render(children));
///     }
///   }
///   return buffer.toString();
/// }
/// ```
sealed class FluentSpan {
  const FluentSpan();
}

/// A run of plain text in a message.
///
/// The text is exactly what the resolver produced — including any
/// bidi-isolation marks (FSI / PDI, U+2068 / U+2069) it added around
/// interpolated values. Downstream renderers don't need to add their
/// own.
///
/// ```dart
/// const span = FluentTextSpan('Hello, world!');
/// print(span.text); // "Hello, world!"
/// ```
final class FluentTextSpan extends FluentSpan {
  /// Wraps the plain [text] run.
  const FluentTextSpan(this.text);

  /// The literal text to render.
  final String text;

  @override
  String toString() => 'FluentTextSpan(${_quote(text)})';

  @override
  bool operator ==(Object other) =>
      other is FluentTextSpan && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// A markup tag wrapping zero or more child spans.
///
/// Tag names are translator-defined: `<bold>`, `<a>`, `<icon>` —
/// anything the developer mapped to a widget at the call site. The
/// runtime doesn't validate tag names; unknown tags are passed through
/// to the consumer's tag-to-widget mapping (`fluent_flutter`'s
/// converter renders an unmapped tag's children unstyled and asserts
/// in debug builds so translator typos surface during development).
///
/// `tag` is always lowercase — the underlying HTML5 parser
/// case-folds tag names per spec, so `<Bold>`, `<BOLD>`, and `<bold>`
/// all produce `tag = "bold"`.
///
/// ```dart
/// const span = FluentMarkupSpan(
///   tag: 'a',
///   attrs: {'href': '/help'},
///   children: [FluentTextSpan('our help')],
/// );
/// ```
final class FluentMarkupSpan extends FluentSpan {
  /// Bundles the element's tag, attributes, and children.
  const FluentMarkupSpan({
    required this.tag,
    this.attrs = const {},
    this.children = const [],
  });

  /// The tag name from the source — lowercase, no angle brackets.
  final String tag;

  /// Attributes parsed from the opening tag.
  ///
  /// `<a href="/help">` produces `{'href': '/help'}`. Empty when the
  /// tag had no attributes. Values are always `String` — character
  /// entities (`&amp;`, `&#39;`, etc.) are decoded by the parser
  /// before they reach this map.
  final Map<String, String> attrs;

  /// The contents between `<tag>` and `</tag>`.
  ///
  /// Empty for self-closing tags (`<br/>` or `<icon name="usd"/>`).
  /// Otherwise a flat list of [FluentTextSpan] / [FluentMarkupSpan]
  /// in source order.
  final List<FluentSpan> children;

  @override
  String toString() {
    final attrPart =
        attrs.isEmpty
            ? ''
            : ' ${attrs.entries.map((e) => '${e.key}=${_quote(e.value)}').join(' ')}';
    final childPart = children.isEmpty ? '/' : '>${children.join()}</$tag';
    return 'FluentMarkupSpan(<$tag$attrPart$childPart>)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FluentMarkupSpan) return false;
    if (other.tag != tag) return false;
    if (other.attrs.length != attrs.length) return false;
    for (final entry in attrs.entries) {
      if (other.attrs[entry.key] != entry.value) return false;
    }
    if (other.children.length != children.length) return false;
    for (var i = 0; i < children.length; i++) {
      if (other.children[i] != children[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    // Order-independent hash for attrs (Map equality is order-independent).
    var attrsHash = 0;
    for (final entry in attrs.entries) {
      // Combine each (key, value) pair into a single hash, then XOR
      // them so order doesn't matter.
      attrsHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(tag, attrsHash, Object.hashAll(children));
  }
}

/// Quote a string for `toString()` output, escaping internal quotes
/// and special characters so the result is unambiguous when debugging.
String _quote(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');
  return '"$escaped"';
}
