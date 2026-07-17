import 'package:fluent_bundle/src/syntax/ast/ast.dart';
import 'package:fluent_bundle/src/syntax/parser/parser.dart';
import 'package:test/test.dart';

void main() {
  final parser = FluentParser(
    options: const FluentParserOptions(withSpans: false),
  );
  Resource parse(String source) => parser.parse(source);

  /// Locate the SelectExpression inside the first placeable of message `key`.
  SelectExpression selectIn(Resource r, String key) {
    final m =
        r.body.firstWhere(
              (e) => e is Message && e.id.name == key,
              orElse: () => throw StateError('No message named $key'),
            )
            as Message;
    final placeable = m.value!.elements.whereType<Placeable>().first;
    return placeable.expression as SelectExpression;
  }

  group('SelectExpression — basic shape', () {
    test(r'plural-style with $variable selector', () {
      final r = parse('''
m = { \$count ->
    [one] One item.
   *[other] { \$count } items.
}
''');
      final sel = selectIn(r, 'm');
      expect(sel.selector, isA<VariableReference>());
      expect(sel.variants, hasLength(2));

      final one = sel.variants[0];
      expect(one.isDefault, isFalse);
      expect((one.key as IdentifierKey).id.name, 'one');
      expect((one.value.elements.first as TextElement).value, 'One item.');

      final other = sel.variants[1];
      expect(other.isDefault, isTrue);
      expect((other.key as IdentifierKey).id.name, 'other');
    });

    test('single-default variant is allowed', () {
      final r = parse('''
m = { \$x ->
   *[other] fallback only
}
''');
      final sel = selectIn(r, 'm');
      expect(sel.variants, hasLength(1));
      expect(sel.variants.first.isDefault, isTrue);
    });

    test('numeric variant key', () {
      final r = parse('''
m = { \$n ->
    [0] zero
    [1] one
   *[other] many
}
''');
      final sel = selectIn(r, 'm');
      expect(sel.variants, hasLength(3));
      final firstKey = sel.variants[0].key as NumberLiteralKey;
      expect(firstKey.value.value, '0');
      final secondKey = sel.variants[1].key as NumberLiteralKey;
      expect(secondKey.value.value, '1');
      expect((sel.variants[2].key as IdentifierKey).id.name, 'other');
    });

    test('defaultVariant getter returns the default-marked variant', () {
      final r = parse('''
m = { \$x ->
    [a] alpha
   *[b] bravo
    [c] charlie
}
''');
      final sel = selectIn(r, 'm');
      expect((sel.defaultVariant.key as IdentifierKey).id.name, 'b');
    });
  });

  group('SelectExpression — selector validity', () {
    test('NUMBER() function-reference selector is valid', () {
      final r = parse('''
m = { NUMBER(\$n, type: "ordinal") ->
    [1] first
   *[other] other
}
''');
      final sel = selectIn(r, 'm');
      expect(sel.selector, isA<FunctionReference>());
    });

    test('term .attribute reference selector is valid', () {
      final r = parse('''
m = { -brand.gender ->
    [feminine] she
   *[masculine] he
}
''');
      final sel = selectIn(r, 'm');
      expect(sel.selector, isA<TermReference>());
      expect((sel.selector as TermReference).attribute?.name, 'gender');
    });

    test('message .attribute reference selector is rejected (E0018)', () {
      // Per Fluent spec, message attributes resolve to a Pattern and are
      // not matchable. They cannot be used as a select-expression
      // selector. Term attributes ARE allowed (they're scalars by spec).
      final r = parse('''
m = { menu.kind ->
    [primary] P
   *[other] O
}
''');
      expect(r.body.first, isA<Junk>());
    });

    test('bare message-reference selector is rejected as Junk', () {
      final r = parse('''
m = { greeting ->
    [a] x
   *[b] y
}
''');
      expect(r.body.first, isA<Junk>());
    });

    test('bare term-reference selector is rejected as Junk', () {
      final r = parse('''
m = { -brand ->
    [a] x
   *[b] y
}
''');
      expect(r.body.first, isA<Junk>());
    });
  });

  group('SelectExpression — structural errors', () {
    test('two default variants is rejected as Junk', () {
      final r = parse('''
m = { \$x ->
   *[a] alpha
   *[b] bravo
}
''');
      expect(r.body.first, isA<Junk>());
    });

    test('no default variant is rejected as Junk', () {
      final r = parse('''
m = { \$x ->
    [a] alpha
    [b] bravo
}
''');
      expect(r.body.first, isA<Junk>());
    });

    test('zero variants is rejected as Junk', () {
      final r = parse('''
m = { \$x ->
}
''');
      expect(r.body.first, isA<Junk>());
    });
  });

  group('SelectExpression — nested patterns', () {
    test('variant value can include placeables', () {
      final r = parse('''
m = { \$gender ->
    [female] She is { \$age } years old.
   *[other] They are { \$age } years old.
}
''');
      final sel = selectIn(r, 'm');
      final female = sel.variants[0].value;
      // [text "She is "][placeable $age][text " years old."]
      expect(female.elements, hasLength(3));
      expect(female.elements[1], isA<Placeable>());
      expect(
        ((female.elements[1] as Placeable).expression as VariableReference)
            .id
            .name,
        'age',
      );
    });

    test('nested select expression in a variant', () {
      final r = parse('''
m = { \$tier ->
    [pro] { \$count ->
        [one] 1 pro item
       *[other] { \$count } pro items
    }
   *[free] { \$count ->
        [one] 1 free item
       *[other] { \$count } free items
    }
}
''');
      final outer = selectIn(r, 'm');
      expect(outer.variants, hasLength(2));
      final pro = outer.variants[0].value;
      // The outer-tier variant body itself contains a single placeable
      // whose expression is the inner SelectExpression.
      final inner =
          (pro.elements.whereType<Placeable>().first.expression)
              as SelectExpression;
      expect(inner.variants, hasLength(2));
      expect(inner.defaultVariant.isDefault, isTrue);
    });
  });
}
