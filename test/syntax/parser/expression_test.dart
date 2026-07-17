import 'package:fluent_bundle/src/errors/parse_error.dart';
import 'package:fluent_bundle/src/syntax/ast/ast.dart';
import 'package:fluent_bundle/src/syntax/parser/parser.dart';
import 'package:test/test.dart';

void main() {
  final parser = FluentParser(
    options: const FluentParserOptions(withSpans: false),
  );
  Resource parse(String source) => parser.parse(source);

  /// Read the value of a Message named `key`. Asserts the entry exists.
  Pattern messageValue(Resource r, String key) {
    final m =
        r.body.firstWhere(
              (e) => e is Message && e.id.name == key,
              orElse: () => throw StateError('No message named $key'),
            )
            as Message;
    return m.value!;
  }

  /// First placeable in the message's value, asserting one exists.
  Placeable firstPlaceable(Resource r, String key) {
    final v = messageValue(r, key);
    return v.elements.whereType<Placeable>().first;
  }

  group('NumberLiteralExpression', () {
    test('positive integer', () {
      final r = parse('m = { 42 }\n');
      final expr = firstPlaceable(r, 'm').expression as NumberLiteralExpression;
      expect(expr.literal.value, '42');
      expect(expr.literal.precision, 0);
    });

    test('negative integer', () {
      final r = parse('m = { -7 }\n');
      final expr = firstPlaceable(r, 'm').expression as NumberLiteralExpression;
      expect(expr.literal.value, '-7');
      expect(expr.literal.precision, 0);
    });

    test('decimal preserves precision', () {
      final r = parse('m = { 3.140 }\n');
      final expr = firstPlaceable(r, 'm').expression as NumberLiteralExpression;
      expect(expr.literal.value, '3.140');
      expect(expr.literal.precision, 3);
    });

    test('negative decimal', () {
      final r = parse('m = { -0.5 }\n');
      final expr = firstPlaceable(r, 'm').expression as NumberLiteralExpression;
      expect(expr.literal.value, '-0.5');
      expect(expr.literal.precision, 1);
    });

    test('toDouble parses correctly', () {
      final r = parse('m = { 2.5 }\n');
      final expr = firstPlaceable(r, 'm').expression as NumberLiteralExpression;
      expect(expr.literal.toDouble(), 2.5);
    });

    test('lone minus without digits is Junk', () {
      final r = parse('m = { - }\n');
      expect(r.body.first, isA<Junk>());
    });

    test('decimal point without fractional digits is Junk', () {
      final r = parse('m = { 3. }\n');
      expect(r.body.first, isA<Junk>());
    });
  });

  group('VariableReference', () {
    test('simple variable', () {
      final r = parse(
        r'm = Hello, { $name }!'
        '\n',
      );
      final expr = firstPlaceable(r, 'm').expression as VariableReference;
      expect(expr.id.name, 'name');
    });

    test('variable name with digits and dash', () {
      final r = parse(
        r'm = { $user-id-2 }'
        '\n',
      );
      final expr = firstPlaceable(r, 'm').expression as VariableReference;
      expect(expr.id.name, 'user-id-2');
    });

    test(r'$ without identifier is Junk', () {
      final r = parse('m = { \$ }\n');
      expect(r.body.first, isA<Junk>());
    });
  });

  group('MessageReference', () {
    test('bare message reference', () {
      final r = parse('m = See { greeting }!\n');
      final expr = firstPlaceable(r, 'm').expression as MessageReference;
      expect(expr.id.name, 'greeting');
      expect(expr.attribute, isNull);
    });

    test('message reference with attribute', () {
      final r = parse('m = { login.title }\n');
      final expr = firstPlaceable(r, 'm').expression as MessageReference;
      expect(expr.id.name, 'login');
      expect(expr.attribute?.name, 'title');
    });
  });

  group('TermReference', () {
    test('bare term reference', () {
      final r = parse('m = Welcome to { -brand }!\n');
      final expr = firstPlaceable(r, 'm').expression as TermReference;
      expect(expr.id.name, 'brand');
      expect(expr.attribute, isNull);
      expect(expr.arguments, isNull);
    });

    test('term reference with attribute in placeable position is rejected '
        '(E0019)', () {
      // Per Fluent spec, `-term.attr` in a plain placeable is illegal —
      // term attributes resolve to a Pattern and are only allowed as
      // select-expression selectors.
      final r = parse('m = { -brand.full }\n');
      expect(r.body.first, isA<Junk>());
    });

    test('term reference with attribute is reachable as a select selector', () {
      final r = parse(
        'm = { -brand.full ->\n'
        '   *[long] Long form\n'
        '}\n',
      );
      // Resource parses cleanly — the term-attr selector is the spec's
      // legitimate use site for `-term.attr`.
      expect(r.body.first, isA<Message>());
    });

    test('term reference with named arg', () {
      final r = parse('m = { -brand(case: "vocative") }\n');
      final expr = firstPlaceable(r, 'm').expression as TermReference;
      expect(expr.id.name, 'brand');
      expect(expr.arguments, isNotNull);
      expect(expr.arguments!.named, hasLength(1));
      expect(expr.arguments!.named.first.name.name, 'case');
      expect(
        (expr.arguments!.named.first.value as StringLiteral).value,
        'vocative',
      );
    });

    test('term reference with attribute AND call args in placeable position '
        'is rejected (E0019)', () {
      final r = parse('m = { -brand.short(formal: "yes") }\n');
      expect(r.body.first, isA<Junk>());
    });
  });

  group('FunctionReference', () {
    test('NUMBER with one positional arg', () {
      final r = parse(
        r'm = { NUMBER($n) }'
        '\n',
      );
      final expr = firstPlaceable(r, 'm').expression as FunctionReference;
      expect(expr.id.name, 'NUMBER');
      expect(expr.arguments.positional, hasLength(1));
      expect(expr.arguments.positional.first, isA<VariableReference>());
      expect(expr.arguments.named, isEmpty);
    });

    test('NUMBER with positional + named args', () {
      final r = parse(
        r'm = { NUMBER($n, style: "currency", currency: "USD") }'
        '\n',
      );
      final expr = firstPlaceable(r, 'm').expression as FunctionReference;
      expect(expr.arguments.positional, hasLength(1));
      expect(expr.arguments.named, hasLength(2));
      expect(expr.arguments.named[0].name.name, 'style');
      expect(
        (expr.arguments.named[0].value as StringLiteral).value,
        'currency',
      );
      expect(expr.arguments.named[1].name.name, 'currency');
      expect((expr.arguments.named[1].value as StringLiteral).value, 'USD');
    });

    test('callee name allows dashes and digits', () {
      final r = parse(
        r'm = { MY-FN-2($x) }'
        '\n',
      );
      final expr = firstPlaceable(r, 'm').expression as FunctionReference;
      expect(expr.id.name, 'MY-FN-2');
    });

    test('numeric named-arg value', () {
      final r = parse(
        r'm = { NUMBER($x, minimumFractionDigits: 2) }'
        '\n',
      );
      final expr = firstPlaceable(r, 'm').expression as FunctionReference;
      final arg = expr.arguments.named.first;
      expect(arg.name.name, 'minimumFractionDigits');
      expect((arg.value as NumberLiteral).value, '2');
    });

    test('lowercase-led name parses as MessageReference, not function', () {
      // `lower-fn(...)` is NOT a function call: function callees must start
      // with an uppercase letter. `(` cannot follow a message reference,
      // so the placeable is malformed and the entry becomes Junk.
      final r = parse('m = { lower-fn(x) }\n');
      expect(r.body.first, isA<Junk>());
    });

    test('positional arg after named is rejected as Junk', () {
      final r = parse(
        r'm = { NUMBER(style: "decimal", $n) }'
        '\n',
      );
      expect(r.body.first, isA<Junk>());
    });

    test('duplicate named arg is rejected as Junk', () {
      final r = parse(
        r'm = { NUMBER($n, style: "a", style: "b") }'
        '\n',
      );
      expect(r.body.first, isA<Junk>());
    });

    test('empty arg list', () {
      final r = parse('m = { FN() }\n');
      final expr = firstPlaceable(r, 'm').expression as FunctionReference;
      expect(expr.arguments.positional, isEmpty);
      expect(expr.arguments.named, isEmpty);
    });

    test('trailing comma allowed', () {
      final r = parse(
        r'm = { NUMBER($n, ) }'
        '\n',
      );
      final expr = firstPlaceable(r, 'm').expression as FunctionReference;
      expect(expr.arguments.positional, hasLength(1));
    });
  });

  group('Inline expressions — error reporting', () {
    test('UnbalancedClosingBraceError code is E0027', () {
      const e = UnbalancedClosingBraceError(0);
      expect(e.code, 'E0027');
    });

    test('empty placeable body is Junk', () {
      final r = parse('m = { }\n');
      expect(r.body.first, isA<Junk>());
    });
  });
}
