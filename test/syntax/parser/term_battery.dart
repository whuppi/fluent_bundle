import 'package:fluent_bundle/src/syntax/ast/ast.dart';
import 'package:fluent_bundle/src/syntax/parser/parser.dart';
import 'package:test/test.dart';

void registerTermTests() {
  final parser = FluentParser(
    options: const FluentParserOptions(withSpans: false),
  );
  Resource parse(String source) => parser.parse(source);

  Term termNamed(Resource r, String name) {
    return r.body.firstWhere(
          (e) => e is Term && e.id.name == name,
          orElse: () => throw StateError('No term named -$name'),
        )
        as Term;
  }

  String firstText(Pattern p) =>
      p.elements.whereType<TextElement>().first.value;

  group('Term — value + attributes', () {
    test('term with simple value', () {
      final r = parse('-brand = Acme\n');
      final t = termNamed(r, 'brand');
      expect(firstText(t.value), 'Acme');
      expect(t.attributes, isEmpty);
    });

    test('term with attributes', () {
      final r = parse(
        '-brand = Acme\n'
        '    .full = Acme Corp.\n'
        '    .short = Acme\n',
      );
      final t = termNamed(r, 'brand');
      expect(firstText(t.value), 'Acme');
      expect(t.attributes, hasLength(2));
      expect(t.attributes[0].id.name, 'full');
      expect(firstText(t.attributes[0].value), 'Acme Corp.');
      expect(t.attributes[1].id.name, 'short');
      expect(firstText(t.attributes[1].value), 'Acme');
    });

    test('term value is required (Junk on missing value)', () {
      final r = parse(
        '-brand =\n'
        '    .full = Acme Corp.\n',
      );
      // Term value is REQUIRED (unlike Message). Parser fails.
      expect(r.body.first, isA<Junk>());
    });

    test('comment attaches to a term', () {
      final r = parse(
        '# Brand identity\n'
        '-brand = Acme\n',
      );
      final t = termNamed(r, 'brand');
      expect(t.comment, isNotNull);
      expect(t.comment!.content, 'Brand identity');
      expect(t.comment!.level, CommentLevel.regular);
    });
  });

  group('Term — attribute access from a term reference', () {
    test('-term.attr in placeable position is rejected (E0019)', () {
      // Per Fluent spec, `-term.attr` in a plain placeable is illegal —
      // term attributes resolve to a Pattern. They're only allowed as
      // select-expression selectors.
      final r = parse(
        '-brand = Acme\n'
        '    .full = Acme Corp.\n'
        'about = About { -brand.full }.\n',
      );
      // The `about` entry becomes Junk; the term itself parses cleanly.
      expect(r.body.any((e) => e is Term && e.id.name == 'brand'), isTrue);
      expect(r.body.any((e) => e is Junk), isTrue);
    });
  });

  group('Term — selector validity via .attr', () {
    test('-term.attr is valid as a select-expression selector', () {
      final r = parse(
        '-brand = Acme\n'
        '    .gender = neuter\n'
        'desc = { -brand.gender ->\n'
        '    [feminine] she\n'
        '    [masculine] he\n'
        '   *[neuter] it\n'
        '}\n',
      );
      // The whole resource must NOT be Junk for this entry — both the
      // term and the message parse cleanly.
      final entries = r.body.toList();
      expect(entries.any((e) => e is Term && e.id.name == 'brand'), isTrue);
      expect(entries.any((e) => e is Message && e.id.name == 'desc'), isTrue);
    });
  });

  group('Term identifier rules', () {
    test('term identifier accepts dashes and digits', () {
      final r = parse('-my-brand-2 = Test\n');
      final t = termNamed(r, 'my-brand-2');
      expect(t.id.name, 'my-brand-2');
    });
  });
}
