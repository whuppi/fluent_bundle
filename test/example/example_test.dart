// Runs the pub.dev showcase (example/main.dart) and pins its output —
// every claim on the Example tab stays proven. When the showcase gains a
// section, pin its lines here in the same commit.

import 'package:test/test.dart';

import '../../example/main.dart';

void main() {
  late Map<String, String> lines;

  setUpAll(() {
    lines = {
      for (final line in runShowcase())
        line.substring(0, line.indexOf(': ')): line.substring(
          line.indexOf(': ') + 2,
        ),
    };
  });

  test('showcase covers every section with unique labels', () {
    expect(
      lines.keys,
      hasLength(runShowcase().length),
      reason: 'duplicate showcase labels would hide a pinned line',
    );
  });

  test('syntax barrel — parse, spans, comments, junk, unescape', () {
    expect(lines['parse.messages'], '1');
    expect(lines['parse.terms'], '1');
    expect(lines['parse.junk'], '1');
    expect(lines['parse.comment'], 'A comment attached to the message below.');
    expect(lines['parse.span'], '0..65');
    expect(lines['parse.unescape'], 'café');
  });

  test('bundle — lookup, args, attributes, terms', () {
    expect(lines['bundle.hasMessage'], 'true');
    expect(lines['bundle.getMessage'], 'title,aria-label');
    expect(lines['format.args'], 'Welcome to Fluent, Aria!');
    expect(lines['format.attribute'], 'Sign in to Fluent');
  });

  test('selectors — exact number keys and defaults on the base backend', () {
    expect(lines['select.exact'], 'one item');
    expect(lines['select.other'], '5 items');
    expect(lines['select.string'], 'Command');
  });

  test('builtins — digit options honored, dates ISO-8601', () {
    expect(lines['number.minFractionDigits'], '2.00');
    expect(lines['number.significant'], '3.14');
    expect(lines['datetime.iso'], '2026-01-15T12:30:00.000Z');
  });

  test('bidi isolation and the pseudo-localization transform', () {
    expect(lines['bidi.isolated'], 'Hello, \u2068Aria\u2069!');
    expect(lines['bidi.plain'], 'Hello, Aria!');
    expect(lines['transform.pseudo'], 'HELLO, Aria!');
  });

  test('custom functions', () {
    expect(lines['function.custom'], 'fluent has 6 letters');
  });

  test('errors are inert values — output always comes back', () {
    expect(lines['errors.parseJunk'], '1');
    expect(lines['errors.missingVariable'], r'Hello {$missing} (1 error)');
    expect(lines['errors.cycle'], 'output=true errors=1');
    expect(lines['errors.missingMessage'], 'nope (1 error)');
  });

  test('hot reload — duplicates rejected, allowOverrides replaces', () {
    expect(lines['reload.duplicateRejected'], '1 error, still v1');
    expect(lines['reload.afterOverride'], 'v2');
  });

  test('locale fallback chain', () {
    expect(lines['locales.chain'], 'de-CH → de → en');
    expect(lines['locales.format'], 'Grüezi!');
  });

  test('markup — span tree, attributes, standalone parser', () {
    expect(
      lines['markup.spans'],
      'text(Try) | bold(text(Pro)) | text(—) | cta(text(upgrade)) | text(!)',
    );
    expect(lines['markup.attr'], 'cta href=/buy');
    expect(lines['markup.standalone'], 'text(a) | i(text(b)) | text(c)');
  });
}
