// fluent_bundle showcase — every core capability in one runnable file.
//
// The whole tour lives in this one file because pub.dev renders it on the
// package's Example tab — splitting it would hide everything else from
// that page. `test/example/example_test.dart` runs this exact showcase
// and pins its output, so every line below is proven, not aspirational.
//
// The core is backend-blind: everything here renders through the
// spec-fallback `FluentBackend` (plurals always `other`, digit-correct
// locale-blind numbers, ISO-8601 dates). For CLDR-aware output swap in a
// satellite backend — `IcuBackend` (fluent_icu) or `IntlBackend`
// (fluent_intl) — without touching a single message.
//
// Run with: dart run example/main.dart

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_bundle/markup.dart';
import 'package:fluent_bundle/syntax.dart';

/// Every section of the tour, as `label: value` lines. The example test
/// asserts on these — keep labels stable.
List<String> runShowcase() => [
  ...parsingShowcase(),
  ...formattingShowcase(),
  ...selectorShowcase(),
  ...builtinShowcase(),
  ...bidiAndTransformShowcase(),
  ...customFunctionShowcase(),
  ...errorShowcase(),
  ...hotReloadShowcase(),
  ...localeChainShowcase(),
  ...markupShowcase(),
];

// ── §1 Syntax barrel — parse FTL to a spanned AST ──────────────────────

List<String> parsingShowcase() {
  final resource = FluentParser().parse('''
# A comment attached to the message below.
hello = Hello, world!
-brand = Fluent
0bad = ids cannot start with a digit — recovered as a Junk entry
''');
  final messages = resource.body.whereType<Message>().toList();
  final terms = resource.body.whereType<Term>().toList();
  final junk = resource.body.whereType<Junk>().toList();
  final hello = messages.first;
  return [
    'parse.messages: ${messages.length}',
    'parse.terms: ${terms.length}',
    'parse.junk: ${junk.length}',
    'parse.comment: ${hello.comment?.content}',
    'parse.span: ${hello.span?.start}..${hello.span?.end}',
    // The string unescaper is the same one the parser uses for literals.
    'parse.unescape: ${unescapeFluentString(r'caf\u00E9')}',
  ];
}

// ── §2 Bundle — messages, arguments, attributes, terms ─────────────────

List<String> formattingShowcase() {
  final bundle = FluentBundle('en', useIsolating: false)..addResource(r'''
-brand = Fluent
welcome = Welcome to { -brand }, { $name }!
login = Sign in
    .title = Sign in to { -brand }
    .aria-label = Sign in button
''');
  return [
    'bundle.hasMessage: ${bundle.hasMessage('welcome')}',
    'bundle.getMessage: ${bundle.getMessage('login')?.attributes.keys.join(',')}',
    'format.args: ${bundle.formatMessage('welcome', args: {'name': 'Aria'})}',
    "format.attribute: ${bundle.formatMessage('login', attribute: 'title')}",
  ];
}

// ── §3 Selectors — exact keys always match; plurals are backend work ───

List<String> selectorShowcase() {
  // The spec-fallback backend classifies every number as `other`, so the
  // `[one]` variant below only fires via its EXACT-number sibling `[1]`.
  // Swap in a satellite backend and `[one]` fires for 1 through CLDR.
  final bundle = FluentBundle('en', useIsolating: false)..addResource(r'''
items = { $count ->
    [1] one item
   *[other] { $count } items
}
platform = { $os ->
    [mac] Command
   *[other] Control
}
''');
  return [
    'select.exact: ${bundle.formatMessage('items', args: {'count': 1})}',
    'select.other: ${bundle.formatMessage('items', args: {'count': 5})}',
    'select.string: ${bundle.formatMessage('platform', args: {'os': 'mac'})}',
  ];
}

// ── §4 Builtins — NUMBER and DATETIME with the ECMA-402 option bags ────

List<String> builtinShowcase() {
  // The core validates the full ECMA-402 option surface; the spec-fallback
  // backend honors every DIGIT option (locale-blind, no grouping) and
  // renders dates as ISO-8601. Satellites render the rest (currency,
  // units, styles, calendars, time zones).
  final bundle = FluentBundle('en', useIsolating: false)..addResource(r'''
padded = { NUMBER($n, minimumFractionDigits: 2) }
sig = { NUMBER($n, maximumSignificantDigits: 3) }
launched = { DATETIME($at) }
''');
  final at = DateTime.utc(2026, 1, 15, 12, 30);
  return [
    'number.minFractionDigits: ${bundle.formatMessage('padded', args: {'n': 2})}',
    'number.significant: ${bundle.formatMessage('sig', args: {'n': 3.14159})}',
    'datetime.iso: ${bundle.formatMessage('launched', args: {'at': at})}',
  ];
}

