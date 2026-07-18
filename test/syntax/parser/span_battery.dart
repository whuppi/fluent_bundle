import 'package:fluent_bundle/src/syntax/ast/ast.dart';
import 'package:fluent_bundle/src/syntax/parser/parser.dart';
import 'package:test/test.dart';

void registerSpanTests() {
  Resource parseWithSpans(String source) => FluentParser(
    options: const FluentParserOptions(withSpans: true),
  ).parse(source);

  Resource parseWithoutSpans(String source) => FluentParser(
    options: const FluentParserOptions(withSpans: false),
  ).parse(source);

  group('Span — withSpans: true populates spans', () {
    test('Identifier carries the span of its name in source', () {
      const src = 'hello = world\n';
      final r = parseWithSpans(src);
      final m = r.body.first as Message;
      // The id is the bare identifier "hello" at the start.
      expect(m.id.span, isNotNull);
      expect(m.id.span!.start, 0);
      expect(m.id.span!.end, 5);
      expect(src.substring(m.id.span!.start, m.id.span!.end), 'hello');
    });

    test('Pattern span covers the value text', () {
      const src = 'm = Hello!\n';
      final r = parseWithSpans(src);
      final m = r.body.first as Message;
      final span = m.value!.span!;
      // The pattern starts at "Hello" (after `= ` skip) and ends before `\n`.
      expect(src.substring(span.start, span.end), contains('Hello!'));
    });

    test('TextElement and Placeable spans are non-overlapping', () {
      const src = 'm = Hi { "world" }!\n';
      final r = parseWithSpans(src);
      final m = r.body.first as Message;
      final elements = m.value!.elements;
      // 3 elements: "Hi ", { "world" }, "!"
      expect(elements, hasLength(3));
      final t1 = elements[0] as TextElement;
      final p = elements[1] as Placeable;
      final t2 = elements[2] as TextElement;
      // Spans are present on each.
      expect(t1.span, isNotNull);
      expect(p.span, isNotNull);
      expect(t2.span, isNotNull);
      // And in increasing source order, non-overlapping.
      expect(t1.span!.end, lessThanOrEqualTo(p.span!.start));
      expect(p.span!.end, lessThanOrEqualTo(t2.span!.start));
    });

    test('Placeable span includes the braces', () {
      const src = 'm = { "x" }\n';
      final r = parseWithSpans(src);
      final placeable =
          (r.body.first as Message).value!.elements
              .whereType<Placeable>()
              .first;
      final span = placeable.span!;
      expect(src[span.start], '{');
      expect(src[span.end - 1], '}');
    });

    test(r'VariableReference span covers the entire $name', () {
      const src =
          r'm = { $username }'
          '\n';
      final r = parseWithSpans(src);
      final placeable =
          (r.body.first as Message).value!.elements
              .whereType<Placeable>()
              .first;
      final v = placeable.expression as VariableReference;
      // Variable reference span starts AT the `$` and ends after the
      // identifier.
      final span = v.span!;
      expect(src.substring(span.start, span.end), r'$username');
    });

    test('NumberLiteral span covers digits and optional minus', () {
      const src = 'm = { -3.14 }\n';
      final r = parseWithSpans(src);
      final placeable =
          (r.body.first as Message).value!.elements
              .whereType<Placeable>()
              .first;
      final lit = (placeable.expression as NumberLiteralExpression).literal;
      expect(src.substring(lit.span!.start, lit.span!.end), '-3.14');
    });

    test('Attribute span includes the leading "."', () {
      const src = 'm = value\n    .label = X\n';
      final r = parseWithSpans(src);
      final m = r.body.first as Message;
      final attr = m.attributes.single;
      final span = attr.span!;
      expect(src[span.start], '.');
      // The end span covers through the attribute's value.
      expect(src.substring(span.start, span.end), contains('.label'));
    });

    test('Comment span starts at the leading "#"', () {
      const src = '# leading\nm = v\n';
      final r = parseWithSpans(src);
      final m = r.body.first as Message;
      final comment = m.comment!;
      expect(src[comment.span!.start], '#');
    });
  });

  group('Span — withSpans: false leaves every span null', () {
    test('every node in a complex resource has span == null', () {
      const src =
          '# Header\n'
          'hello = Hi { \$name }!\n'
          '    .label = Greeting\n'
          '\n'
          '-brand = Acme\n';
      final r = parseWithoutSpans(src);

      void checkAllNull(Object? node) {
        // Every AST node is a SyntaxNode; anything else has no span.
        if (node is! SyntaxNode) return;
        expect(
          node.span,
          isNull,
          reason: 'expected null span on ${node.runtimeType}',
        );
      }

      checkAllNull(r);
      for (final entry in r.body) {
        checkAllNull(entry);
        if (entry is Message) {
          checkAllNull(entry.id);
          checkAllNull(entry.value);
          checkAllNull(entry.comment);
          for (final el in entry.value?.elements ?? const []) {
            checkAllNull(el);
            if (el is Placeable) {
              checkAllNull(el.expression);
            }
          }
          for (final a in entry.attributes) {
            checkAllNull(a);
            checkAllNull(a.id);
            checkAllNull(a.value);
          }
        }
        if (entry is Term) {
          checkAllNull(entry.id);
          checkAllNull(entry.value);
        }
      }
    });
  });
}
