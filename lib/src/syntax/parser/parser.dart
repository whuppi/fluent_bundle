import 'package:fluent_bundle/src/errors/parse_error.dart';
import 'package:fluent_bundle/src/syntax/ast/ast.dart';
import 'package:fluent_bundle/src/syntax/parser/stream.dart';

/// Highest valid Unicode codepoint (U+10FFFF). Anything beyond this is
/// outside the codespace and rejected by `\u`/`\U` escapes.
const int _maxUnicodeCodepoint = 0x10FFFF;

/// Parser configuration.
class FluentParserOptions {
  /// Bundles the parser knobs.
  const FluentParserOptions({this.withSpans = true});

  /// When true (default), every AST node carries a `Span(start, end)`.
  /// Set false for slight perf in pure-runtime use.
  final bool withSpans;
}

/// Recursive-descent parser for Fluent Syntax 1.0.
///
/// Junk recovery: on a parse error inside a top-level entry, the offending
/// span is preserved as a [Junk] entry and parsing resumes at the next entry
/// boundary, so a single bad message never breaks an otherwise-valid
/// resource.
class FluentParser {
  /// Creates a parser configured by [options].
  FluentParser({FluentParserOptions options = const FluentParserOptions()})
    : withSpans = options.withSpans;

  /// True when the parser records [Span]s on every node.
  final bool withSpans;

  /// Parse the full source into a [Resource].
  Resource parse(String source) {
    final ps = FluentParserStream(source);
    ps.skipBlankBlock();

    final entries = <Entry>[];
    Comment? lastComment;

    while (ps.currentChar() != eof) {
      final entry = _getEntryOrJunk(ps);
      final blankLines = ps.skipBlankBlock();

      // Comments attach to a Message/Term iff they're separated by no blank
      // line. If the comment is followed by junk or by blank lines, it stays
      // a standalone Comment entry.
      if (entry is Comment &&
          entry.level == CommentLevel.regular &&
          blankLines.isEmpty &&
          ps.currentChar() != eof) {
        lastComment = entry;
      } else {
        if (lastComment != null) {
          // Attach the saved comment to the just-parsed Message or Term.
          if (entry is Message) {
            entries.add(
              Message(
                id: entry.id,
                value: entry.value,
                attributes: entry.attributes,
                comment: lastComment,
                span: _spanIfTracking(
                  _messageStart(entry, lastComment),
                  ps.index,
                ),
              ),
            );
          } else if (entry is Term) {
            entries.add(
              Term(
                id: entry.id,
                value: entry.value,
                attributes: entry.attributes,
                comment: lastComment,
                span: _spanIfTracking(_termStart(entry, lastComment), ps.index),
              ),
            );
          } else {
            entries.add(lastComment);
            entries.add(entry);
          }
          lastComment = null;
        } else {
          entries.add(entry);
        }
      }
    }

    // Trailing comment that never attached to anything stays as standalone.
    if (lastComment != null) entries.add(lastComment);

    return Resource(entries, span: _spanIfTracking(0, source.length));
  }

  // ── Entry dispatch ──────────────────────────────────────────────────────

  Entry _getEntryOrJunk(FluentParserStream ps) {
    final entryStart = ps.index;
    try {
      return _getEntry(ps);
    } on FluentParseError {
      // Skip to next-entry boundary, preserve raw text as Junk.
      final junkContent = _skipToNextEntryStart(ps, entryStart);
      return Junk(
        content: junkContent,
        span: _spanIfTracking(entryStart, ps.index),
      );
    }
  }

  Entry _getEntry(FluentParserStream ps) {
    final classification = ps.classifyNextEntry();
    switch (classification) {
      case EntryStart.comment:
        return _getComment(ps);
      case EntryStart.term:
        return _getTerm(ps);
      case EntryStart.message:
        return _getMessage(ps);
      case EntryStart.junk:
        throw ExpectedCharRangeError('a-zA-Z, -, or #', ps.index);
    }
  }

