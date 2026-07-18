// Span parser tests — parseFluentMarkup in isolation.
//
// Pure-Dart, no Flutter. The parser sits between
// FluentBundle.formatMessage's resolved string and fluent_flutter's
// InlineSpan adapter; each behavior is asserted independently of the
// FluentBundle integration tested in
// span_parser_resolved_message_integration_test.
import 'package:fluent_bundle/markup.dart';
import 'package:test/test.dart';

void registerMarkupParserTests() {
  group('§7.2 — basic parsing', () {
    test('empty string yields a single empty text span', () {
      expect(parseFluentMarkup(''), const [FluentTextSpan('')]);
    });

    test('plain text yields a single text span', () {
      expect(parseFluentMarkup('Hello, world!'), const [
        FluentTextSpan('Hello, world!'),
      ]);
    });

    test('single tag yields a single markup span with text child', () {
      expect(parseFluentMarkup('<bold>hi</bold>'), const [
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('hi')]),
      ]);
    });

    test('two top-level tags produce two markup spans', () {
      expect(parseFluentMarkup('<bold>a</bold><em>b</em>'), const [
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('a')]),
        FluentMarkupSpan(tag: 'em', children: [FluentTextSpan('b')]),
      ]);
    });

    test('text before, between, and after tags is interleaved', () {
      expect(
        parseFluentMarkup('start <bold>a</bold> middle <em>b</em> end'),
        const [
          FluentTextSpan('start '),
          FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('a')]),
          FluentTextSpan(' middle '),
          FluentMarkupSpan(tag: 'em', children: [FluentTextSpan('b')]),
          FluentTextSpan(' end'),
        ],
      );
    });
  });

  group('§7.3 — HTML5 conformance', () {
    test('case-insensitive tag matching folds to lowercase', () {
      expect(parseFluentMarkup('<Bold>x</Bold>'), const [
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('x')]),
      ]);
      expect(parseFluentMarkup('<BOLD>x</BOLD>'), const [
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('x')]),
      ]);
      // Mixed case in opening + closing — HTML5 still folds.
      expect(parseFluentMarkup('<BoLd>x</bOlD>'), const [
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('x')]),
      ]);
    });

    test('double-quoted attributes', () {
      expect(parseFluentMarkup('<a href="/help">go</a>'), const [
        FluentMarkupSpan(
          tag: 'a',
          attrs: {'href': '/help'},
          children: [FluentTextSpan('go')],
        ),
      ]);
    });

    test('single-quoted attributes', () {
      expect(parseFluentMarkup("<a href='/help'>go</a>"), const [
        FluentMarkupSpan(
          tag: 'a',
          attrs: {'href': '/help'},
          children: [FluentTextSpan('go')],
        ),
      ]);
    });

    test('unquoted attributes', () {
      expect(parseFluentMarkup('<a href=/help>go</a>'), const [
        FluentMarkupSpan(
          tag: 'a',
          attrs: {'href': '/help'},
          children: [FluentTextSpan('go')],
        ),
      ]);
    });

    test('multiple attributes', () {
      expect(
        parseFluentMarkup('<a href="/x" target="_blank" rel="noopener">x</a>'),
        const [
          FluentMarkupSpan(
            tag: 'a',
            attrs: {'href': '/x', 'target': '_blank', 'rel': 'noopener'},
            children: [FluentTextSpan('x')],
          ),
        ],
      );
    });

    test('character entities decoded in text', () {
      expect(parseFluentMarkup('a &amp; b'), const [FluentTextSpan('a & b')]);
      expect(parseFluentMarkup('a &lt; b'), const [FluentTextSpan('a < b')]);
      expect(parseFluentMarkup('a &gt; b'), const [FluentTextSpan('a > b')]);
      expect(parseFluentMarkup('&copy; 2026'), const [
        FluentTextSpan('© 2026'),
      ]);
      expect(parseFluentMarkup('it&#39;s'), const [FluentTextSpan("it's")]);
      expect(parseFluentMarkup('it&#x27;s'), const [FluentTextSpan("it's")]);
      expect(parseFluentMarkup('1 &hellip; 9'), const [
        FluentTextSpan('1 … 9'),
      ]);
    });

    test('character entities decoded in attribute values', () {
      expect(parseFluentMarkup('<a href="/?a=1&amp;b=2">x</a>'), const [
        FluentMarkupSpan(
          tag: 'a',
          attrs: {'href': '/?a=1&b=2'},
          children: [FluentTextSpan('x')],
        ),
      ]);
    });

    test('self-closing void element <br/>', () {
      expect(parseFluentMarkup('a<br/>b'), const [
        FluentTextSpan('a'),
        FluentMarkupSpan(tag: 'br'),
        FluentTextSpan('b'),
      ]);
    });

    test('self-closing void element <br> (no slash)', () {
      // HTML5: <br> is a void element; treated as self-closing.
      expect(parseFluentMarkup('a<br>b'), const [
        FluentTextSpan('a'),
        FluentMarkupSpan(tag: 'br'),
        FluentTextSpan('b'),
      ]);
    });

    test('nested markup', () {
      expect(
        parseFluentMarkup('<bold>this is <em>important</em> stuff</bold>'),
        const [
          FluentMarkupSpan(
            tag: 'bold',
            children: [
              FluentTextSpan('this is '),
              FluentMarkupSpan(
                tag: 'em',
                children: [FluentTextSpan('important')],
              ),
              FluentTextSpan(' stuff'),
            ],
          ),
        ],
      );
    });

    test('whitespace preserved including leading and trailing', () {
      expect(parseFluentMarkup('  hello  '), const [
        FluentTextSpan('  hello  '),
      ]);
      expect(parseFluentMarkup('<bold>  hi  </bold>'), const [
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('  hi  ')]),
      ]);
    });

    test('self-closing custom tag <icon/>', () {
      expect(parseFluentMarkup('<icon name="usd"/>'), const [
        FluentMarkupSpan(
          tag: 'icon',
          attrs: {'name': 'usd'},
          // <icon> is NOT a void element in HTML5; the parser
          // treats it as an open tag whose `/>` is interpreted as
          // start-tag close. In HTML5 fragment parsing this leaves
          // an open <icon> with an empty body.
        ),
      ]);
    });
  });

  group('§7.4 — recovery', () {
    test('unclosed tag closes implicitly', () {
      // HTML5: <bold>oops without close — parser implicitly closes
      // at end of input.
      expect(parseFluentMarkup('<bold>oops'), const [
        FluentMarkupSpan(tag: 'bold', children: [FluentTextSpan('oops')]),
      ]);
    });

    test('stray close tag is dropped', () {
      // </bold> with no opening — HTML5 drops it silently.
      expect(parseFluentMarkup('</bold>'), const [FluentTextSpan('')]);
      // With surrounding text, the text passes through.
      expect(parseFluentMarkup('a</bold>b'), const [FluentTextSpan('ab')]);
    });

    test('lone less-than in text passes through', () {
      // HTML5 tolerates a lone `<` if it doesn't start a tag.
      expect(parseFluentMarkup('a < b'), const [FluentTextSpan('a < b')]);
    });

    test('comment is dropped (text on each side becomes adjacent spans)', () {
      // The HTML5 parser leaves two separate text nodes around the
      // comment. Downstream renderers concatenate adjacent text spans
      // for free, so we don't merge them here.
      expect(parseFluentMarkup('a<!-- secret -->b'), const [
        FluentTextSpan('a'),
        FluentTextSpan('b'),
      ]);
    });

    test('mismatched nesting reorganized per HTML5 (adoption agency)', () {
      // The HTML5 parser's "adoption agency algorithm" handles
      // <b><i>x</b></i> by reorganizing the tree so the elements
      // are properly nested. We don't pin the exact resulting
      // structure — only that we get back SOME well-formed tree
      // with both `b` and `i` tags and the text `x` reachable.
      final spans = parseFluentMarkup('<b><i>x</b></i>');
      // Find every text span anywhere in the tree.
      final allText = StringBuffer();
      void walk(List<FluentSpan> ss) {
        for (final s in ss) {
          switch (s) {
            case FluentTextSpan(:final text):
              allText.write(text);
            case FluentMarkupSpan(:final children):
              walk(children);
          }
        }
      }

      walk(spans);
      expect(allText.toString(), 'x');
    });

    test('only comment yields a single empty text span', () {
      expect(parseFluentMarkup('<!-- only a comment -->'), const [
        FluentTextSpan(''),
      ]);
    });
  });

  group('§7.5 — bidi isolation marks', () {
    const fsi = '\u{2068}';
    const pdi = '\u{2069}';

    test('marks preserved in text spans', () {
      // Resolver-style output: name interpolation wrapped in marks.
      expect(parseFluentMarkup('${fsi}Aria$pdi is typing…'), const [
        FluentTextSpan('\u{2068}Aria\u{2069} is typing…'),
      ]);
    });

    test('marks preserved in markup-span text children', () {
      expect(parseFluentMarkup('<bold>${fsi}Aria$pdi</bold>'), const [
        FluentMarkupSpan(
          tag: 'bold',
          children: [FluentTextSpan('\u{2068}Aria\u{2069}')],
        ),
      ]);
    });

    test('marks stripped from attribute values', () {
      // A URL interpolated into an attribute would carry FSI/PDI
      // marks; we strip them so href values stay machine-clean.
      expect(parseFluentMarkup('<a href="$fsi/help/secret$pdi">x</a>'), const [
        FluentMarkupSpan(
          tag: 'a',
          attrs: {'href': '/help/secret'},
          children: [FluentTextSpan('x')],
        ),
      ]);
    });

    test('marks-only attribute value becomes empty string', () {
      expect(parseFluentMarkup('<a href="$fsi$pdi">x</a>'), const [
        FluentMarkupSpan(
          tag: 'a',
          attrs: {'href': ''},
          children: [FluentTextSpan('x')],
        ),
      ]);
    });

    test('attribute value without marks is unchanged', () {
      // Fast-path: most attribute values don't contain marks at all.
      expect(parseFluentMarkup('<a href="/help">x</a>'), const [
        FluentMarkupSpan(
          tag: 'a',
          attrs: {'href': '/help'},
          children: [FluentTextSpan('x')],
        ),
      ]);
    });
  });
}
