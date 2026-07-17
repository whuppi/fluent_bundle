import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:test/test.dart';

void main() {
  /// Build a bundle wired with a single uppercasing transform, no
  /// other features — keeps the asserts focused on what the transform
  /// touches and what it doesn't.
  FluentBundle bundleWithTransform({
    String Function(String)? transform,
    bool useIsolating = false,
  }) {
    final b = FluentBundle.locales(
      ['en'],
      transform: transform,
      useIsolating: useIsolating,
    );
    return b;
  }

  group('FluentBundle.transform — pre-display text hook', () {
    test('null transform leaves text verbatim', () {
      final b = bundleWithTransform()..addResource('hello = Hello, World!\n');
      expect(b.formatMessage('hello'), 'Hello, World!');
    });

    test('uppercase transform applies to TextElements only', () {
      // Pattern text → transformed. String literal in placeable →
      // verbatim. Variable substitution → verbatim.
      final b = bundleWithTransform(transform: (s) => s.toUpperCase())
        ..addResource(r'''
plain = hello world
literal = before { "lower" } after
mixed = before { $name } after
''');
      expect(b.formatMessage('plain'), 'HELLO WORLD');
      // The literal "lower" stays lowercase; the surrounding text
      // ("before "/" after") is uppercased.
      expect(b.formatMessage('literal'), 'BEFORE lower AFTER');
      // The variable substitution stays verbatim.
      expect(
        b.formatMessage('mixed', args: {'name': 'tom'}),
        'BEFORE tom AFTER',
      );
    });

    test('transform applies before bidi isolation marks', () {
      // With useIsolating: true, the FSI/PDI marks wrap PLACEABLE
      // output, not pattern text. The transform on the surrounding
      // text runs first; the marks are added when the buffer writes
      // the placeable.
      final b = bundleWithTransform(
        transform: (s) => s.replaceAll('a', 'A'),
        useIsolating: true,
      )..addResource(
        r'mixed = aaa { $name } bbb'
        '\n',
      );
      // 'aaa ' becomes 'AAA ', ' bbb' becomes ' bbb' (no 'a' in it),
      // and the variable's value sits between FSI/PDI.
      expect(
        b.formatMessage('mixed', args: {'name': 'aaa'}),
        'AAA \u2068aaa\u2069 bbb',
      );
    });

    test('CompiledStringPattern fast-path also passes through transform', () {
      // A pattern with no placeables takes the fast path; the
      // transform must still run.
      final b = bundleWithTransform(transform: (s) => s.toUpperCase())
        ..addResource('flat = no placeholders here\n');
      expect(b.formatMessage('flat'), 'NO PLACEHOLDERS HERE');
    });

    test('variant keys are not transformed', () {
      // The selector and variant-keys are evaluation-internal — the
      // transform should not see them. Only the pattern text inside
      // the chosen variant gets transformed. We use numeric variant
      // keys here so the test doesn't depend on a wired plural-rules
      // adapter.
      final b = bundleWithTransform(transform: (s) => s.toUpperCase())
        ..addResource(r'''
m = { $count ->
    [1] just one
   *[other] more than one
}
''');
      expect(b.formatMessage('m', args: {'count': 1}), 'JUST ONE');
      expect(b.formatMessage('m', args: {'count': 5}), 'MORE THAN ONE');
    });
  });
}