  /// Walk forward past the broken entry until we find what looks like the
  /// start of a new entry (line-start letter, dash, or hash) or hit EOF.
  String _skipToNextEntryStart(FluentParserStream ps, int junkStart) {
    // If the parser advanced past one or more newlines before throwing,
    // anchor the recovery scan at the start of the line that contained
    // the failure. Without this, junk content can swallow following
    // lines (next comment, next entry) that the parser already walked
    // through but then rejected.
    final lastNewline = ps.source.lastIndexOf(eol, ps.index);
    if (lastNewline > junkStart) {
      ps.index = lastNewline;
    }
    while (ps.currentChar() != eof) {
      if (ps.currentChar() != eol) {
        ps.next();
        continue;
      }
      // At an EOL — peek at what follows.
      ps.next();
      final c = ps.currentChar();
      if (c == eof) break;
      if (FluentParserStream.isCharIdStart(c) || c == '-' || c == '#') break;
    }
    return ps.slice(junkStart, ps.index);
  }

  // ── Top-level entries ───────────────────────────────────────────────────

  Message _getMessage(FluentParserStream ps) {
    final start = ps.index;
    final id = _getIdentifier(ps);
    ps.skipBlankInline();
    ps.expectChar('=');

    final value = _maybeGetPattern(ps);
    final attributes = _getAttributes(ps);

    if (value == null && attributes.isEmpty) {
      throw ExpectedMessageFieldError(id.name, ps.index);
    }
    return Message(
      id: id,
      value: value,
      attributes: attributes,
      span: _spanIfTracking(start, ps.index),
    );
  }

  Term _getTerm(FluentParserStream ps) {
    final start = ps.index;
    ps.expectChar('-');
    final id = _getIdentifier(ps);
    ps.skipBlankInline();
    ps.expectChar('=');

    final value = _maybeGetPattern(ps);
    if (value == null) {
      throw ExpectedTermFieldError(id.name, ps.index);
    }
    final attributes = _getAttributes(ps);

    return Term(
      id: id,
      value: value,
      attributes: attributes,
      span: _spanIfTracking(start, ps.index),
    );
  }

  Comment _getComment(FluentParserStream ps) {
    final start = ps.index;
    var level = 0;
    final lines = <String>[];

    while (true) {
      // Count this line's '#' run to determine its level (max 3).
      final lineHashStart = ps.index;
      var lineLevel = 0;
      while (ps.currentChar() == '#' && lineLevel < 3) {
        ps.next();
        lineLevel++;
      }
      if (lineLevel == 0) {
        // No '#' on this line — we're past the comment.
        break;
      }
      if (level != 0 && lineLevel != level) {
        // Different comment level than the block we've been collecting.
        // Back out this line's '#' chars and stop; the outer dispatch
        // loop will treat the next line as a fresh entry attempt.
        ps.index = lineHashStart;
        break;
      }
      level = lineLevel;

      // After the '#' run, the line must be either empty (EOL or EOF) or
      // a single space followed by content. Anything else is a parse
      // error on the first line (turning the whole entry into Junk) or
      // a "back out and stop" signal once we've already collected content.
      final ch = ps.currentChar();
      if (ch == eol || ch == eof) {
        lines.add('');
      } else if (ch == ' ') {
        ps.next();
        final lineStart = ps.index;
        while (ps.currentChar() != eof && ps.currentChar() != eol) {
          ps.next();
        }
        lines.add(ps.slice(lineStart, ps.index));
      } else {
        // No space and no EOL after the '#' run.
        if (lines.isEmpty) {
          // First line of this comment attempt — surface as a parse
          // error so junk-recovery captures the offending line.
          throw ExpectedCharRangeError(' ', ps.index);
        }
        // We already have valid content; back out this line's '#'s and
        // stop. The accumulated lines are a valid comment; the rest is
        // the next entry's problem.
        ps.index = lineHashStart;
        break;
      }
      if (ps.currentChar() == eol) ps.next();
    }

    final commentLevel = switch (level) {
      1 => CommentLevel.regular,
      2 => CommentLevel.group,
      3 => CommentLevel.resource,
      _ => CommentLevel.regular,
    };
    return Comment(
      level: commentLevel,
      content: lines.join('\n'),
      span: _spanIfTracking(start, ps.index),
    );
  }

  // ── Sub-productions ─────────────────────────────────────────────────────

