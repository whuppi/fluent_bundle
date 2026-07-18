import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_bundle/markup.dart';
import 'package:test/test.dart';

void registerBundleChainTests() {
  // deCh is deliberately partial; de fills some gaps; en is the base.
  // de carries an uppercasing transform so output PROVES which member
  // formatted (the chain must format in the owner's context).
  FluentBundleChain chain() {
    final deCh = FluentBundle('de-CH', useIsolating: false)
      ..addResource('greet = Grüezi!');
    final de = FluentBundle(
      'de',
      useIsolating: false,
      transform: (text) => text.toUpperCase(),
    )..addResource('''
bye = tschüss
login = anmelden
    .title = willkommen zurück
''');
    final en = FluentBundle('en', useIsolating: false)..addResource(r'''
greet = Hello!
bye = Bye!
only-base = base only, { $name }
tagged = read <bold>this</bold>
''');
    return FluentBundleChain([deCh, de, en]);
  }

  group('FluentBundleChain — formatMessage', () {
    test('first member with the message wins', () {
      expect(chain().formatMessage('greet'), 'Grüezi!');
    });

    test('a miss falls through to the next member', () {
      // Formatted by `de` — its transform proves the owner ran it.
      expect(chain().formatMessage('bye'), 'TSCHÜSS');
    });

    test('falls all the way to the base', () {
      expect(
        chain().formatMessage('only-base', args: {'name': 'Aria'}),
        'base only, Aria',
      );
    });

    test('attribute formats in the owning member', () {
      expect(
        chain().formatMessage('login', attribute: 'title'),
        'WILLKOMMEN ZURÜCK',
      );
    });

    test('attribute missing on the owner records there — no fall-through', () {
      final errors = <FluentError>[];
      final out = chain().formatMessage(
        'login',
        attribute: 'nope',
        errors: errors,
      );
      expect(out, 'login.nope');
      expect(errors.single, isA<FluentReferenceError>());
    });

    test('id no member has behaves like a plain bundle miss', () {
      final errors = <FluentError>[];
      expect(chain().formatMessage('ghost', errors: errors), 'ghost');
      expect(errors.single, isA<FluentReferenceError>());
    });
  });

  group('FluentBundleChain — lookup surface', () {
    test('hasMessage sees every member', () {
      final c = chain();
      expect(c.hasMessage('greet'), isTrue);
      expect(c.hasMessage('only-base'), isTrue);
      expect(c.hasMessage('ghost'), isFalse);
    });

    test('locales flatten in chain order, deduplicated', () {
      expect(chain().locales, ['de-CH', 'de', 'en']);
    });

    test('parseJunk aggregates the members', () {
      final bad = FluentBundle('en')..addResource('0bad = nope');
      final c = FluentBundleChain([bad, FluentBundle('en')]);
      expect(c.parseJunk, hasLength(1));
    });

    test('getMessage returns the owning member\'s message', () {
      final c = chain();
      expect(c.getMessage('bye'), isNotNull);
      expect(c.getMessage('ghost'), isNull);
    });
  });

  group('FluentBundleChain — formatPattern', () {
    test('formats a getMessage pattern in the owning member', () {
      final c = chain();
      final pattern = c.getMessage('bye')!.value!;
      // Uppercased — proves `de` (the owner) formatted, not the chain's
      // own defaults.
      expect(c.formatPattern(pattern), 'TSCHÜSS');
    });

    test('attribute patterns are owned too', () {
      final c = chain();
      final pattern = c.getMessage('login')!.attributes['title']!;
      expect(c.formatPattern(pattern), 'WILLKOMMEN ZURÜCK');
    });

    test('a foreign pattern throws instead of guessing a locale', () {
      final foreign = FluentBundle('en')..addResource('x = y');
      final pattern = foreign.getMessage('x')!.value!;
      expect(() => chain().formatPattern(pattern), throwsStateError);
    });
  });

  group('FluentBundleChain — read-only view', () {
    test('addResource throws', () {
      expect(() => chain().addResource('x = y'), throwsUnsupportedError);
    });

    test('the members list is unmodifiable', () {
      expect(() => chain().bundles.clear(), throwsUnsupportedError);
    });

    test('an empty chain is a construction bug', () {
      expect(() => FluentBundleChain([]), throwsA(isA<AssertionError>()));
    });
  });

  group('FluentBundleChain — markup extension chains for free', () {
    test('formatMessageAsSpans resolves through the fallback walk', () {
      final spans = chain().formatMessageAsSpans('tagged');
      expect(spans, const [
        FluentTextSpan('read '),
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('this')]),
      ]);
    });
  });
}
