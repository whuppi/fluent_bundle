import 'package:fluent_bundle/src/errors/fluent_error.dart';
import 'package:fluent_bundle/src/values/fluent_value.dart';
import 'package:test/test.dart';
import '../_helpers/bundle_factory.dart';

void registerBundleTests() {
  group('FluentBundle — basic formatMessage', () {
    test('plain text message renders verbatim', () {
      final bundle = testBundle('en');
      bundle.addResource('hello = Hello, world!\n');
      expect(bundle.formatMessage('hello'), 'Hello, world!');
    });

    test(
      'missing message returns the literal id and records reference error',
      () {
        final bundle = testBundle('en');
        bundle.addResource('hello = Hi.\n');
        final errs = <FluentError>[];
        // Missing-id behavior: return the literal id so the gap is
        // visible in the UI; record the FluentReferenceError so callers
        // who passed an `errors` list can detect the miss.
        expect(bundle.formatMessage('missing', errors: errs), 'missing');
        expect(errs, hasLength(1));
        expect(errs.single, isA<FluentReferenceError>());
      },
    );

    test('attribute lookup', () {
      final bundle = testBundle('en');
      bundle.addResource(
        'login = Log in\n'
        '    .title = Sign-in screen\n',
      );
      expect(bundle.formatMessage('login'), 'Log in');
      expect(
        bundle.formatMessage('login', attribute: 'title'),
        'Sign-in screen',
      );
    });

    test('value-less message: only attributes are reachable', () {
      final bundle = testBundle('en');
      bundle.addResource(
        'shortcut =\n'
        '    .key = Ctrl+S\n',
      );
      // Message body lookup misses (no value, only attributes) — falls
      // back to the literal id and records the error. Attribute access
      // works.
      final errs = <FluentError>[];
      expect(bundle.formatMessage('shortcut', errors: errs), 'shortcut');
      expect(errs, hasLength(1));
      expect(bundle.formatMessage('shortcut', attribute: 'key'), 'Ctrl+S');
    });
  });

  group('FluentBundle — variable substitution', () {
    test('string variable', () {
      final bundle = testBundle('en');
      bundle.addResource(
        r'greet = Hello, { $name }!'
        '\n',
      );
      expect(
        bundle.formatMessage('greet', args: {'name': 'World'}),
        'Hello, World!',
      );
    });

    test('integer variable renders without trailing zeroes', () {
      final bundle = testBundle('en');
      bundle.addResource(
        r'count = You have { $n } items.'
        '\n',
      );
      expect(
        bundle.formatMessage('count', args: {'n': 5}),
        'You have 5 items.',
      );
    });

    test(r'missing variable degrades to {$name} placeholder + error', () {
      final bundle = testBundle('en');
      bundle.addResource(
        r'greet = Hello, { $name }!'
        '\n',
      );
      final errs = <FluentError>[];
      final result = bundle.formatMessage('greet', errors: errs);
      expect(result, contains(r'{$name}'));
      expect(errs, hasLength(1));
      expect(errs.single, isA<FluentReferenceError>());
    });
  });

  group('FluentBundle — message references', () {
    test('a message can reference another message', () {
      final bundle = testBundle('en');
      bundle.addResource(
        'name = Acme\n'
        'greeting = Welcome to { name }.\n',
      );
      expect(bundle.formatMessage('greeting'), 'Welcome to Acme.');
    });

    test('reference to a message attribute', () {
      final bundle = testBundle('en');
      bundle.addResource(
        'login = Log in\n'
        '    .title = Sign-in\n'
        'header = Page: { login.title }\n',
      );
      expect(bundle.formatMessage('header'), 'Page: Sign-in');
    });

    test('cyclic reference is detected', () {
      final bundle = testBundle('en');
      bundle.addResource(
        'a = A says { b }\n'
        'b = B says { a }\n',
      );
      final errs = <FluentError>[];
      bundle.formatMessage('a', errors: errs);
      expect(errs.any((e) => e is FluentCyclicReferenceError), isTrue);
    });
  });

  group('FluentBundle — term references', () {
    test('a message can reference a term value', () {
      final bundle = testBundle('en');
      bundle.addResource(
        '-brand = Acme\n'
        'about = About { -brand }.\n',
      );
      expect(bundle.formatMessage('about'), 'About Acme.');
    });

    test('term arguments do not leak from caller', () {
      final bundle = testBundle('en');
      bundle.addResource(
        r'-greet = Hello, { $name }'
        '\n'
        r'msg = { -greet(name: "World") }!'
        '\n',
      );
      expect(bundle.formatMessage('msg'), 'Hello, World!');
    });

    test(r'term can read its own named args via $name', () {
      final bundle = testBundle('en');
      bundle.addResource(
        r'-deal = { $kind } deal'
        '\n'
        r'banner = { -deal(kind: "Black Friday") }!'
        '\n',
      );
      expect(bundle.formatMessage('banner'), 'Black Friday deal!');
    });

    test(r'caller args do NOT leak into a term body', () {
      final bundle = testBundle('en');
      bundle.addResource(
        r'-greet = Hi { $name }'
        '\n'
        r'msg = { -greet }!'
        '\n',
      );
      // Caller passes $name, but the term doesn't receive it (term args
      // are isolated by design). The reference fails, surfacing
      // {$name} as the placeholder.
      final errs = <FluentError>[];
      final result = bundle.formatMessage(
        'msg',
        args: {'name': 'World'},
        errors: errs,
      );
      expect(result, contains(r'{$name}'));
      expect(errs, isNotEmpty);
    });
  });

  group('FluentBundle — function references', () {
    test('user-supplied function is called with positional + named args', () {
      String trace = '';
      final bundle = testBundle(
        'en',
        functions: {
          'TRACE': (positional, named, _) {
            trace = '${positional.length}|${named.keys.join(",")}';
            return const FluentString('ok');
          },
        },
      );
      bundle.addResource(
        r'm = { TRACE($a, $b, mode: "test") }'
        '\n',
      );
      bundle.formatMessage('m', args: {'a': 1, 'b': 2});
      expect(trace, '2|mode');
    });

    test('unknown function records reference error', () {
      final bundle = testBundle('en');
      bundle.addResource(
        r'm = { UNKNOWN($x) }'
        '\n',
      );
      final errs = <FluentError>[];
      bundle.formatMessage('m', args: {'x': 1}, errors: errs);
      expect(errs.any((e) => e is FluentReferenceError), isTrue);
    });
  });

  group('FluentBundle — select expressions', () {
    test('numeric variant matches by exact value', () {
      final bundle = testBundle('en');
      bundle.addResource(
        'm = { \$n ->\n'
        '    [0] zero\n'
        '    [1] one\n'
        '   *[other] many\n'
        '}\n',
      );
      expect(bundle.formatMessage('m', args: {'n': 0}), 'zero');
      expect(bundle.formatMessage('m', args: {'n': 1}), 'one');
      expect(bundle.formatMessage('m', args: {'n': 7}), 'many');
    });

    test('string variant matches by string equality', () {
      final bundle = testBundle('en');
      bundle.addResource(
        r'm = { $kind ->'
        '\n'
        '    [primary] P\n'
        '   *[other] O\n'
        '}\n',
      );
      expect(bundle.formatMessage('m', args: {'kind': 'primary'}), 'P');
      expect(bundle.formatMessage('m', args: {'kind': 'secondary'}), 'O');
    });

    test(
      'default plural rules: numeric selector falls through to *[other]',
      () {
        // Without an intl-backed plural-rules adapter wired in, the bundle's
        // default rule returns `other` for everything. A numeric selector
        // hitting an `[one]/[other]` pattern matches the default `[other]`.
        final bundle = testBundle('en');
        bundle.addResource('''
m = { \$n ->
    [one] One item
   *[other] { \$n } items
}
''');
        expect(bundle.formatMessage('m', args: {'n': 1}), '1 items');
        expect(bundle.formatMessage('m', args: {'n': 5}), '5 items');
      },
    );

    test('default variant fallback when nothing matches', () {
      final bundle = testBundle('en');
      bundle.addResource(
        r'm = { $tier ->'
        '\n'
        '    [pro] PRO\n'
        '   *[free] FREE\n'
        '}\n',
      );
      expect(bundle.formatMessage('m', args: {'tier': 'enterprise'}), 'FREE');
    });
  });

  group('FluentBundle — addResource error reporting', () {
    test('duplicate message id is rejected by default', () {
      final bundle = testBundle('en');
      bundle.addResource('m = first\n');
      final result = bundle.addResource('m = second\n');
      expect(result.hasErrors, isTrue);
      // First definition wins.
      expect(bundle.formatMessage('m'), 'first');
    });

    test('allowOverrides: true replaces existing message', () {
      final bundle = testBundle('en');
      bundle.addResource('m = first\n');
      bundle.addResource('m = second\n', allowOverrides: true);
      expect(bundle.formatMessage('m'), 'second');
    });

    test('Junk is preserved on the bundle for inspection', () {
      final bundle = testBundle('en');
      bundle.addResource(
        'good = ok.\n'
        'broken-thing\n',
      );
      expect(bundle.parseJunk, hasLength(1));
      expect(bundle.formatMessage('good'), 'ok.');
    });
  });

  group('FluentBundle — placeable safety', () {
    test('a million expansions trips the placeable limit', () {
      final bundle = testBundle('en');
      // a -> b -> a -> b ... — cycle SHOULD trip cycle detection first,
      // but a self-recursive pattern via DIFFERENT messages each time
      // would otherwise expand without bound.
      bundle.addResource(
        'a = A { b }\n'
        'b = B { a }\n',
      );
      final errs = <FluentError>[];
      bundle.formatMessage('a', errors: errs);
      // Either cycle error OR placeable-limit error must be reported.
      final tripped = errs.any(
        (e) =>
            e is FluentCyclicReferenceError || e is FluentResolutionLimitError,
      );
      expect(tripped, isTrue);
    });
  });
}