  Identifier _getIdentifier(FluentParserStream ps) {
    final start = ps.index;
    final ch = ps.currentChar();
    if (!FluentParserStream.isCharIdStart(ch)) {
      throw ExpectedCharRangeError('a-zA-Z', ps.index);
    }
    ps.next();
    while (true) {
      final c = ps.currentChar();
      if (c.isEmpty) break;
      final code = c.codeUnitAt(0);
      final isContinuation =
          (code >= 0x41 && code <= 0x5A) || // A-Z
          (code >= 0x61 && code <= 0x7A) || // a-z
          (code >= 0x30 && code <= 0x39) || // 0-9
          code == 0x5F || // _
          code == 0x2D; // -
      if (!isContinuation) break;
      ps.next();
    }
    return Identifier(
      ps.slice(start, ps.index),
      span: _spanIfTracking(start, ps.index),
    );
  }

  List<Attribute> _getAttributes(FluentParserStream ps) {
    final attrs = <Attribute>[];
    while (true) {
      // Attributes appear on their own line, indented with whitespace, starting with `.`.
      final lineStart = ps.index;
      final blankStart = ps.peekOffset;
      ps.peekBlank();
      if (ps.currentPeek() != '.') {
        ps.resetPeek(blankStart);
        break;
      }
      ps.skipToPeek();
      // Attribute parse failure rewinds to the line start so the unparsed
      // text can be junked as its own entry by the entry loop.
      try {
        attrs.add(_getAttribute(ps));
      } on FluentParseError {
        ps.index = lineStart;
        ps.resetPeek();
        break;
      }
    }
    return attrs;
  }

  Attribute _getAttribute(FluentParserStream ps) {
    final start = ps.index;
    ps.expectChar('.');
    final id = _getIdentifier(ps);
    ps.skipBlankInline();
    ps.expectChar('=');
    final value = _maybeGetPattern(ps);
    if (value == null) {
      // Attribute MUST have a value.
      throw ExpectedTokenError('Pattern', ps.index);
    }
    return Attribute(
      id: id,
      value: value,
      span: _spanIfTracking(start, ps.index),
    );
  }

  // ── Pattern parsing ─────────────────────────────────────────────────────

  /// Distinguishes inline patterns (start on the same line as `=`) from
  /// block patterns (start on a new line, indented). Returns null if no
  /// pattern follows.
  Pattern? _maybeGetPattern(FluentParserStream ps) {
    // Try inline first.
    ps.peekBlankInline();
    if (ps.isValueStart()) {
      ps.skipToPeek();
      return _getPattern(ps, isBlock: false);
    }
    // Try block: look past blank lines for indented content.
    ps.peekBlankBlock();
    if (ps.isValueContinuation()) {
      ps.skipToPeek();
      return _getPattern(ps, isBlock: true);
    }
    ps.resetPeek();
    return null;
  }

  /// Parse a Pattern body. Collects text + placeable + indent markers in
  /// source order, then runs `_dedent` to strip the common leading indent
  /// off continuation lines.
  Pattern? _getPattern(FluentParserStream ps, {required bool isBlock}) {
    final start = ps.index;
    final elements = <_PatternBuildItem>[];
    int commonIndentLength;

    if (isBlock) {
      // Block patterns: the first line is itself indented. Capture the
      // indent as the seed for commonIndentLength. No leading EOL on the
      // first indent of a block pattern — getMessage already consumed `=\n`.
      final blankStart = ps.index;
      final firstIndent = ps.skipBlankInline();
      elements.add(_Indent('', firstIndent, blankStart, ps.index));
      commonIndentLength = firstIndent.length;
    } else {
      commonIndentLength = -1; // sentinel for "no block constraints yet"
    }

    elements:
    while (true) {
      final ch = ps.currentChar();
      switch (ch) {
        case eof:
          break elements;
        case eol:
          // Newline. Decide whether the pattern continues on the next line.
          final blankStart = ps.index;
          final blankLines = ps.peekBlankBlock();
          if (ps.isValueContinuation()) {
            ps.skipToPeek();
            final indent = ps.skipBlankInline();
            commonIndentLength =
                (commonIndentLength < 0)
                    ? indent.length
                    : (indent.length < commonIndentLength
                        ? indent.length
                        : commonIndentLength);
            // EOL run is kept as-is; inline-blank goes into `indent` and
            // gets common-indent-stripped at dedent time.
            elements.add(_Indent(blankLines, indent, blankStart, ps.index));
            continue elements;
          }
          // Not a continuation — pattern ends here.
          ps.resetPeek();
          break elements;
        case '{':
          elements.add(_PlaceableElement(_getPlaceable(ps)));
          continue elements;
        case '}':
          throw UnbalancedClosingBraceError(ps.index);
        default:
          elements.add(_TextElementChunk(_getTextElement(ps)));
      }
    }

    // Dedent and drop trailing whitespace on the last text element.
    final dedented = _dedent(
      elements,
      commonIndentLength < 0 ? 0 : commonIndentLength,
    );
    if (dedented.isEmpty) {
      return null;
    }
    return Pattern(dedented, span: _spanIfTracking(start, ps.index));
  }

