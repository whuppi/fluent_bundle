// Mozilla Fluent Syntax compliance corpus runner.
//
// For each `*.ftl` fixture under `test/_corpus/syntax/`, parses it with
// our parser, serializes the resulting AST to the canonical Fluent JSON
// shape (see `ast_to_json.dart`), and asserts structural equality with
// the matching `*.json` fixture.
//
// Drift between our output and the canonical shape is a real bug — the
// fixtures are the spec's executable form. Failures should be fixed in
// the parser or in `ast_to_json.dart` (when the JSON shape itself
// drifted), never by editing the fixtures.
//
// VM-only: this runner reads `.ftl` and `.json` fixtures from disk via
// `dart:io`. The parser itself is pure-Dart and cross-platform; the
// corpus harness is the only piece that needs filesystem access.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:fluent_bundle/syntax.dart';
import 'package:test/test.dart';

import 'ast_to_json.dart';

void main() {
  final corpusDir = Directory('test/_corpus/syntax');
  if (!corpusDir.existsSync()) {
    fail('Mozilla Fluent Syntax corpus not found at ${corpusDir.path}');
  }

  final ftlFiles =
      corpusDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ftl'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  group('Mozilla Fluent Syntax corpus', () {
    for (final ftl in ftlFiles) {
      final basename = ftl.uri.pathSegments.last.replaceAll('.ftl', '');
      final expectedFile = File('${ftl.path.replaceAll('.ftl', '')}.json');

      test(basename, () {
        if (!expectedFile.existsSync()) {
          fail('Missing companion JSON for $basename: ${expectedFile.path}');
        }

        final source = ftl.readAsStringSync();
        final expected = jsonDecode(expectedFile.readAsStringSync());

        // Parse with spans off so the JSON output never contains span
        // metadata (the canonical fixtures don't include spans).
        final parser = FluentParser(
          options: const FluentParserOptions(withSpans: false),
        );
        final actual = resourceToJson(parser.parse(source));

        expect(
          actual,
          equals(expected),
          reason:
              'Parser output for "$basename" does not match the canonical '
              'Mozilla Fluent fixture.\n'
              'Source: ${ftl.path}\n'
              'Expected fixture: ${expectedFile.path}',
        );
      });
    }
  });
}
