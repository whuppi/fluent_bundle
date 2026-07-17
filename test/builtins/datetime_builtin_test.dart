// The DATETIME() option parser: hourCycle joins the option surface with
// value-set validation, and merge keeps named-args-win semantics.

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_bundle/src/builtins/datetime_builtin.dart';
import 'package:test/test.dart';

void main() {
  FluentDateTimeOptions parse(
    Map<String, String> named, [
    List<FluentError>? errors,
  ]) {
    return parseDateTimeOptions(
      named.map((k, v) => MapEntry(k, FluentString(v))),
      errors ?? <FluentError>[],
    );
  }

  group('parseDateTimeOptions — hourCycle', () {
    test('each valid cycle parses', () {
      for (final cycle in ['h11', 'h12', 'h23', 'h24']) {
        expect(parse({'hourCycle': cycle}).hourCycle, cycle);
      }
    });

    test('an out-of-set cycle records an error and drops to null', () {
      final errors = <FluentError>[];
      final o = parse({'hourCycle': 'h25'}, errors);
      expect(o.hourCycle, isNull);
      expect(errors.single, isA<FluentFormatError>());
    });
  });

  group('parseDateTimeOptions — value-set validation', () {
    test('out-of-set values record an error and drop to null', () {
      for (final entry
          in {
            'dateStyle': 'huge',
            'timeStyle': 'tiny',
            'weekday': 'numeric',
            'era': '2-digit',
            'dayPeriod': 'numeric',
            'timeZoneName': 'iso',
            'year': 'long',
            'month': 'wide',
            'day': 'narrow',
            'hour': 'short',
            'minute': 'long',
            'second': 'narrow',
            'calendar': 'no good!',
            'numberingSystem': 'x!',
          }.entries) {
        final errors = <FluentError>[];
        final o = parse({entry.key: entry.value}, errors);
        expect(o.isEmpty, isTrue, reason: '${entry.key} should drop');
        expect(
          errors.single,
          isA<FluentFormatError>(),
          reason: '${entry.key} should error',
        );
      }
    });

    test('fractionalSecondDigits accepts 1-3 only', () {
      expect(parse({'fractionalSecondDigits': '2'}).fractionalSecondDigits, 2);
      final errors = <FluentError>[];
      final o = parse({'fractionalSecondDigits': '0'}, errors);
      expect(o.fractionalSecondDigits, isNull);
      expect(errors.single, isA<FluentFormatError>());
    });

    test('multi-subtag calendar identifiers pass', () {
      expect(parse({'calendar': 'islamic-civil'}).calendar, 'islamic-civil');
    });
  });

  group('merge', () {
    test('hourCycle merges with named-args-win semantics', () {
      const base = FluentDateTimeOptions(hourCycle: 'h23');
      expect(
        base.merge(const FluentDateTimeOptions(hourCycle: 'h12')).hourCycle,
        'h12',
      );
      expect(base.merge(const FluentDateTimeOptions()).hourCycle, 'h23');
    });
  });
}