  /// Strip the common indent from text-line starts, merge adjacent text
  /// fragments, and assemble the final pattern-element list. Drops
  /// trailing whitespace on the last element.
  List<PatternElement> _dedent(
    List<_PatternBuildItem> items,
    int commonIndent,
  ) {
    final result = <PatternElement>[];

    void appendText(String value, int spanStart, int spanEnd) {
      if (value.isEmpty) return;
      // Coalesce with the previous TextElement if there is one. The spec
      // treats indents and text-line fragments as one continuous text
      // run; the canonical fixtures expect a single merged TextElement
      // per run.
      if (result.isNotEmpty && result.last is TextElement) {
        final prev = result.last as TextElement;
        result[result.length - 1] = TextElement(
          prev.value + value,
          span: _spanIfTracking(prev.span?.start ?? spanStart, spanEnd),
        );
      } else {
        result.add(
          TextElement(value, span: _spanIfTracking(spanStart, spanEnd)),
        );
      }
    }

    for (final item in items) {
      if (item is _Indent) {
        final keepInline =
            item.inline.length > commonIndent
                ? item.inline.substring(commonIndent)
                : '';
        appendText(item.eol + keepInline, item.start, item.end);
      } else if (item is _TextElementChunk) {
        appendText(
          item.text.value,
          item.text.span?.start ?? 0,
          item.text.span?.end ?? 0,
        );
      } else if (item is _PlaceableElement) {
        result.add(item.placeable);
      }
    }

    // Drop trailing fluent-blank from the last text element. Per spec, only
    // ASCII space (U+0020), CR (U+000D), and LF (U+000A) count — tabs are
    // literal pattern content and must NOT be trimmed.
    if (result.isNotEmpty) {
      final last = result.last;
      if (last is TextElement) {
        final v = last.value;
        var end = v.length;
        while (end > 0) {
          final c = v.codeUnitAt(end - 1);
          if (c == 0x20 || c == 0x0D || c == 0x0A) {
            end--;
          } else {
            break;
          }
        }
        if (end == 0) {
          result.removeLast();
        } else if (end != v.length) {
          result[result.length - 1] = TextElement(
            v.substring(0, end),
            span: last.span,
          );
        }
      }
    }

    return result;
  }

  /// A run of literal text up to the next placeable / newline / EOF.
  /// Escape sequences are NOT processed here (only inside string literals);
  /// patterns use raw text per Fluent Syntax 1.0.
  TextElement _getTextElement(FluentParserStream ps) {
    final start = ps.index;
    final buffer = StringBuffer();
    while (true) {
      final ch = ps.currentChar();
      if (ch == eof || ch == eol) break;
      if (ch == '{' || ch == '}') break;
      buffer.write(ch);
      ps.next();
    }
    return TextElement(
      buffer.toString(),
      span: _spanIfTracking(start, ps.index),
    );
  }

  /// Parse a `{ expression }` placeable.
  Placeable _getPlaceable(FluentParserStream ps) {
    final start = ps.index;
    ps.expectChar('{');
    ps.skipBlank();
    final expr = _getExpression(ps);
    ps.skipBlank();
    ps.expectChar('}');
    return Placeable(expr, span: _spanIfTracking(start, ps.index));
  }

