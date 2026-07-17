import 'package:fluent_bundle/src/errors/parse_error.dart';
import 'package:fluent_bundle/src/syntax/parser/stream.dart';
import 'package:test/test.dart';

void main() {
  group('ParserStream — basic cursor', () {
    test('starts at index 0', () {
      final s = ParserStream('abc');
      expect(s.index, 0);
      expect(s.peekOffset, 0);
      expect(s.currentChar(), 'a');
    });

    test('next advances by one and resets peek pointer', () {
      final s = ParserStream('abc');
      s.peek();
      expect(s.peekOffset, 1);
      s.next();
      expect(s.index, 1);
      expect(s.peekOffset, 0);
      expect(s.currentChar(), 'b');
    });

    test('charAt past end returns eof (empty string)', () {
      final s = ParserStream('a');
      expect(s.charAt(99), eof);
      expect(s.charAt(-1), eof);
    });

    test('next at EOF stops at end without overflowing', () {
      final s = ParserStream('a');
      expect(s.currentChar(), 'a');
      s.next();
      expect(s.currentChar(), eof);
      // Calling next at EOF must not crash.
      s.next();
      expect(s.currentChar(), eof);
    });
  });

  group('ParserStream — CRLF normalization', () {
    test('charAt returns LF when sitting on CR of CRLF', () {
      final s = ParserStream('a\r\nb');
      expect(s.charAt(1), '\n'); // CR position appears as LF
      expect(s.charAt(2), '\n'); // LF position is itself LF
      expect(s.charAt(3), 'b');
    });

    test('next steps over CRLF as one char', () {
      final s = ParserStream('a\r\nb');
      expect(s.currentChar(), 'a');
      s.next();
      // The CR position presents as LF.
      expect(s.currentChar(), '\n');
      s.next();
      // Cursor is now past the entire CRLF sequence.
      expect(s.currentChar(), 'b');
    });

    test('peek steps over CRLF as one char', () {
      final s = ParserStream('a\r\nb');
      // Peek from index 0: first peek lands on the CRLF (presented as \n).
      expect(s.peek(), '\n');
      // Second peek lands on 'b'.
      expect(s.peek(), 'b');
    });
  });

  group('ParserStream — peek + skipToPeek', () {
    test('peek does not move index, only peekOffset', () {
      final s = ParserStream('abcd');
      s.peek();
      s.peek();
      expect(s.index, 0);
      expect(s.peekOffset, 2);
      expect(s.currentChar(), 'a');
      expect(s.currentPeek(), 'c');
    });

    test('resetPeek with no arg sets peekOffset back to zero', () {
      final s = ParserStream('abcd');
      s.peek();
      s.peek();
      s.resetPeek();
      expect(s.peekOffset, 0);
      expect(s.currentPeek(), 'a');
    });

    test('resetPeek with an offset sets peek to that offset', () {
      final s = ParserStream('abcd');
      s.peek();
      s.peek();
      s.resetPeek(1);
      expect(s.peekOffset, 1);
      expect(s.currentPeek(), 'b');
    });

    test('skipToPeek commits the peek pointer to the index', () {
      final s = ParserStream('abcd');
      s.peek();
      s.peek();
      s.skipToPeek();
      expect(s.index, 2);
      expect(s.peekOffset, 0);
      expect(s.currentChar(), 'c');
    });
  });

  group('FluentParserStream — whitespace skipping', () {
    test('skipBlankInline returns consumed spaces and stops at non-space', () {
      final s = FluentParserStream('   abc');
      expect(s.skipBlankInline(), '   ');
      expect(s.currentChar(), 'a');
    });

    test('skipBlankInline does NOT cross newlines', () {
      final s = FluentParserStream('  \nabc');
      expect(s.skipBlankInline(), '  ');
      expect(s.currentChar(), '\n');
    });

    test('skipBlankBlock returns one EOL per blank line consumed', () {
      final s = FluentParserStream('\n\n\nabc');
      expect(s.skipBlankBlock(), '\n\n\n');
      expect(s.currentChar(), 'a');
    });

    test('skipBlankBlock handles CRLF blank lines', () {
      final s = FluentParserStream('\r\n\r\nabc');
      expect(s.skipBlankBlock(), '\n\n');
      expect(s.currentChar(), 'a');
    });

    test('skipBlankBlock counts whitespace-only lines as blank', () {
      final s = FluentParserStream('   \n\t \nabc');
      // Note: Fluent spec only treats spaces (0x20) as blank inside lines —
      // tab makes the line non-blank. We mirror that behavior.
      // First line is ALL spaces, then '\n' — counts. Second line starts with
      // tab — non-blank — so we stop after one blank line.
      final result = s.skipBlankBlock();
      expect(result, '\n');
      expect(s.currentChar(), '\t');
    });

    test('skipBlankBlock returns empty string when no blank lines present', () {
      final s = FluentParserStream('abc');
      expect(s.skipBlankBlock(), '');
      expect(s.index, 0);
    });

    test('skipBlank consumes both spaces and EOLs', () {
      final s = FluentParserStream('  \n  abc');
      s.skipBlank();
      expect(s.currentChar(), 'a');
    });
  });

  group('FluentParserStream — expectChar / takeChar', () {
    test('expectChar consumes the matching character', () {
      final s = FluentParserStream('=value');
      s.expectChar('=');
      expect(s.currentChar(), 'v');
    });

    test('expectChar throws ExpectedTokenError on mismatch', () {
      final s = FluentParserStream('xvalue');
      expect(
        () => s.expectChar('='),
        throwsA(
          isA<ExpectedTokenError>()
              .having((e) => e.token, 'token', '=')
              .having((e) => e.offset, 'offset', 0),
        ),
      );
    });

    test('expectLineEnd accepts EOL', () {
      final s = FluentParserStream('\nabc');
      s.expectLineEnd();
      expect(s.currentChar(), 'a');
    });

    test('expectLineEnd accepts EOF', () {
      final s = FluentParserStream('');
      s.expectLineEnd(); // does not throw
    });

    test('expectLineEnd throws when at non-EOL non-EOF', () {
      final s = FluentParserStream('abc');
      expect(s.expectLineEnd, throwsA(isA<ExpectedTokenError>()));
    });
  });

  group('FluentParserStream — character classes', () {
    test('isCharIdStart matches ASCII letters only', () {
      expect(FluentParserStream.isCharIdStart('a'), true);
      expect(FluentParserStream.isCharIdStart('Z'), true);
      expect(FluentParserStream.isCharIdStart('0'), false);
      expect(FluentParserStream.isCharIdStart('_'), false);
      expect(FluentParserStream.isCharIdStart('-'), false);
      expect(FluentParserStream.isCharIdStart(''), false);
    });

    test('isDigit matches digits only', () {
      expect(FluentParserStream.isDigit('5'), true);
      expect(FluentParserStream.isDigit('a'), false);
      expect(FluentParserStream.isDigit(''), false);
    });

    test('isNumberStart matches dash + digits', () {
      expect(FluentParserStream.isNumberStart('-'), true);
      expect(FluentParserStream.isNumberStart('5'), true);
      expect(FluentParserStream.isNumberStart('a'), false);
    });
  });

  group('FluentParserStream — slicing', () {
    test('slice returns substring', () {
      final s = ParserStream('hello world');
      expect(s.slice(6, 11), 'world');
    });
  });

  group('FluentParserStream — entry classification', () {
    test('classifies messages by leading letter', () {
      expect(
        FluentParserStream('hello = X').classifyNextEntry(),
        EntryStart.message,
      );
      expect(
        FluentParserStream('Z = X').classifyNextEntry(),
        EntryStart.message,
      );
    });

    test('classifies terms by leading dash', () {
      expect(
        FluentParserStream('-name = X').classifyNextEntry(),
        EntryStart.term,
      );
    });

    test('classifies comments by hash', () {
      expect(
        FluentParserStream('# foo').classifyNextEntry(),
        EntryStart.comment,
      );
    });

    test('classifies anything else as junk', () {
      expect(
        FluentParserStream('!!! bad').classifyNextEntry(),
        EntryStart.junk,
      );
      expect(FluentParserStream('').classifyNextEntry(), EntryStart.junk);
    });
  });
}
