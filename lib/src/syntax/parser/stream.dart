import 'package:fluent_bundle/src/errors/parse_error.dart';

/// Sentinel for end-of-file. The empty string is distinct from any real
/// character because every real character has length 1.
const String eof = '';

/// Stream-internal end-of-line. The stream normalizes `\r\n` to `\n` so
/// callers only ever see this value.
const String eol = '\n';

const _specialLineStartChars = {'}', '.', '[', '*'};

/// Character cursor with a separate "peek" pointer for lookahead.
///
/// Two cursors:
///
/// - `index` — committed position. Used by `currentChar` and `next`.
/// - `peekOffset` — speculative lookahead. Used by `currentPeek` and
///   `peek`, relative to `index + peekOffset`. Reset with `resetPeek` or
///   committed with `skipToPeek`.
///
/// `\r\n` is normalized to a single `\n`: `charAt` returns `\n` when it
/// sees `\r\n`, and `next` / `peek` step over both code units as if they
/// were one character.
class ParserStream {
  /// Creates a cursor over [source].
  ParserStream(this.source);

  /// The full FTL source being parsed.
  final String source;

  /// The committed read position.
  int index = 0;

  /// Lookahead distance beyond [index]; see [resetPeek] and
  /// [skipToPeek].
  int peekOffset = 0;

  /// The character at [offset] in the source. Returns `\n` when the offset
  /// points at the `\r` of a `\r\n` pair. Returns `eof` (empty string) past
  /// the end of input.
  String charAt(int offset) {
    if (offset < 0 || offset >= source.length) return eof;
    if (offset + 1 < source.length &&
        source.codeUnitAt(offset) == 0x0D &&
        source.codeUnitAt(offset + 1) == 0x0A) {
      return '\n';
    }
    return source[offset];
  }

  /// The character at the committed position.
  String currentChar() => charAt(index);

  /// The character at the current lookahead position.
  String currentPeek() => charAt(index + peekOffset);

  /// Advance the committed cursor by one character (treating `\r\n` as one).
  /// Resets the peek pointer to zero.
  String next() {
    peekOffset = 0;
    if (index + 1 < source.length &&
        source.codeUnitAt(index) == 0x0D &&
        source.codeUnitAt(index + 1) == 0x0A) {
      index++;
    }
    index++;
    return charAt(index);
  }

  /// Advance the peek pointer by one character (treating `\r\n` as one).
  String peek() {
    if (index + peekOffset + 1 < source.length &&
        source.codeUnitAt(index + peekOffset) == 0x0D &&
        source.codeUnitAt(index + peekOffset + 1) == 0x0A) {
      peekOffset++;
    }
    peekOffset++;
    return charAt(index + peekOffset);
  }

  /// Reset the lookahead to [offset] past the committed position.
  void resetPeek([int offset = 0]) {
    peekOffset = offset;
  }

  /// Commit the lookahead: advance [index] to the peek position.
  void skipToPeek() {
    index += peekOffset;
    peekOffset = 0;
  }

  /// Source slice from [start] (inclusive) to [end] (exclusive).
  String slice(int start, int end) => source.substring(start, end);
}

/// Parser-flavored stream: adds skip / peek helpers, character classification,
/// and `expectChar` / `takeChar` primitives the parser uses to walk EBNF rules.
class FluentParserStream extends ParserStream {
  /// Creates the FTL-aware cursor over the source.
  FluentParserStream(super.source);

  // ── Whitespace skipping (peek + skip variants) ──────────────────────────

  /// Peek over a run of inline blank space (just `' '` per Fluent spec).
  /// Returns the consumed run. Does NOT commit the index.
  String peekBlankInline() {
    final start = index + peekOffset;
    while (currentPeek() == ' ') {
      peek();
    }
    return source.substring(start, index + peekOffset);
  }

  /// Skip a run of inline blank space, committing the index. Returns the
  /// consumed run.
  String skipBlankInline() {
    final blank = peekBlankInline();
    skipToPeek();
    return blank;
  }

  /// Peek over zero or more blank lines. Returns the EOL chars consumed
  /// (one `'\n'` per blank line). Does NOT commit the index.
  String peekBlankBlock() {
    var blank = '';
    while (true) {
      final lineStart = peekOffset;
      peekBlankInline();
      if (currentPeek() == eol) {
        blank += eol;
        peek();
        continue;
      }
      if (currentPeek() == eof) {
        // Treat trailing blank-only content at EOF as a blank block.
        return blank;
      }
      // Non-blank line — reset to that line's start, return what we've seen.
      resetPeek(lineStart);
      return blank;
    }
  }