// ── §5 Bidi isolation + pseudo-localization transform ──────────────────

List<String> bidiAndTransformShowcase() {
  const ftl = r'hello = Hello, { $name }!';
  // Default: substituted values are wrapped in FSI (U+2068) / PDI
  // (U+2069) so RTL user content can't reorder the surrounding text.
  final isolating = FluentBundle('en')..addResource(ftl);
  final plain = FluentBundle('en', useIsolating: false)..addResource(ftl);
  // `transform` rewrites author-written pattern text only — substituted
  // values and string literals pass through untouched. The classic use is
  // pseudo-localization during QA.
  final pseudo = FluentBundle(
    'en',
    useIsolating: false,
    transform: (text) => text.toUpperCase(),
  )..addResource(ftl);
  final args = {'name': 'Aria'};
  return [
    'bidi.isolated: ${isolating.formatMessage('hello', args: args)}',
    'bidi.plain: ${plain.formatMessage('hello', args: args)}',
    'transform.pseudo: ${pseudo.formatMessage('hello', args: args)}',
  ];
}

// ── §6 Custom functions — extend FTL's callable surface ────────────────

List<String> customFunctionShowcase() {
  final bundle = FluentBundle(
    'en',
    useIsolating: false,
    functions: {
      'STRLEN':
          (positional, named, context) =>
              FluentNumber(positional.first.format(context).length),
    },
  )..addResource(r'len = { $word } has { STRLEN($word) } letters');
  return [
    'function.custom: ${bundle.formatMessage('len', args: {'word': 'fluent'})}',
  ];
}

// ── §7 Errors are inert values — output always comes back ──────────────

List<String> errorShowcase() {
  final bundle = FluentBundle('en', useIsolating: false);
  final load = bundle.addResource(r'''
mv = Hello { $missing }
loop = looping { loop }
0bad = ids cannot start with a digit
''');
  final missingVar = <FluentError>[];
  final mv = bundle.formatMessage('mv', errors: missingVar);
  final cyclic = <FluentError>[];
  final loop = bundle.formatMessage('loop', errors: cyclic);
  final missingMsg = <FluentError>[];
  final gone = bundle.formatMessage('nope', errors: missingMsg);
  return [
    'errors.parseJunk: ${load.junk.length}',
    'errors.missingVariable: $mv (${missingVar.length} error)',
    'errors.cycle: output=${loop.isNotEmpty} errors=${cyclic.length}',
    'errors.missingMessage: $gone (${missingMsg.length} error)',
  ];
}

// ── §8 Hot reload — allowOverrides replaces messages in place ───────────

List<String> hotReloadShowcase() {
  final bundle = FluentBundle('en', useIsolating: false)
    ..addResource('status = v1');
  final rejected = bundle.addResource('status = v2-rejected');
  final before = bundle.formatMessage('status');
  bundle.addResource('status = v2', allowOverrides: true);
  return [
    'reload.duplicateRejected: ${rejected.errors.length} error, still $before',
    'reload.afterOverride: ${bundle.formatMessage('status')}',
  ];
}

// ── §9 Locale fallback chain ────────────────────────────────────────────

List<String> localeChainShowcase() {
  // The first locale drives formatting and plural lookup in the backend;
  // the rest document the negotiation chain the app resolved.
  final bundle = FluentBundle.locales(['de-CH', 'de', 'en'])
    ..addResource('greet = Grüezi!');
  return [
    'locales.chain: ${bundle.locales.join(' → ')}',
    'locales.format: ${bundle.formatMessage('greet')}',
  ];
}

// ── §10 Markup barrel — inline tags become a walkable span tree ─────────

List<String> markupShowcase() {
  final bundle = FluentBundle('en', useIsolating: false)..addResource(
    r'banner = Try <bold>{ $plan }</bold> — <cta href="/buy">upgrade</cta>!',
  );
  final spans = bundle.formatMessageAsSpans('banner', args: {'plan': 'Pro'});
  final cta = spans.whereType<FluentMarkupSpan>().last;
  return [
    'markup.spans: ${spans.map(describeSpan).join(' | ')}',
    'markup.attr: ${cta.tag} href=${cta.attrs['href']}',
    // The parser is also usable standalone on any resolved string.
    "markup.standalone: ${parseFluentMarkup('a <i>b</i> c').map(describeSpan).join(' | ')}",
  ];
}

/// One-line rendering of a span node for the tour output.
String describeSpan(FluentSpan span) => switch (span) {
  FluentTextSpan(:final text) => 'text(${text.trim()})',
  FluentMarkupSpan(:final tag, :final children) =>
    '$tag(${children.map(describeSpan).join(' ')})',
};

void main() => runShowcase().forEach(print);