  /// Parse the expression inside a placeable. May be either an inline
  /// expression or a `selector -> [key] pattern ...` select expression.
  ///
  /// Two placeable-context validation rules apply, per the Fluent Syntax
  /// 1.0 spec:
  ///
  ///   - Inside a placeable that is NOT a select expression, a
  ///     [TermReference] with a non-null attribute is illegal — `{-x.a}`
  ///     is forbidden. Only the SELECTOR position permits term-attr
  ///     references. (E0019)
  ///   - When the expression IS a select expression, the selector itself
  ///     is restricted: bare message refs (E0016), message-attr refs
  ///     (E0018), bare term refs (E0017), and nested placeables (E0029)
  ///     are all rejected.
  Expression _getExpression(FluentParserStream ps) {
    final start = ps.index;
    final selector = _getInlineExpression(ps);

    // If the selector is followed by `->` (after optional blank — newlines
    // are part of the spec's blank class between selector and arrow), this
    // is a SelectExpression.
    final saved = ps.peekOffset;
    ps.peekBlank();
    if (ps.currentPeek() == '-') {
      ps.peek();
      if (ps.currentPeek() == '>') {
        // Commit the lookahead: skip the blank, the `-`, and the `>`.
        ps.skipToPeek();
        ps.next(); // `>`
        _validateSelector(selector, start);
        ps.skipBlankInline();
        ps.expectLineEnd();
        final variants = _getVariants(ps);
        return SelectExpression(
          selector,
          variants,
          span: _spanIfTracking(start, ps.index),
        );
      }
    }
    ps.resetPeek(saved);

    // Placeable-context (not select-expression) validation: a term
    // reference with an attribute may not appear here.
    if (selector is TermReference && selector.attribute != null) {
      throw CallbackParseError(
        'E0019',
        'Attributes of terms cannot be used as placeables',
        start,
      );
    }
    return selector;
  }

  /// Validate the selector position of a select expression. Throws the
  /// matching spec error code on the first violation; junk recovery
  /// catches it at the entry boundary.
  void _validateSelector(InlineExpression selector, int start) {
    if (selector is MessageReference) {
      throw CallbackParseError(
        selector.attribute == null ? 'E0016' : 'E0018',
        selector.attribute == null
            ? 'Message references cannot be used as selectors'
            : 'Attributes of messages cannot be used as selectors',
        start,
      );
    }
    if (selector is TermReference && selector.attribute == null) {
      throw CallbackParseError(
        'E0017',
        'Terms cannot be used as selectors',
        start,
      );
    }
    if (selector is Placeable) {
      throw CallbackParseError(
        'E0029',
        'Select expressions are not valid selectors',
        start,
      );
    }
  }

  /// Parse one or more `[key] pattern` variants until the closing `}`.
  ///
  /// Exactly one variant must be marked as the default (with a leading `*`).
  List<Variant> _getVariants(FluentParserStream ps) {
    final variants = <Variant>[];
    var sawDefault = false;
    while (true) {
      ps.skipBlank();
      if (ps.currentChar() == '}') break;
      final v = _getVariant(ps);
      if (v.isDefault) {
        if (sawDefault) {
          throw CallbackParseError(
            'E0028',
            'Expected only one default variant',
            ps.index,
          );
        }
        sawDefault = true;
      }
      variants.add(v);
    }
    if (variants.isEmpty) {
      throw CallbackParseError(
        'E0011',
        'Expected at least one variant after "->"',
        ps.index,
      );
    }
    if (!sawDefault) {
      throw CallbackParseError(
        'E0010',
        'Expected one of the variants to be marked as default (*)',
        ps.index,
      );
    }
    return variants;
  }

  /// Parse a single `[key] pattern` (or `*[key] pattern`) variant.
  Variant _getVariant(FluentParserStream ps) {
    final start = ps.index;
    var isDefault = false;
    if (ps.currentChar() == '*') {
      ps.next();
      isDefault = true;
    }
    ps.expectChar('[');
    ps.skipBlank();
    final key = _getVariantKey(ps);
    ps.skipBlank();
    ps.expectChar(']');
    final value = _maybeGetPattern(ps);
    if (value == null) {
      throw CallbackParseError(
        'E0012',
        'Expected a value for the variant',
        ps.index,
      );
    }
    return Variant(
      key: key,
      value: value,
      isDefault: isDefault,
      span: _spanIfTracking(start, ps.index),
    );
  }

  /// Parse a variant key: an Identifier or a NumberLiteral.
  VariantKey _getVariantKey(FluentParserStream ps) {
    final start = ps.index;
    final ch = ps.currentChar();
    if (FluentParserStream.isNumberStart(ch)) {
      final n = _getNumberLiteral(ps);
      return NumberLiteralKey(n, span: _spanIfTracking(start, ps.index));
    }
    if (FluentParserStream.isCharIdStart(ch)) {
      final id = _getIdentifier(ps);
      return IdentifierKey(id, span: _spanIfTracking(start, ps.index));
    }
    throw ExpectedCharRangeError(
      'variant key (identifier or number)',
      ps.index,
    );
  }

