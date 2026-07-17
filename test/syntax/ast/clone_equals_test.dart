import 'package:fluent_bundle/src/syntax/ast/ast.dart';
import 'package:fluent_bundle/src/syntax/parser/parser.dart';
import 'package:test/test.dart';

void main() {
  final parser = FluentParser(
    options: const FluentParserOptions(withSpans: true),
  );
  Resource parse(String source) => parser.parse(source);

  group('clone() roundtrip — every node type equals its clone', () {
    test('Identifier', () {
      const a = Identifier('foo', span: Span(0, 3));
      final b = a.clone();
      expect(a.equals(b), isTrue);
      expect(identical(a, b), isFalse);
    });

    test('StringLiteral', () {
      const a = StringLiteral('hello', span: Span(0, 7));
      final b = a.clone();
      expect(a.equals(b), isTrue);
    });

    test('NumberLiteral', () {
      const a = NumberLiteral('3.14', 2, span: Span(0, 4));
      final b = a.clone();
      expect(a.equals(b), isTrue);
    });

    test('TextElement', () {
      const a = TextElement('Hello', span: Span(0, 5));
      final b = a.clone();
      expect(a.equals(b), isTrue);
    });

    test('Pattern + Placeable + StringLiteralExpression', () {
      final r = parse('m = Hi { "world" }!\n');
      final a = (r.body.first as Message).value!;
      final b = a.clone();
      expect(a.equals(b), isTrue);
      expect(identical(a, b), isFalse);
      expect(identical(a.elements.first, b.elements.first), isFalse);
    });

    test('Message with attributes + comment', () {
      final r = parse(
        '# Comment\n'
        'greeting = Hi\n'
        '    .label = Greeting\n'
        '    .access = G\n',
      );
      final a = r.body.first as Message;
      final b = a.clone();
      expect(a.equals(b), isTrue);
    });

    test('Term with attributes', () {
      final r = parse('-brand = Acme\n    .full = Acme Corp.\n');
      final a = r.body.first as Term;
      final b = a.clone();
      expect(a.equals(b), isTrue);
    });

    test('Comment (each level)', () {
      for (final level in CommentLevel.values) {
        final c = Comment(level: level, content: 'hi', span: const Span(0, 4));
        expect(c.equals(c.clone()), isTrue);
      }
    });

    test('Junk', () {
      const a = Junk(content: 'broken =', span: Span(0, 8));
      final b = a.clone();
      expect(a.equals(b), isTrue);
    });

    test('VariableReference', () {
      final r = parse(
        r'm = { $name }'
        '\n',
      );
      final placeable =
          (r.body.first as Message).value!.elements
              .whereType<Placeable>()
              .first;
      final a = placeable.expression as VariableReference;
      final b = a.clone();
      expect(a.equals(b), isTrue);
    });

    test('MessageReference with attribute', () {
      final r = parse('m = { greeting.title }\n');
      final placeable =
          (r.body.first as Message).value!.elements
              .whereType<Placeable>()
              .first;
      final a = placeable.expression as MessageReference;
      final b = a.clone();
      expect(a.equals(b), isTrue);
      expect(b.attribute, isNotNull);
      expect(b.attribute!.name, 'title');
    });

    test('TermReference with arguments (no attribute)', () {
      // `-term(...)` is valid in placeable position. `-term.attr(...)` is
      // NOT (term attributes can only appear as select-expression
      // selectors per spec rule E0019), so the args-with-attr shape is
      // exercised in the select-expression test below.
      final r = parse('m = { -brand(case: "vocative") }\n');
      final placeable =
          (r.body.first as Message).value!.elements
              .whereType<Placeable>()
              .first;
      final a = placeable.expression as TermReference;
      final b = a.clone();
      expect(a.equals(b), isTrue);
      expect(b.arguments, isNotNull);
    });

    test('TermReference with attribute as a select-expression selector', () {
      final r = parse(
        'm = { -brand.gender ->\n'
        '   *[neuter] it\n'
        '}\n',
      );
      final placeable =
          (r.body.first as Message).value!.elements
              .whereType<Placeable>()
              .first;
      final select = placeable.expression as SelectExpression;
      final a = select.selector as TermReference;
      final b = a.clone();
      expect(a.equals(b), isTrue);
      expect(b.attribute, isNotNull);
      expect(b.attribute!.name, 'gender');
    });

    test('FunctionReference with mixed args', () {
      final r = parse(
        r'm = { NUMBER($n, style: "currency") }'
        '\n',
      );
      final placeable =
          (r.body.first as Message).value!.elements
              .whereType<Placeable>()
              .first;
      final a = placeable.expression as FunctionReference;
      final b = a.clone();
      expect(a.equals(b), isTrue);
    });

    test('SelectExpression with multiple variants', () {
      final r = parse(
        'm = { \$count ->\n'
        '    [one] One.\n'
        '   *[other] Many.\n'
        '}\n',
      );
      final placeable =
          (r.body.first as Message).value!.elements
              .whereType<Placeable>()
              .first;
      final a = placeable.expression as SelectExpression;
      final b = a.clone();
      expect(a.equals(b), isTrue);
      expect(b.defaultVariant.isDefault, isTrue);
    });

    test('Resource — full document equals its clone', () {
      final r = parse(
        '# Header\n'
        'hello = Hi { \$name }!\n'
        '    .label = Greeting\n'
        '\n'
        '-brand = Acme\n',
      );
      final clone = r.clone();
      expect(r.equals(clone), isTrue);
    });
  });

  group('equals() — span comparison contract', () {
    test('span differences are ignored by default', () {
      const a = Identifier('foo', span: Span(0, 3));
      const b = Identifier('foo', span: Span(99, 102));
      expect(a.equals(b), isTrue);
    });

    test('ignoreSpans: false makes span differences fail equality', () {
      const a = Identifier('foo', span: Span(0, 3));
      const b = Identifier('foo', span: Span(99, 102));
      expect(a.equals(b, ignoreSpans: false), isFalse);
    });

    test('ignoreSpans: false with matching spans still equal', () {
      const a = Identifier('foo', span: Span(0, 3));
      const b = Identifier('foo', span: Span(0, 3));
      expect(a.equals(b, ignoreSpans: false), isTrue);
    });

    test('ignoreSpans: false with one null span is unequal', () {
      const a = Identifier('foo', span: Span(0, 3));
      const b = Identifier('foo');
      expect(a.equals(b, ignoreSpans: false), isFalse);
    });

    test('ignoreSpans: false with both null spans is equal', () {
      const a = Identifier('foo');
      const b = Identifier('foo');
      expect(a.equals(b, ignoreSpans: false), isTrue);
    });

    test('ignoreSpans: false propagates through nested equality', () {
      // Outer identifier spans match; inner literal spans differ. Strict
      // mode must catch the inner mismatch.
      const a = NumberLiteralExpression(
        NumberLiteral('1', 0, span: Span(0, 1)),
        span: Span(0, 1),
      );
      const b = NumberLiteralExpression(
        NumberLiteral('1', 0, span: Span(50, 51)),
        span: Span(0, 1),
      );
      expect(a.equals(b), isTrue);
      expect(a.equals(b, ignoreSpans: false), isFalse);
    });

    test('content differences are NOT ignored', () {
      const a = Identifier('foo');
      const b = Identifier('bar');
      expect(a.equals(b), isFalse);
    });

    test('NumberLiteral precision is part of equality', () {
      const a = NumberLiteral('1', 0);
      const b = NumberLiteral('1.0', 1);
      // Both parse to 1.0 numerically, but the source-precision differs,
      // and Fluent keeps that distinction. They are NOT equal.
      expect(a.equals(b), isFalse);
    });

    test('cross-type comparison returns false (sealed dispatch)', () {
      const a = Identifier('x');
      const b = StringLiteral('x');
      expect(a.equals(b), isFalse);
      expect(b.equals(a), isFalse);
    });

    test('Variant default flag is part of equality', () {
      final r = parse('m = { \$x ->\n    [a] x\n   *[b] y\n}\n');
      final placeable =
          (r.body.first as Message).value!.elements
              .whereType<Placeable>()
              .first;
      final sel = placeable.expression as SelectExpression;
      final v0 = sel.variants[0]; // not default
      final v1 = sel.variants[1]; // default
      expect(v0.equals(v1), isFalse);
    });
  });
}
