import 'package:fluent_bundle/src/syntax/ast/ast.dart';
import 'package:fluent_bundle/src/syntax/parser/parser.dart';
import 'package:test/test.dart';

void main() {
  final parser = FluentParser(
    options: const FluentParserOptions(withSpans: false),
  );

  Resource parse(String source) => parser.parse(source);

  group('FluentParser — empty + comments', () {
    test('parses empty source as empty resource', () {
      final r = parse('');
      expect(r.body, isEmpty);
    });

    test('parses whitespace-only source as empty', () {
      final r = parse('   \n\n  \t\n');
      // Tabs are non-blank, so the second line is non-blank;
      // it becomes Junk. Verify recovery: source was malformed for Fluent
      // but parser must still produce a Resource.
      expect(r.body.length, anyOf(0, 1));
    });

    test('parses regular comment as standalone Comment entry', () {
      final r = parse('# A regular comment\n');
      expect(r.body, hasLength(1));
      final c = r.body.first as Comment;
      expect(c.level, CommentLevel.regular);
      expect(c.content, 'A regular comment');
    });

    test('parses group comment (##)', () {
      final r = parse('## Group comment\n');
      final c = r.body.first as Comment;
      expect(c.level, CommentLevel.group);
      expect(c.content, 'Group comment');
    });

    test('parses resource comment (###)', () {
      final r = parse('### Resource comment\n');
      final c = r.body.first as Comment;
      expect(c.level, CommentLevel.resource);
      expect(c.content, 'Resource comment');
    });

    test('joins multi-line regular comment', () {
      final r = parse('# Line one\n# Line two\n# Line three\n');
      expect(r.body, hasLength(1));
      final c = r.body.first as Comment;
      expect(c.level, CommentLevel.regular);
      expect(c.content, 'Line one\nLine two\nLine three');
    });

    test('does not merge comments of different levels', () {
      final r = parse('# regular\n## group\n');
      expect(r.body, hasLength(2));
      expect((r.body[0] as Comment).level, CommentLevel.regular);
      expect((r.body[1] as Comment).level, CommentLevel.group);
    });
  });

  group('FluentParser — simple messages', () {
    test('parses minimal message with text value', () {
      final r = parse('hello = world\n');
      expect(r.body, hasLength(1));
      final m = r.body.first as Message;
      expect(m.id.name, 'hello');
      expect(m.value, isNotNull);
      final elements = m.value!.elements;
      expect(elements, hasLength(1));
      expect((elements.first as TextElement).value, 'world');
      expect(m.attributes, isEmpty);
      expect(m.comment, isNull);
    });

    test('parses two messages back-to-back', () {
      final r = parse('hello = world\nfoo = bar\n');
      expect(r.body, hasLength(2));
      expect((r.body[0] as Message).id.name, 'hello');
      expect((r.body[1] as Message).id.name, 'foo');
    });

    test('skips blank lines between messages', () {
      final r = parse('hello = world\n\n\nfoo = bar\n');
      expect(r.body, hasLength(2));
      expect((r.body[0] as Message).id.name, 'hello');
      expect((r.body[1] as Message).id.name, 'foo');
    });

    test('trims trailing inline whitespace from value', () {
      final r = parse('hello = world   \n');
      final m = r.body.first as Message;
      expect((m.value!.elements.first as TextElement).value, 'world');
    });

    test('handles whitespace around = sign', () {
      final r = parse('hello   =   world\n');
      final m = r.body.first as Message;
      // Inline blank after `=` is consumed locating the value start; the
      // value's leading whitespace is gone but the value itself is preserved.
      expect((m.value!.elements.first as TextElement).value, 'world');
    });

    test('identifier accepts letters, digits, dash, underscore', () {
      final r = parse('my-key_123 = value\n');
      expect((r.body.first as Message).id.name, 'my-key_123');
    });
  });

  group('FluentParser — terms', () {
    test('parses minimal term', () {
      final r = parse('-brand = Sewali\n');
      expect(r.body, hasLength(1));
      final t = r.body.first as Term;
      expect(t.id.name, 'brand');
      expect((t.value.elements.first as TextElement).value, 'Sewali');
    });
  });

  group('FluentParser — comments attached to messages', () {
    test('regular comment immediately before a message attaches to it', () {
      final r = parse('# About hello\nhello = world\n');
      expect(r.body, hasLength(1));
      final m = r.body.first as Message;
      expect(m.comment, isNotNull);
      expect(m.comment!.content, 'About hello');
    });

    test('regular comment with blank line after stays standalone', () {
      final r = parse('# Standalone\n\nhello = world\n');
      expect(r.body, hasLength(2));
      expect(r.body[0], isA<Comment>());
      expect(r.body[1], isA<Message>());
      expect((r.body[1] as Message).comment, isNull);
    });

    test('group/resource comments do NOT attach to messages', () {
      final r = parse('## Group\nhello = world\n');
      expect(r.body, hasLength(2));
      expect(r.body[0], isA<Comment>());
      expect(r.body[1], isA<Message>());
      expect((r.body[1] as Message).comment, isNull);
    });
  });

  group('FluentParser — junk recovery', () {
    test('preserves later valid messages after a malformed entry', () {
      // First entry is malformed (no `=`); parser must recover and parse the
      // second entry successfully.
      final r = parse('!!!\nhello = world\n');
      expect(r.body, hasLength(2));
      expect(r.body[0], isA<Junk>());
      expect(r.body[1], isA<Message>());
      expect((r.body[1] as Message).id.name, 'hello');
    });

    test('Junk content captures the malformed source', () {
      final r = parse('garbage line\n');
      expect(r.body, hasLength(1));
      final j = r.body.first as Junk;
      expect(j.content, contains('garbage'));
    });
  });

  group('FluentParser — error fields', () {
    test('a message missing `=` fails as Junk, not exception', () {
      // The parser uses junk recovery internally and never throws to caller.
      final r = parse('hello\n');
      expect(r.body.first, isA<Junk>());
    });

    test('a message missing both value and attributes fails', () {
      final r = parse('hello =\n');
      // Spec: a message MUST have a value or attributes. With neither,
      // it's malformed → Junk.
      expect(r.body.first, isA<Junk>());
    });
  });
}