  /// Inline expression dispatch: picks the right branch by lookahead.
  ///
  /// One non-obvious case: when the current char is `{`, we recurse into
  /// [_getPlaceable] and return the resulting [Placeable] — a [Placeable]
  /// is both a [PatternElement] and an [InlineExpression] per spec, so
  /// it can legally sit in any expression slot (a nested placeable like
  /// `{ {"x"} }` or a placeable used as an arg to a function).
  InlineExpression _getInlineExpression(FluentParserStream ps) {
    final start = ps.index;
    final ch = ps.currentChar();

    if (ch == '{') {
      return _getPlaceable(ps);
    }

    if (ch == '"') {
      final lit = _getStringLiteral(ps);
      return StringLiteralExpression(
        lit,
        span: _spanIfTracking(start, ps.index),
      );
    }
    if (FluentParserStream.isDigit(ch)) {
      final lit = _getNumberLiteral(ps);
      return NumberLiteralExpression(
        lit,
        span: _spanIfTracking(start, ps.index),
      );
    }
    if (ch == r'$') {
      ps.next();
      final id = _getIdentifier(ps);
      return VariableReference(id, span: _spanIfTracking(start, ps.index));
    }
    if (ch == '-') {
      // `-` is ambiguous: `-7` is a negative number, `-brand` is a Term ref.
      // Peek the next character to disambiguate.
      ps.peek();
      final next = ps.currentPeek();
      ps.resetPeek();
      if (FluentParserStream.isDigit(next)) {
        final lit = _getNumberLiteral(ps);
        return NumberLiteralExpression(
          lit,
          span: _spanIfTracking(start, ps.index),
        );
      }
      ps.next(); // consume the leading `-` of the term name
      final id = _getIdentifier(ps);
      Identifier? attr;
      if (ps.currentChar() == '.') {
        ps.next();
        attr = _getIdentifier(ps);
      }
      // Whitespace between the term name (or `.attr`) and `(` — including
      // line breaks — is allowed by the spec. `-term ( ... )` and
      // `-term\n  (\n    ...\n  )` are the same as `-term(...)`.
      CallArguments? args;
      ps.peekBlank();
      if (ps.currentPeek() == '(') {
        ps.skipToPeek();
        args = _getCallArguments(ps);
      } else {
        ps.resetPeek();
      }
      return TermReference(
        id,
        attribute: attr,
        arguments: args,
        span: _spanIfTracking(start, ps.index),
      );
    }
    if (FluentParserStream.isCalleeStart(ch)) {
      // A leading uppercase letter could start either a callee name
      // (FunctionReference) or a regular identifier (MessageReference).
      // Disambiguate: scan ahead through the callee-name chars and then
      // through any blank (including line breaks); if a `(` follows,
      // it's a call.
      final probeStart = ps.index;
      ps.peek();
      while (FluentParserStream.isCalleeChar(ps.currentPeek())) {
        ps.peek();
      }
      ps.peekBlank();
      final isCall = ps.currentPeek() == '(';
      ps.resetPeek();
      if (isCall) {
        final name = _readWhile(ps, FluentParserStream.isCalleeChar);
        final id = Identifier(
          name,
          span: _spanIfTracking(probeStart, ps.index),
        );
        ps.skipBlank();
        final args = _getCallArguments(ps);
        return FunctionReference(
          id,
          args,
          span: _spanIfTracking(start, ps.index),
        );
      }
      // Fall through to MessageReference.
    }
    if (FluentParserStream.isCharIdStart(ch)) {
      final id = _getIdentifier(ps);
      Identifier? attr;
      if (ps.currentChar() == '.') {
        ps.next();
        attr = _getIdentifier(ps);
      }
      return MessageReference(
        id,
        attribute: attr,
        span: _spanIfTracking(start, ps.index),
      );
    }

    throw ExpectedCharRangeError(
      'expression: string, number, \$variable, identifier, -term, or CALLEE',
      ps.index,
    );
  }

  /// Consume identifier characters while the matcher returns true.
  String _readWhile(FluentParserStream ps, bool Function(String) matcher) {
    final buffer = StringBuffer();
    while (matcher(ps.currentChar())) {
      buffer.write(ps.currentChar());
      ps.next();
    }
    return buffer.toString();
  }

