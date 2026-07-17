import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:test/test.dart';

/// A custom FluentValue: proves FluentValue is open for extension (F16).
class _Upper extends FluentValue {
  const _Upper(this.text);
  final String text;
  @override
  String get rawString => text;
  @override
  String format(FluentFormatContext context) => text.toUpperCase();
}

void main() {
  group('spec builtins are always available (F7)', () {
    test(
      'NUMBER resolves with the bare spec backend — no backend imported',
      () {
        final b = FluentBundle('en', useIsolating: false)
          ..addResource('price = It costs { NUMBER(\$n) }.');
        final errors = <FluentError>[];
        final out = b.formatMessage('price', args: {'n': 1234}, errors: errors);
        expect(out, 'It costs 1234.');
        expect(errors.whereType<FluentReferenceError>(), isEmpty);
      },
    );

    test('DATETIME resolves with the bare spec backend', () {
      final b = FluentBundle('en', useIsolating: false)
        ..addResource('at = { DATETIME(\$d) }');
      final out = b.formatMessage(
        'at',
        args: {'d': DateTime.utc(2026, 1, 2, 3, 4, 5)},
      );
      expect(out, contains('2026-01-02'));
    });
  });

  group('custom value types (F16)', () {
    test('a function returning a custom FluentValue formats via format()', () {
      final b = FluentBundle(
        'en',
        useIsolating: false,
        functions: {
          'SHOUT':
              (pos, named, ctx) => _Upper((pos.first as FluentString).value),
        },
      )..addResource('m = { SHOUT("hi") }');
      expect(b.formatMessage('m'), 'HI');
    });
  });

  group('functions receive the format context (F20)', () {
    test('a custom function can read the locale', () {
      final b = FluentBundle(
        'fr',
        useIsolating: false,
        functions: {'LOC': (pos, named, ctx) => FluentString(ctx.locale)},
      )..addResource('m = { LOC() }');
      expect(b.formatMessage('m'), 'fr');
    });
  });

  group('override conflict is a typed FluentOverrideError (F18)', () {
    test('duplicate message id records FluentOverrideError', () {
      final b = FluentBundle('en')..addResource('a = 1');
      final r = b.addResource('a = 2');
      expect(r.errors.single, isA<FluentOverrideError>());
    });
  });
}
