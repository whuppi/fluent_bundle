/// Decodes escape sequences inside a Fluent string-literal value.
///
/// Per the Fluent Syntax 1.0 spec, the parser preserves escape sequences
/// in `StringLiteral.value` as their literal characters (`\\` stays as
/// `\\`, `\uXXXX` stays as `\uXXXX`). The runtime resolver decodes them
/// when the literal is rendered into a pattern. This function is that
/// decoder.
///
/// Recognized sequences:
///   - `\\` → `\` (single backslash)
///   - `\"` → `"` (double quote)
///   - `\uXXXX` → BMP codepoint named by 4 hex digits
///   - `\UXXXXXX` → full-range codepoint named by 6 hex digits
///
/// Malformed input is decoded best-effort: the parser already validated
/// every sequence, so a value reaching this function is well-formed by
/// construction. Unknown bytes after `\` are passed through unchanged
/// to keep the function total.
String unescapeFluentString(String input) {
  if (!input.contains(r'\')) return input;

  final buffer = StringBuffer();
  final length = input.length;
  var i = 0;
  while (i < length) {
    final ch = input.codeUnitAt(i);
    if (ch != _backslash) {
      buffer.writeCharCode(ch);
      i++;
      continue;
    }
    if (i + 1 >= length) {
      // Trailing backslash — preserve as literal.
      buffer.writeCharCode(_backslash);
      i++;
      continue;
    }
    final kind = input.codeUnitAt(i + 1);
    if (kind == _backslash) {
      buffer.writeCharCode(_backslash);
      i += 2;
    } else if (kind == _quote) {
      buffer.writeCharCode(_quote);
      i += 2;
    } else if (kind == _lowerU) {
      // `\uXXXX` — 4 hex digits.
      buffer.writeCharCode(int.parse(input.substring(i + 2, i + 6), radix: 16));
      i += 6;
    } else if (kind == _upperU) {
      // `\UXXXXXX` — 6 hex digits.
      buffer.writeCharCode(int.parse(input.substring(i + 2, i + 8), radix: 16));
      i += 8;
    } else {
      // Unknown sequence — should never reach here on parser-validated
      // input, but be tolerant.
      buffer.writeCharCode(_backslash);
      i++;
    }
  }
  return buffer.toString();
}

const int _backslash = 0x5C; // \
const int _quote = 0x22; // "
const int _lowerU = 0x75; // u
const int _upperU = 0x55; // U