  /// Parse a numeric literal: optional `-`, integer part, optional `.frac`.
  NumberLiteral _getNumberLiteral(FluentParserStream ps) {
    final start = ps.index;
    final buffer = StringBuffer();
    if (ps.currentChar() == '-') {
      buffer.write('-');
      ps.next();
    }
    if (!FluentParserStream.isDigit(ps.currentChar())) {
      throw ExpectedCharRangeError('0-9', ps.index);
    }
    while (FluentParserStream.isDigit(ps.currentChar())) {
      buffer.write(ps.currentChar());
      ps.next();
    }
    var precision = 0;
    if (ps.currentChar() == '.') {
      buffer.write('.');
      ps.next();
      if (!FluentParserStream.isDigit(ps.currentChar())) {
        throw ExpectedCharRangeError('0-9', ps.index);
      }
      while (FluentParserStream.isDigit(ps.currentChar())) {
        buffer.write(ps.currentChar());
        ps.next();
        precision++;
      }
    }
    return NumberLiteral(
      buffer.toString(),
      precision,
      span: _spanIfTracking(start, ps.index),
    );
  }

  /// Parse `( arg, arg, key: value, ... )` after a callee or term name.
  ///
  /// Positional arguments must precede named arguments. A trailing comma is
  /// allowed.
  CallArguments _getCallArguments(FluentParserStream ps) {
    final start = ps.index;
    ps.expectChar('(');
    ps.skipBlank();

    final positional = <InlineExpression>[];
    final named = <NamedArgument>[];
    final seenNames = <String>{};

    while (ps.currentChar() != ')') {
      // Lookahead to distinguish `name: value` from a bare expression.
      final isNamed = _peekIsNamedArgument(ps);
      if (isNamed) {
        final argStart = ps.index;
        final name = _getIdentifier(ps);
        if (!seenNames.add(name.name)) {
          throw CallbackParseError(
            'E0022',
            'Duplicated named argument: ${name.name}',
            argStart,
          );
        }
        ps.skipBlank();
        ps.expectChar(':');
        ps.skipBlank();
        final value = _getLiteral(ps);
        named.add(
          NamedArgument(name, value, span: _spanIfTracking(argStart, ps.index)),
        );
      } else {
        if (named.isNotEmpty) {
          // Positional after named is an error.
          throw CallbackParseError(
            'E0021',
            'Positional arguments must not follow named arguments',
            ps.index,
          );
        }
        positional.add(_getInlineExpression(ps));
      }
      ps.skipBlank();
      if (ps.currentChar() == ',') {
        ps.next();
        ps.skipBlank();
        continue;
      }
      break;
    }

    ps.expectChar(')');
    return CallArguments(
      positional: positional,
      named: named,
      span: _spanIfTracking(start, ps.index),
    );
  }

  /// True if the next argument is a named argument (`identifier` then `:`).
  /// Whitespace — including line breaks — is allowed between the name and
  /// the `:`. Restores the peek pointer on return.
  bool _peekIsNamedArgument(FluentParserStream ps) {
    if (!FluentParserStream.isCharIdStart(ps.currentChar())) return false;
    ps.peek();
    while (FluentParserStream.isIdentifierChar(ps.currentPeek())) {
      ps.peek();
    }
    ps.peekBlank();
    final isColon = ps.currentPeek() == ':';
    ps.resetPeek();
    return isColon;
  }

  /// Parse a literal value (string or number). Used for named-argument
  /// values, where only literals are allowed.
  Literal _getLiteral(FluentParserStream ps) {
    final ch = ps.currentChar();
    if (ch == '"') return _getStringLiteral(ps);
    if (FluentParserStream.isNumberStart(ch)) return _getNumberLiteral(ps);
    throw ExpectedCharRangeError('string or number literal', ps.index);
  }

  /// Parse a `"..."` string literal. The returned [StringLiteral.value]
  /// holds the **raw source content** between the quotes, with escape
  /// sequences preserved as their literal characters (e.g. `\\` stays as
  /// `\\`, `\uXXXX` stays as `\uXXXX`). Decoding into actual codepoints
  /// is the runtime resolver's job — see `unescapeFluentString`.
  ///
  /// Escapes are still VALIDATED here (so `\q` raises [UnknownEscapeSequenceError]
  /// and `\uXX` raises [InvalidUnicodeEscapeSequenceError] at parse time)
  /// — only the decoded codepoint is deferred.
  StringLiteral _getStringLiteral(FluentParserStream ps) {
    final start = ps.index;
    ps.expectChar('"');
    final contentStart = ps.index;
    while (true) {
      final ch = ps.currentChar();
      if (ch == eof || ch == eol) {
        throw UnterminatedStringError(ps.index);
      }
      if (ch == '"') break;
      if (ch == r'\') {
        // Validate the escape but don't decode — index advances past the
        // whole sequence so the raw slice picks it up verbatim.
        _validateEscapeSequence(ps);
      } else {
        ps.next();
      }
    }
    final contentEnd = ps.index;
    ps.expectChar('"');
    return StringLiteral(
      ps.slice(contentStart, contentEnd),
      span: _spanIfTracking(start, ps.index),
    );
  }