  /// Skip zero or more blank lines, committing the index. Returns the EOL
  /// chars consumed.
  String skipBlankBlock() {
    final blank = peekBlankBlock();
    skipToPeek();
    return blank;
  }

  /// Peek over any blank (inline + EOL).
  void peekBlank() {
    while (currentPeek() == ' ' || currentPeek() == eol) {
      peek();
    }
  }

  /// Skip any blank (inline + EOL), committing the index.
  void skipBlank() {
    peekBlank();
    skipToPeek();
  }

  // ── Required-char helpers ───────────────────────────────────────────────

  /// Consume [ch] or throw [FluentParseError]. Used when the EBNF says a
  /// specific character MUST appear at this position.
  void expectChar(String ch) {
    if (currentChar() == ch) {
      next();
      return;
    }
    throw ExpectedTokenError(ch, index);
  }

  /// Consume one EOL or throw. EOF is treated as a valid line end.
  void expectLineEnd() {
    if (currentChar() == eof) {
      // EOF counts as a valid line end.
      return;
    }
    if (currentChar() == eol) {
      next();
      return;
    }
    throw ExpectedTokenError(r'\n', index);
  }

  // ── Character classes (Fluent Syntax 1.0) ───────────────────────────────

  /// `[a-zA-Z]`
  static bool isCharIdStart(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
  }

  /// `[0-9]`
  static bool isDigit(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  /// Number sign (`-`) or digit, the start of a number literal.
  static bool isNumberStart(String ch) => ch == '-' || isDigit(ch);

  /// `[a-zA-Z0-9_-]` — characters allowed AFTER the first char of an
  /// identifier. The first char must additionally be a letter (see
  /// [isCharIdStart]).
  static bool isIdentifierChar(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return (c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A) ||
        (c >= 0x30 && c <= 0x39) ||
        c == 0x2D ||
        c == 0x5F;
  }

  /// `[A-Z]` — the start of a callee name (function reference).
  static bool isCalleeStart(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return c >= 0x41 && c <= 0x5A;
  }

  /// `[A-Z0-9_-]` — characters allowed AFTER the first char of a callee name.
  static bool isCalleeChar(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return (c >= 0x41 && c <= 0x5A) ||
        (c >= 0x30 && c <= 0x39) ||
        c == 0x2D ||
        c == 0x5F;
  }

  // ── Pattern continuation predicates ─────────────────────────────────────

  /// `true` if a non-empty inline pattern starts at the current peek position.
  /// Inline patterns may start with any character except EOL/EOF.
  bool isValueStart() {
    final ch = currentPeek();
    return ch != eol && ch != eof;
  }

  /// `true` if the next line continues the current pattern. Used by
  /// `getPattern` to decide whether to keep collecting elements after a
  /// newline. Restores the peek pointer either way.
  bool isValueContinuation() {
    final column1 = peekOffset;
    peekBlankInline();

    if (currentPeek() == '{') {
      resetPeek(column1);
      return true;
    }

    if (peekOffset - column1 == 0) {
      // No indent at all — line is at column 0, can't continue.
      return false;
    }

    if (isCharPatternContinuation(currentPeek())) {
      resetPeek(column1);
      return true;
    }

    return false;
  }

  /// A character that can start a pattern-continuation line. Anything that
  /// isn't a special line-start char (`}`, `.`, `[`, `*`).
  static bool isCharPatternContinuation(String ch) {
    if (ch.isEmpty) return false;
    return !_specialLineStartChars.contains(ch);
  }

  // ── Identifier / Number recognition (used by getEntry dispatch) ─────────

  /// Look ahead and decide if the next entry is a Message, Term, Comment,
  /// or Junk. Does not consume input.
  EntryStart classifyNextEntry() {
    final ch = currentChar();
    if (ch == '#') return EntryStart.comment;
    if (ch == '-') return EntryStart.term;
    if (isCharIdStart(ch)) return EntryStart.message;
    return EntryStart.junk;
  }
}

/// What kind of top-level entry the next character begins.
/// What kind of entry begins at the stream's current position.
enum EntryStart {
  /// A message (`id =`).
  message,

  /// A term (`-id =`).
  term,

  /// A comment (`#`, `##`, `###`).
  comment,

  /// Unparseable content — recovered as junk.
  junk,
}
