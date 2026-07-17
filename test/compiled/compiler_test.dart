import 'package:fluent_bundle/src/compiled/compiled_expression.dart';
import 'package:fluent_bundle/src/compiled/compiled_pattern.dart';
import 'package:fluent_bundle/src/compiled/compiler.dart';
import 'package:fluent_bundle/src/syntax/parser/parser.dart';
import 'package:test/test.dart';

void main() {
  final parser = FluentParser(
    options: const FluentParserOptions(withSpans: false),
  );
  final compiler = Compiler();

  CompilationResult compile(String source) =>
      compiler.compile(parser.parse(source));

  group('Compiler — entries', () {
    test('compiles a single message with a literal value', () {
      final r = compile('hello = Hi there.\n');
      expect(r.messages.keys, contains('hello'));
      expect(r.messages, hasLength(1));
      expect(r.terms, isEmpty);
      expect(r.junk, isEmpty);
    });

    test('skips standalone comments', () {
      final r = compile(
        '# Header\n'
        'hello = Hi.\n'
        '## Group\n'
        'world = World.\n',
      );
      expect(r.messages.keys, containsAll(['hello', 'world']));
    });

    test('preserves Junk entries on the side', () {
      final r = compile(
        'good = ok.\n'
        'broken-thing\n'
        'another = ok.\n',
      );
      expect(r.messages.keys, containsAll(['good', 'another']));
      expect(r.junk, hasLength(1));
    });

    test('compiles a term with attributes', () {
      final r = compile(
        '-brand = Acme\n'
        '    .full = Acme Corp.\n'
        '    .short = Acme\n',
      );
      final brand = r.terms['brand']!;
      expect(brand.attributes.keys, containsAll(['full', 'short']));
      expect(brand.value, isA<CompiledStringPattern>());
    });
  });

  group('Compiler — pattern lowering', () {
    test('text-only pattern lowers to CompiledStringPattern', () {
      final r = compile('m = Hello world.\n');
      final p = r.messages['m']!.value;
      expect(p, isA<CompiledStringPattern>());
      expect((p as CompiledStringPattern).value, 'Hello world.');
    });

    test('pattern with placeable lowers to CompiledComplexPattern', () {
      final r = compile(
        r'm = Hi { $name }!'
        '\n',
      );
      final p = r.messages['m']!.value;
      expect(p, isA<CompiledComplexPattern>());
      final elements = (p as CompiledComplexPattern).elements;
      expect(elements, hasLength(3));
      expect(elements[0], isA<CompiledTextElement>());
      expect((elements[0] as CompiledTextElement).value, 'Hi ');
      expect(elements[1], isA<CompiledPlaceable>());
      expect(
        (elements[1] as CompiledPlaceable).expression,
        isA<CompiledVariableReference>(),
      );
      expect(elements[2], isA<CompiledTextElement>());
    });

    test('value-less message has null value', () {
      final r = compile(
        'm =\n'
        '    .label = X\n',
      );
      final m = r.messages['m']!;
      expect(m.value, isNull);
      expect(m.attributes.keys, contains('label'));
    });

    test('multiple text elements concatenate', () {
      // A multi-line pattern produces multiple TextElements at the syntax
      // layer (one per line + dedent indent). The compiler concatenates
      // them when there are no placeables.
      final r = compile('m =\n    line one\n    line two\n');
      final p = r.messages['m']!.value;
      expect(p, isA<CompiledStringPattern>());
      expect((p as CompiledStringPattern).value, 'line one\nline two');
    });
  });

  group('Compiler — expression lowering', () {
    test('string literal expression', () {
      final r = compile('m = { "x" }\n');
      final expr =
          ((r.messages['m']!.value as CompiledComplexPattern).elements.single
                  as CompiledPlaceable)
              .expression;
      expect(expr, isA<CompiledStringLiteral>());
      expect((expr as CompiledStringLiteral).value, 'x');
    });

    test('number literal expression preserves precision', () {
      final r = compile('m = { 3.14 }\n');
      final expr =
          ((r.messages['m']!.value as CompiledComplexPattern).elements.single
                  as CompiledPlaceable)
              .expression;
      expect(expr, isA<CompiledNumberLiteral>());
      final n = expr as CompiledNumberLiteral;
      expect(n.value, '3.14');
      expect(n.precision, 2);
    });

    test('variable reference', () {
      final r = compile(
        r'm = { $name }'
        '\n',
      );
      final expr =
          ((r.messages['m']!.value as CompiledComplexPattern).elements.single
                  as CompiledPlaceable)
              .expression;
      expect((expr as CompiledVariableReference).name, 'name');
    });

    test('message reference + attribute', () {
      final r = compile('m = { greet.title }\n');
      final expr =
          ((r.messages['m']!.value as CompiledComplexPattern).elements.single
                  as CompiledPlaceable)
              .expression;
      expect((expr as CompiledMessageReference).name, 'greet');
      expect(expr.attribute, 'title');
    });

    test('term reference with named arg', () {
      final r = compile('m = { -brand(case: "vocative") }\n');
      final expr =
          ((r.messages['m']!.value as CompiledComplexPattern).elements.single
                  as CompiledPlaceable)
              .expression;
      final t = expr as CompiledTermReference;
      expect(t.name, 'brand');
      expect(t.attribute, isNull);
      expect(t.arguments, isNotNull);
      expect(t.arguments!.named['case'], isA<CompiledStringLiteral>());
      expect(
        (t.arguments!.named['case']! as CompiledStringLiteral).value,
        'vocative',
      );
    });

    test('function reference with positional + named', () {
      final r = compile(
        r'm = { NUMBER($n, style: "currency", currency: "USD") }'
        '\n',
      );
      final expr =
          ((r.messages['m']!.value as CompiledComplexPattern).elements.single
                  as CompiledPlaceable)
              .expression;
      final f = expr as CompiledFunctionReference;
      expect(f.name, 'NUMBER');
      expect(f.arguments.positional, hasLength(1));
      expect(f.arguments.positional.first, isA<CompiledVariableReference>());
      expect(f.arguments.named.keys, containsAll(['style', 'currency']));
    });
  });

  group('Compiler — select expression lowering', () {
    test('basic select with default index recorded', () {
      final r = compile(
        'm = { \$count ->\n'
        '    [one] One.\n'
        '   *[other] Many.\n'
        '}\n',
      );
      final expr =
          ((r.messages['m']!.value as CompiledComplexPattern).elements.single
                  as CompiledPlaceable)
              .expression;
      final sel = expr as CompiledSelectExpression;
      expect(sel.variants, hasLength(2));
      expect(sel.defaultIndex, 1);
      // Identifier keys are compiled to CompiledStringLiteral so the resolver
      // matches them through the same path as any other expression.
      expect((sel.variants[0].key as CompiledStringLiteral).value, 'one');
      expect((sel.variants[1].key as CompiledStringLiteral).value, 'other');
    });

    test('numeric variant key compiles to CompiledNumberLiteral', () {
      final r = compile(
        'm = { \$n ->\n'
        '    [0] zero\n'
        '    [42] forty-two\n'
        '   *[other] many\n'
        '}\n',
      );
      final sel =
          ((r.messages['m']!.value as CompiledComplexPattern).elements.single
                      as CompiledPlaceable)
                  .expression
              as CompiledSelectExpression;
      expect((sel.variants[0].key as CompiledNumberLiteral).value, '0');
      expect((sel.variants[1].key as CompiledNumberLiteral).value, '42');
      expect((sel.variants[2].key as CompiledStringLiteral).value, 'other');
    });

    test('default index is 0 when default is the first variant', () {
      final r = compile(
        'm = { \$x ->\n'
        '   *[a] alpha\n'
        '    [b] bravo\n'
        '}\n',
      );
      final sel =
          ((r.messages['m']!.value as CompiledComplexPattern).elements.single
                      as CompiledPlaceable)
                  .expression
              as CompiledSelectExpression;
      expect(sel.defaultIndex, 0);
    });

    test('nested select inside variant lowers correctly', () {
      final r = compile(
        'm = { \$tier ->\n'
        '    [pro] { \$count ->\n'
        '        [one] 1 pro\n'
        '       *[other] many pro\n'
        '    }\n'
        '   *[free] free\n'
        '}\n',
      );
      final outer =
          ((r.messages['m']!.value as CompiledComplexPattern).elements.single
                      as CompiledPlaceable)
                  .expression
              as CompiledSelectExpression;
      final proVariant = outer.variants[0];
      expect((proVariant.key as CompiledStringLiteral).value, 'pro');
      // pro variant's value is itself a complex pattern wrapping a select.
      final proPattern = proVariant.value as CompiledComplexPattern;
      final innerExpr =
          (proPattern.elements.single as CompiledPlaceable).expression;
      expect(innerExpr, isA<CompiledSelectExpression>());
    });
  });
}