  /// Validate an escape sequence at the current position WITHOUT decoding
  /// it. Advances past `\`, the kind char, and any required hex digits.
  /// Throws on unknown or malformed sequences.
  ///
  /// Per Fluent Syntax 1.0:
  ///   `\\`     → backslash
  ///   `\"`     → double quote
  ///   `\uXXXX`   → 4-hex BMP Unicode escape
  ///   `\UXXXXXX` → 6-hex full-range Unicode escape
  ///
  /// Anything else is E0025 (unknown escape).
  void _validateEscapeSequence(FluentParserStream ps) {
    // `\` was already at currentChar — consume it.
    ps.next();
    final ch = ps.currentChar();
    if (ch.isEmpty) {
      throw UnknownEscapeSequenceError('', ps.index);
    }
    switch (ch) {
      case r'\':
      case '"':
        ps.next();
        return;
      case 'u':
        ps.next();
        _validateUnicodeEscape(ps, 4);
        return;
      case 'U':
        ps.next();
        _validateUnicodeEscape(ps, 6);
        return;
      default:
        throw UnknownEscapeSequenceError('\\$ch', ps.index);
    }
  }

  /// Validate `[hexDigits]` hex characters at the current position.
  /// Advances the index past them. Throws if any character is not a
  /// hex digit, or if the resulting codepoint exceeds U+10FFFF.
  void _validateUnicodeEscape(FluentParserStream ps, int hexDigits) {
    final start = ps.index;
    final buffer = StringBuffer();
    for (var i = 0; i < hexDigits; i++) {
      final ch = ps.currentChar();
      if (ch.isEmpty || !_isHex(ch)) {
        throw InvalidUnicodeEscapeSequenceError(
          ps.slice(start - 2, ps.index),
          start - 2,
        );
      }
      buffer.write(ch);
      ps.next();
    }
    final code = int.parse(buffer.toString(), radix: 16);
    if (code > _maxUnicodeCodepoint) {
      throw InvalidUnicodeEscapeSequenceError(
        ps.slice(start - 2, ps.index),
        start - 2,
      );
    }
  }

  static bool _isHex(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return (c >= 0x30 && c <= 0x39) || // 0-9
        (c >= 0x41 && c <= 0x46) || // A-F
        (c >= 0x61 && c <= 0x66); // a-f
  }

  // ── Span helpers ────────────────────────────────────────────────────────

  Span? _spanIfTracking(int start, int end) =>
      withSpans ? Span(start, end) : null;

  int _messageStart(Message m, Comment c) =>
      withSpans ? (c.span?.start ?? m.span?.start ?? 0) : 0;

  int _termStart(Term t, Comment c) =>
      withSpans ? (c.span?.start ?? t.span?.start ?? 0) : 0;
}

// ── Parser-internal types ─────────────────────────────────────────────────

/// One element collected by `_getPattern` before dedentation. Keeps text
/// runs, placeables, and indent markers in a single list so dedent can
/// adjust just the indents.
sealed class _PatternBuildItem {
  const _PatternBuildItem();
}

class _TextElementChunk extends _PatternBuildItem {
  const _TextElementChunk(this.text);
  final TextElement text;
}

class _PlaceableElement extends _PatternBuildItem {
  const _PlaceableElement(this.placeable);
  final Placeable placeable;
}

/// Captured leading-blank chars at the start of a pattern continuation line.
/// Two separate runs: `eol` (zero or more `\n`s, kept as-is) + `inline`
/// (zero or more spaces, common-indent-stripped at dedent time).
class _Indent extends _PatternBuildItem {
  const _Indent(this.eol, this.inline, this.start, this.end);
  final String eol;
  final String inline;
  final int start;
  final int end;
}
