// Verifies the runtime barrel `package:fluent_bundle/fluent_bundle.dart`
// exposes everything an app needs to format messages, with NO
// dependency on the parse-time AST or `package:intl`.
import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:test/test.dart';

import '../_helpers/bundle_factory.dart';

void registerRuntimeBarrelTests() {
  group('runtime barrel', () {
    test('parses + formats a basic message', () {
      final bundle = testBundle('en');
      bundle.addResource('hello = Hi, { \$name }!\n');
      expect(
        bundle.formatMessage('hello', args: {'name': 'World'}),
        'Hi, World!',
      );
    });

    test('exposes FluentValue, FluentNumber, FluentDateTime, FluentNone', () {
      // Construction-only check; the type system catches any missing export.
      const FluentString s = FluentString('x');
      const FluentNumber n = FluentNumber(0);
      final FluentDateTime d = FluentDateTime(DateTime(2025));
      const FluentNone none = FluentNone('reason');
      expect(s.rawString, 'x');
      expect(n.rawString, '0');
      expect(d.rawString, isNotEmpty);
      expect(none.rawString, '{reason}');
    });

    test('exposes errors and Result-style accumulation', () {
      final bundle = testBundle('en');
      bundle.addResource('m = { \$missing }\n');
      final errors = <FluentError>[];
      bundle.formatMessage('m', errors: errors);
      expect(errors, isNotEmpty);
      expect(errors.first, isA<FluentReferenceError>());
    });

    test('compiled types are exposed (CompiledMessage etc.)', () {
      final bundle = testBundle('en');
      bundle.addResource('hello = Hi.\n');
      final CompiledMessage? m = bundle.getMessage('hello');
      expect(m, isNotNull);
      expect(m!.id, 'hello');
    });
  });
}
