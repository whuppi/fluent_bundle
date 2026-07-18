// Equality + hashCode contract tests for the FluentSpan tree.
//
// The runtime depends on value equality (not identity) so consumers
// can put spans in sets, use them as map keys, and compare two trees
// built from the same source.

import 'package:fluent_bundle/markup.dart';
import 'package:test/test.dart';

void registerFluentSpanEqualityTests() {
  group('FluentTextSpan', () {
    test('equal when text matches', () {
      expect(const FluentTextSpan('hello'), const FluentTextSpan('hello'));
    });

    test('unequal when text differs', () {
      expect(
        const FluentTextSpan('hello'),
        isNot(const FluentTextSpan('Hello')),
      );
    });

    test('hashCode matches when equal', () {
      expect(
        const FluentTextSpan('hello').hashCode,
        const FluentTextSpan('hello').hashCode,
      );
    });

    test('toString is debuggable', () {
      expect(
        const FluentTextSpan('hello').toString(),
        'FluentTextSpan("hello")',
      );
      expect(
        const FluentTextSpan('a "quoted" b').toString(),
        r'FluentTextSpan("a \"quoted\" b")',
      );
      expect(
        const FluentTextSpan('line1\nline2').toString(),
        r'FluentTextSpan("line1\nline2")',
      );
    });

    test('not equal to FluentMarkupSpan even with empty children', () {
      expect(const FluentTextSpan(''), isNot(const FluentMarkupSpan(tag: 'x')));
    });
  });

  group('FluentMarkupSpan — tag and structure', () {
    test('equal when tag matches and children match', () {
      const a = FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('hi')]);
      const b = FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('hi')]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('unequal when tag differs', () {
      const a = FluentMarkupSpan(tag: 'bold');
      const b = FluentMarkupSpan(tag: 'em');
      expect(a, isNot(b));
    });

    test('unequal when child count differs', () {
      const a = FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('a')]);
      const b = FluentMarkupSpan(
        tag: 'bold',
        children: [FluentTextSpan('a'), FluentTextSpan('b')],
      );
      expect(a, isNot(b));
    });

    test('unequal when child contents differ', () {
      const a = FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('a')]);
      const b = FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('b')]);
      expect(a, isNot(b));
    });

    test('identity returns equal short-circuit', () {
      const a = FluentMarkupSpan(tag: 'bold');
      expect(identical(a, a), isTrue);
      expect(a, a);
    });
  });

  group('FluentMarkupSpan — attributes', () {
    test('equal when attrs match', () {
      const a = FluentMarkupSpan(tag: 'a', attrs: {'href': '/x'});
      const b = FluentMarkupSpan(tag: 'a', attrs: {'href': '/x'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('unequal when attr value differs', () {
      const a = FluentMarkupSpan(tag: 'a', attrs: {'href': '/x'});
      const b = FluentMarkupSpan(tag: 'a', attrs: {'href': '/y'});
      expect(a, isNot(b));
    });

    test('unequal when attr key differs', () {
      const a = FluentMarkupSpan(tag: 'a', attrs: {'href': '/x'});
      const b = FluentMarkupSpan(tag: 'a', attrs: {'src': '/x'});
      expect(a, isNot(b));
    });

    test('unequal when attr count differs', () {
      const a = FluentMarkupSpan(tag: 'a', attrs: {'href': '/x'});
      const b = FluentMarkupSpan(
        tag: 'a',
        attrs: {'href': '/x', 'target': '_blank'},
      );
      expect(a, isNot(b));
    });

    test('attr order does not affect equality', () {
      // Map literals iterate in insertion order, so this verifies our
      // == and hashCode are order-independent (they should be — Map
      // equality is order-independent in Dart's contract).
      const a = FluentMarkupSpan(
        tag: 'a',
        attrs: {'href': '/x', 'target': '_blank'},
      );
      const b = FluentMarkupSpan(
        tag: 'a',
        attrs: {'target': '_blank', 'href': '/x'},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('empty attrs equal default empty', () {
      const a = FluentMarkupSpan(tag: 'br');
      const b = FluentMarkupSpan(tag: 'br', attrs: {});
      expect(a, b);
    });
  });

  group('FluentMarkupSpan — deep nesting', () {
    test('two-level tree equal when shape and contents match', () {
      const a = FluentMarkupSpan(
        tag: 'bold',
        children: [
          FluentTextSpan('this is '),
          FluentMarkupSpan(tag: 'em', children: [FluentTextSpan('important')]),
        ],
      );
      const b = FluentMarkupSpan(
        tag: 'bold',
        children: [
          FluentTextSpan('this is '),
          FluentMarkupSpan(tag: 'em', children: [FluentTextSpan('important')]),
        ],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('unequal when innermost text differs', () {
      const a = FluentMarkupSpan(
        tag: 'bold',
        children: [
          FluentMarkupSpan(tag: 'em', children: [FluentTextSpan('important')]),
        ],
      );
      const b = FluentMarkupSpan(
        tag: 'bold',
        children: [
          FluentMarkupSpan(tag: 'em', children: [FluentTextSpan('IMPORTANT')]),
        ],
      );
      expect(a, isNot(b));
    });
  });

  group('FluentSpan — usable in collections', () {
    test('text spans can be Set members', () {
      // Build the set programmatically to deliberately try inserting a
      // duplicate — the literal-form check fires `equal_elements_in_set`
      // since it can spot the dup at compile time.
      final set = <FluentSpan>{};
      set.add(const FluentTextSpan('a'));
      set.add(const FluentTextSpan('b'));
      set.add(const FluentTextSpan('a')); // duplicate, dropped by Set
      expect(set.length, 2);
      expect(set.contains(const FluentTextSpan('a')), isTrue);
      expect(set.contains(const FluentTextSpan('c')), isFalse);
    });

    test('markup spans can be Map keys', () {
      const key1 = FluentMarkupSpan(tag: 'bold', attrs: {'k': 'v'});
      const key2 = FluentMarkupSpan(tag: 'bold', attrs: {'k': 'v'});
      final map = <FluentSpan, int>{key1: 1};
      expect(map[key2], 1);
    });
  });

  group('FluentMarkupSpan — toString', () {
    test('self-closing format for empty children', () {
      const span = FluentMarkupSpan(tag: 'br');
      expect(span.toString(), 'FluentMarkupSpan(<br/>)');
    });

    test('renders children inline', () {
      const span = FluentMarkupSpan(
        tag: 'bold',
        children: [FluentTextSpan('hi')],
      );
      expect(
        span.toString(),
        'FluentMarkupSpan(<bold>FluentTextSpan("hi")</bold>)',
      );
    });

    test('renders attrs', () {
      const span = FluentMarkupSpan(
        tag: 'a',
        attrs: {'href': '/help'},
        children: [FluentTextSpan('go')],
      );
      expect(
        span.toString(),
        'FluentMarkupSpan(<a href="/help">FluentTextSpan("go")</a>)',
      );
    });
  });
}
