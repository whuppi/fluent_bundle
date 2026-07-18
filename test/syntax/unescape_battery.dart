import 'package:fluent_bundle/syntax.dart';
import 'package:test/test.dart';

void registerUnescapeTests() {
  group('unescapeFluentString — recognized escapes', () {
    test(r'\\ decodes to a single backslash', () {
      expect(unescapeFluentString(r'a\\b'), r'a\b');
    });

    test(r'\" decodes to a double quote', () {
      expect(unescapeFluentString(r'say \"hi\"'), 'say "hi"');
    });

    test(r'\uXXXX decodes a 4-hex BMP codepoint', () {
      // U+0041 is "A".
      expect(unescapeFluentString(r'A'), 'A');
      // U+5BD2 is 寒.
      expect(unescapeFluentString(r'Foo 寒 Bar'), 'Foo 寒 Bar');
    });

    test(r'\UXXXXXX decodes a 6-hex codepoint above the BMP', () {
      // U+1F600 — 😀 (emoji needs UTF-16 surrogate pair).
      expect(unescapeFluentString(r'\U01F600'), '😀');
      // U+1F60A — 😊.
      expect(unescapeFluentString(r'Foo \U01F60A Bar'), 'Foo 😊 Bar');
    });

    test('non-escaped content passes through verbatim', () {
      expect(unescapeFluentString('plain'), 'plain');
      expect(unescapeFluentString('café 中文 🎉'), 'café 中文 🎉');
    });

    test('multiple escapes in one string', () {
      expect(unescapeFluentString(r'Hi \"quoted\"\\path'), r'Hi "quoted"\path');
    });
  });

  group('unescapeFluentString — short-circuit', () {
    test('returns the input unchanged when no backslashes are present', () {
      const input = 'no backslashes here';
      expect(identical(unescapeFluentString(input), input), isTrue);
    });
  });

  group(
    'unescapeFluentString — surrogate pairs from \\u (parser-validated)',
    () {
      test('two adjacent \\uXXXX escapes form one BMP+surrogate emoji', () {
        // The parser doesn't reject lone surrogates; it preserves them so
        // a translator's `"😂"` decodes to the emoji 😂. Two
        // UTF-16 code units in sequence form the surrogate pair.
        final out = unescapeFluentString(r'😂');
        expect(out.runes.first, 0x1F602);
      });
    },
  );
}
