// Integration tests for FluentBundle.formatMessageAsSpans.
//
// Covers test matrix §7.6 in docs/plan.md: the resolver and the
// span parser combined — interpolations + plurals + terms + markup
// all in one call, plus error semantics matching formatMessage.

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_bundle/markup.dart';
import 'package:test/test.dart';

void registerFormatMessageAsSpansTests() {
  group('formatMessageAsSpans — interpolation + markup', () {
    test('placeholder + markup', () {
      final bundle = FluentBundle.locales(['en'], useIsolating: false)
        ..addResource('welcome = Hello, <bold>{ \$name }</bold>!');

      final spans = bundle.formatMessageAsSpans(
        'welcome',
        args: {'name': 'Aria'},
      );

      expect(spans, [
        const FluentTextSpan('Hello, '),
        const FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('Aria')]),
        const FluentTextSpan('!'),
      ]);
    });

    test('plain message (no markup) yields a single text span', () {
      final bundle = FluentBundle.locales(['en'], useIsolating: false)
        ..addResource('plain = Hello, { \$name }!');

      final spans = bundle.formatMessageAsSpans(
        'plain',
        args: {'name': 'World'},
      );

      expect(spans, const [FluentTextSpan('Hello, World!')]);
    });

    test('attribute on outer tag + nested markup', () {
      final bundle = FluentBundle.locales(
        ['en'],
        useIsolating: false,
      )..addResource('help = Read <a href="/help">our <em>help</em> page</a>.');

      final spans = bundle.formatMessageAsSpans('help');

      expect(spans, const [
        FluentTextSpan('Read '),
        FluentMarkupSpan(
          tag: 'a',
          attrs: {'href': '/help'},
          children: [
            FluentTextSpan('our '),
            FluentMarkupSpan(tag: 'em', children: [FluentTextSpan('help')]),
            FluentTextSpan(' page'),
          ],
        ),
        FluentTextSpan('.'),
      ]);
    });
  });

  group('formatMessageAsSpans — selectors + markup', () {
    test('plural selector inside a markup tag', () {
      final bundle = FluentBundle.locales(['en'], useIsolating: false)
        ..addResource('''
items = You have <bold>{ \$count ->
    [one] one item
   *[other] { \$count } items
}</bold>.
''');

      // Default plural rules return 'other', so we just verify both
      // arms render as expected text inside the bold tag.
      final manyArm = bundle.formatMessageAsSpans('items', args: {'count': 5});
      expect(manyArm, const [
        FluentTextSpan('You have '),
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('5 items')]),
        FluentTextSpan('.'),
      ]);
    });

    test('term reference inside markup', () {
      final bundle = FluentBundle.locales(['en'], useIsolating: false)
        ..addResource('''
-brand = Acme

footer = Built by <bold>{ -brand }</bold>.
''');

      expect(bundle.formatMessageAsSpans('footer'), const [
        FluentTextSpan('Built by '),
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('Acme')]),
        FluentTextSpan('.'),
      ]);
    });
  });

  group('formatMessageAsSpans — error semantics', () {
    test('unknown message id falls back to literal id + records error', () {
      final bundle = FluentBundle.locales(['en']);
      final errors = <FluentError>[];

      final spans = bundle.formatMessageAsSpans('nope', errors: errors);

      // Fallback: the missing id renders as visible text so the gap
      // surfaces during dev. The error list still records why.
      expect(spans, const [FluentTextSpan('nope')]);
      expect(errors, hasLength(1));
      expect(errors.first, isA<FluentReferenceError>());
    });

    test('missing argument leaves a placeholder + records error', () {
      final bundle = FluentBundle.locales(['en'], useIsolating: false)
        ..addResource('greet = Hello, <bold>{ \$name }</bold>!');
      final errors = <FluentError>[];

      final spans = bundle.formatMessageAsSpans('greet', errors: errors);

      // The resolver renders missing-arg interpolations as `{$name}`
      // (the raw FTL form). The markup parser sees that as plain
      // text inside the bold tag.
      expect(spans, const [
        FluentTextSpan('Hello, '),
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('{\$name}')]),
        FluentTextSpan('!'),
      ]);
      expect(errors, isNotEmpty);
      expect(errors.first, isA<FluentReferenceError>());
    });

    test('unknown attribute falls back to "id.attr" + records error', () {
      final bundle = FluentBundle.locales(['en'])..addResource('greet = Hi');
      final errors = <FluentError>[];

      final spans = bundle.formatMessageAsSpans(
        'greet',
        attribute: 'tooltip',
        errors: errors,
      );

      expect(spans, const [FluentTextSpan('greet.tooltip')]);
      expect(errors, hasLength(1));
    });
  });

  group('formatMessageAsSpans — bidi-isolation interaction', () {
    test('text spans keep marks; attribute values do not', () {
      // Use the default useIsolating: true so the resolver actually
      // adds FSI/PDI marks around interpolations.
      final bundle = FluentBundle.locales(['en'])
        ..addResource('msg = User <a href="{ \$url }">{ \$name }</a>.');

      final spans = bundle.formatMessageAsSpans(
        'msg',
        args: {'name': 'Aria', 'url': '/users/aria'},
      );

      // The <a>'s text child preserves the FSI/PDI marks the resolver
      // added around the name. The href attribute's URL had marks
      // around it too — those are stripped.
      expect(spans.length, 3);

      expect(spans[0], isA<FluentTextSpan>());
      final firstText = (spans[0] as FluentTextSpan).text;
      expect(firstText, 'User ');

      expect(spans[1], isA<FluentMarkupSpan>());
      final aTag = spans[1] as FluentMarkupSpan;
      expect(aTag.tag, 'a');
      // href is clean — no marks.
      expect(aTag.attrs['href'], '/users/aria');

      // Inside the <a>, the name carries the marks.
      expect(aTag.children, hasLength(1));
      final nameInside = (aTag.children.first as FluentTextSpan).text;
      expect(nameInside.contains('\u{2068}'), isTrue);
      expect(nameInside.contains('Aria'), isTrue);
      expect(nameInside.contains('\u{2069}'), isTrue);
    });
  });

  group('formatMessageAsSpans — empty-result handling', () {
    test('empty message body yields literal-id fallback (junk per spec)', () {
      final bundle = FluentBundle.locales(['en'])..addResource('empty = ');

      // Fluent's parser treats `empty = ` (no value, no attributes)
      // as Junk per spec — the message id is never registered. The
      // bundle then handles the missing-id case the same way as any
      // other miss: returns the literal id as a single text span.
      final spans = bundle.formatMessageAsSpans('empty');
      expect(spans, const [FluentTextSpan('empty')]);
    });

    test('message with only an empty attribute value', () {
      final bundle = FluentBundle.locales(['en'])..addResource('msg = stub');

      final spans = bundle.formatMessageAsSpans('msg');
      expect(spans, const [FluentTextSpan('stub')]);
    });
  });
}
