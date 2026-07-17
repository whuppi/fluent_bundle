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

  group('Pattern — placeables with string literals', () {
    test('inline placeable with string literal', () {
      final r = parse('greet = Hello, { "world" }!\n');
      final v = messageValue(r, 'greet');
      expect(v.elements, hasLength(3));

      expect((v.elements[0] as TextElement).value, 'Hello, ');
      final placeable = v.elements[1] as Placeable;
      expect(placeable.expression, isA<StringLiteralExpression>());
      expect(
        (placeable.expression as StringLiteralExpression).literal.value,
        'world',
      );
      expect((v.elements[2] as TextElement).value, '!');
    });

    test('placeable at start of pattern', () {
      final r = parse('m = { "X" } end\n');
      final v = messageValue(r, 'm');
      expect(v.elements.first, isA<Placeable>());
      expect((v.elements.last as TextElement).value, ' end');
    });

    test('placeable at end of pattern', () {
      final r = parse('m = start { "X" }\n');
      final v = messageValue(r, 'm');
      expect((v.elements.first as TextElement).value, 'start ');
      expect(v.elements.last, isA<Placeable>());
    });

    test('two consecutive placeables', () {
      final r = parse('m = { "a" }{ "b" }\n');
      final v = messageValue(r, 'm');
      expect(v.elements, hasLength(2));
      expect(v.elements[0], isA<Placeable>());
      expect(v.elements[1], isA<Placeable>());
    });

    test('whitespace inside placeable braces is allowed', () {
      final r = parse('m = { "X" }\n');
      final v = messageValue(r, 'm');
      final placeable = v.elements.first as Placeable;
      expect(
        (placeable.expression as StringLiteralExpression).literal.value,
        'X',
      );
    });
  });

  group('Pattern — string literal escapes', () {
    // Per Fluent Syntax 1.0, [StringLiteral.value] preserves the raw,
    // ESCAPE-PRESERVED source content. Decoding into actual codepoints
    // happens at runtime via `unescapeFluentString`. These tests assert
    // the parser's preservation behavior; the decoder has its own tests
    // in `test/syntax/unescape_test.dart`.
    test(r'\\ is preserved as the literal characters \\', () {
      final r = parse(
        r'm = { "a\\b" }'
        '\n',
      );
      final placeable = messageValue(r, 'm').elements.first as Placeable;
      final lit = (placeable.expression as StringLiteralExpression).literal;
      expect(lit.value, r'a\\b');
    });

    test(r'\" is preserved as the literal characters \"', () {
      final r = parse(
        r'm = { "say \"hi\"" }'
        '\n',
      );
      final placeable = messageValue(r, 'm').elements.first as Placeable;
      final lit = (placeable.expression as StringLiteralExpression).literal;
      expect(lit.value, r'say \"hi\"');
    });

    test(r'plain ASCII content is preserved verbatim', () {
      final r = parse(
        r'm = { "A" }'
        '\n',
      );
      final placeable = messageValue(r, 'm').elements.first as Placeable;
      final lit = (placeable.expression as StringLiteralExpression).literal;
      expect(lit.value, 'A');
    });

    test(r'non-ASCII source text passes through verbatim', () {
      final r = parse(
        r'm = { "é" }'
        '\n',
      );
      final placeable = messageValue(r, 'm').elements.first as Placeable;
      final lit = (placeable.expression as StringLiteralExpression).literal;
      expect(lit.value, 'é');
    });

    test(r'\U escape is preserved as raw 8-character sequence', () {
      final r = parse(
        r'm = { "\U01F600" }'
        '\n',
      );
      final placeable = messageValue(r, 'm').elements.first as Placeable;
      final lit = (placeable.expression as StringLiteralExpression).literal;
      expect(lit.value, r'\U01F600');
    });

    test(r'unknown escape \q raises UnknownEscapeSequenceError as Junk', () {
      // Validation happens at parse time; the raw content is rejected.
      final r = parse(
        r'm = { "\q" }'
        '\n',
      );
      expect(r.body.first, isA<Junk>());
    });

    test(r'\u with too few hex digits raises Invalid escape', () {
      final r = parse(
        r'm = { "\u00ZZ" }'
        '\n',
      );
      expect(r.body.first, isA<Junk>());
    });

    test('unterminated string literal at EOL raises Junk', () {
      final r = parse('m = { "no end\n');
      expect(r.body.first, isA<Junk>());
    });
  });

  group('Pattern — multi-line patterns + dedentation', () {
    test('block pattern: value on next line, indent-stripped', () {
      // Block: empty after `=`, value starts on next line indented by spaces.
      final r = parse('m =\n    Hello\n');
      final v = messageValue(r, 'm');
      expect(v.elements, hasLength(1));
      expect((v.elements.first as TextElement).value, 'Hello');
    });

    test(
      'inline multiline: continuation line is dedented to common indent',
      () {
        // First line "Hello" inline, continuation "world" indented 4 spaces.
        // Common indent is 4 (only the continuation has indent), so result is
        // "Hello\nworld".
        final r = parse('m = Hello\n    world\n');
        final v = messageValue(r, 'm');
        // Elements are: TextElement("Hello"), TextElement("\n") (from indent
        // remainder being just newline), TextElement("world"). The dedent
        // implementation joins them via separate elements.
        // Verify the visible text content concatenated is correct.
        final concatenated =
            v.elements.whereType<TextElement>().map((t) => t.value).join();
        expect(concatenated, 'Hello\nworld');
      },
    );

    test(
      'block multiline with deeper indents preserved relative to common',
      () {
        // First-block indent is 4 spaces. Second line indented 8 spaces:
        // 4 of those are common indent, the remaining 4 form leading text
        // on that line.
        final r = parse('m =\n    line one\n        line two indented\n');
        final v = messageValue(r, 'm');
        final concatenated =
            v.elements.whereType<TextElement>().map((t) => t.value).join();
        expect(concatenated, 'line one\n    line two indented');
      },
    );

    test('blank-line-then-special-char ends the pattern', () {
      // After "value", a blank line and then a `.` starting an Attribute
      // should end the pattern.
      final r = parse('m = value\n    .label = X\n');
      final m = r.body.firstWhere((e) => e is Message) as Message;
      expect((m.value!.elements.first as TextElement).value, 'value');
      expect(m.attributes, hasLength(1));
      expect(m.attributes.first.id.name, 'label');
    });
  });

  group('Pattern — attribute values', () {
    test('message with both value and attribute', () {
      final r = parse('m = main\n    .alt = secondary\n');
      final m = r.body.firstWhere((e) => e is Message) as Message;
      expect((m.value!.elements.first as TextElement).value, 'main');
      expect(m.attributes, hasLength(1));
      final attr = m.attributes.first;
      expect(attr.id.name, 'alt');
      expect((attr.value.elements.first as TextElement).value, 'secondary');
    });

    test('message with only attributes (no value)', () {
      final r = parse('m =\n    .a = X\n    .b = Y\n');
      final m = r.body.firstWhere((e) => e is Message) as Message;
      expect(m.value, isNull);
      expect(m.attributes, hasLength(2));
      expect(m.attributes[0].id.name, 'a');
      expect(m.attributes[1].id.name, 'b');
    });
  });

  group('Pattern — error cases (not Junk-recovered when they bubble out)', () {
    test('placeable wrapping a malformed expression yields Junk', () {
      // `{}` (empty placeable) is invalid: the parser expects an expression.
      final r = parse('m = { }\n');
      expect(r.body.first, isA<Junk>());
    });

    test('unbalanced `}` in pattern is Junk', () {
      final r = parse('m = bad } close\n');
      expect(r.body.first, isA<Junk>());
    });

    test('UnterminatedStringError is a typed FluentParseError', () {
      // Sanity check: the error class can be constructed and is a
      // FluentParseError (so callers can catch it as such).
      const e = UnterminatedStringError(0);
      expect(e, isA<FluentParseError>());
      expect(e.code, 'E0020');
    });

    test('UnbalancedClosingBraceError carries E0027', () {
      const e = UnbalancedClosingBraceError(5);
      expect(e.code, 'E0027');
      expect(e.offset, 5);
    });
  });
}
