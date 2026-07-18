import 'package:fluent_bundle/src/values/fluent_value.dart';
import 'package:test/test.dart';

void registerFluentValueTests() {
  group('FluentValue.coerce', () {
    test('passes a FluentValue through unchanged', () {
      const original = FluentString('hi');
      expect(identical(FluentValue.coerce(original), original), isTrue);
    });

    test('wraps String → FluentString', () {
      final v = FluentValue.coerce('hello');
      expect(v, isA<FluentString>());
      expect((v as FluentString).value, 'hello');
    });

    test('wraps int → FluentNumber', () {
      final v = FluentValue.coerce(42);
      expect(v, isA<FluentNumber>());
      expect((v as FluentNumber).value, 42);
    });

    test('wraps double → FluentNumber', () {
      final v = FluentValue.coerce(3.14);
      expect(v, isA<FluentNumber>());
      expect((v as FluentNumber).value, 3.14);
    });

    test('wraps DateTime → FluentDateTime', () {
      final dt = DateTime(2025, 1, 1);
      final v = FluentValue.coerce(dt);
      expect(v, isA<FluentDateTime>());
      expect((v as FluentDateTime).value, dt);
    });

    test('null returns FluentNone', () {
      final v = FluentValue.coerce(null);
      expect(v, isA<FluentNone>());
      expect((v as FluentNone).reason, contains('null'));
    });

    test('unsupported type returns FluentNone with type tag', () {
      final v = FluentValue.coerce([1, 2, 3]);
      expect(v, isA<FluentNone>());
      // The reason embeds the runtime type. On the Dart VM this prints
      // as `List<int>`; on dart2js it prints as `JSArray<int>` because
      // the JS array is the underlying runtime representation. Either
      // form proves the rejection; we accept both.
      final reason = (v as FluentNone).reason;
      expect(reason, anyOf(contains('List'), contains('JSArray')));
    });
  });

  group('FluentString.rawString', () {
    test('returns the wrapped value', () {
      expect(const FluentString('hi').rawString, 'hi');
    });
  });

  group('FluentNumber', () {
    test('options is empty by default', () {
      expect(const FluentNumber(0).options.isEmpty, isTrue);
    });

    test('options.merge prefers non-null values from the override', () {
      const base = FluentNumberOptions(style: 'decimal', useGrouping: true);
      const override = FluentNumberOptions(style: 'currency', currency: 'USD');
      final merged = base.merge(override);
      expect(merged.style, 'currency');
      expect(merged.currency, 'USD');
      expect(merged.useGrouping, isTrue);
    });

    test('rawString returns toString of the wrapped num', () {
      expect(const FluentNumber(42).rawString, '42');
      expect(const FluentNumber(3.14).rawString, '3.14');
    });
  });

  group('FluentDateTime', () {
    test('options is empty by default', () {
      expect(const FluentDateTimeOptions().isEmpty, isTrue);
    });

    test('options.merge preserves base when override field is null', () {
      const base = FluentDateTimeOptions(dateStyle: 'short');
      const override = FluentDateTimeOptions(timeStyle: 'short');
      final merged = base.merge(override);
      expect(merged.dateStyle, 'short');
      expect(merged.timeStyle, 'short');
    });

    test('rawString returns ISO 8601 form', () {
      final dt = DateTime.utc(2025, 1, 2, 3, 4, 5);
      expect(FluentDateTime(dt).rawString, '2025-01-02T03:04:05.000Z');
    });
  });

  group('FluentNone', () {
    test('rawString wraps reason in braces', () {
      expect(const FluentNone(r'$missing').rawString, r'{$missing}');
    });
  });
}
