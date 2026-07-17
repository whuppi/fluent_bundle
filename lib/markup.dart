/// Inline-markup rendering for Project Fluent.
///
/// Translators write HTML5-shaped tags inside messages
/// (`welcome = Hello, <bold>{ $name }</bold>!`); this barrel turns a
/// resolved message into a [FluentSpan] tree you can walk to build any UI.
/// Importing it pulls in `package:html` (the Dart team's HTML5 parser);
/// consumers that don't import it pay nothing.
///
/// ```dart
/// import 'package:fluent_bundle/fluent_bundle.dart';
/// import 'package:fluent_bundle/markup.dart';
///
/// final spans = bundle.formatMessageAsSpans('welcome', args: {'name': 'Aria'});
/// ```
///
/// Tag names are arbitrary — Fluent doesn't define them — with one
/// carve-out from the HTML5 grammar this parser follows: VOID element
/// names (`link`, `br`, `img`, `meta`, ...) parse as childless, so a
/// `<link>...</link>` loses its children to sibling text. Pick
/// non-void names (`<a>`, `<cta>`, `<bold>`).
///
/// The span tree is pure Dart. The Flutter adapter that maps it to
/// `TextSpan` / `WidgetSpan` lives in the `fluent_flutter` satellite
/// (`package:fluent_flutter/markup.dart`), not in this barrel.
library;

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_bundle/src/markup/fluent_span.dart';
import 'package:fluent_bundle/src/markup/markup_parser.dart';

export 'src/markup/fluent_span.dart';
export 'src/markup/markup_parser.dart' show parseFluentMarkup;

/// Adds span-tree rendering of inline markup to [FluentBundle].
extension FluentMarkupFormatting on FluentBundle {
  /// Format the message identified by [id] and parse any inline HTML5-
  /// shaped markup in the result into a [FluentSpan] tree.
  ///
  /// Behaves like [FluentBundle.formatMessage] for message resolution
  /// (always returns a non-empty list; a missing message yields
  /// `[FluentTextSpan(id)]` and records a [FluentReferenceError]), then
  /// parses the resolved string. Bidi-isolation marks are preserved inside
  /// text spans and stripped from attribute values.
  List<FluentSpan> formatMessageAsSpans(
    String id, {
    String? attribute,
    Map<String, Object?> args = const {},
    List<FluentError>? errors,
  }) {
    final resolved = formatMessage(
      id,
      attribute: attribute,
      args: args,
      errors: errors,
    );
    return parseFluentMarkup(resolved);
  }
}
