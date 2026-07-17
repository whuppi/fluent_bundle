<!--
  Banner stays <picture> for GitHub's dark/light rendering. pub.dev strips
  <picture> when sanitizing the README and falls back to the inner <img>
  (the light variant) — which renders fine there. The heavy *-3x.png
  sources stay tracked in git; only the optimized *-web-min.webp files
  ship in the pub archive (see .pubignore). Drop the <picture> wrapper
  once pub.dev renders it. Tracking: dart-lang/pub-dev#5923.
-->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)"  srcset="assets/fluent_bundle-banner-dark-web-min.webp">
    <source media="(prefers-color-scheme: light)" srcset="assets/fluent_bundle-banner-light-web-min.webp">
    <img alt="fluent_bundle — Project Fluent for Dart & Flutter"
         src="assets/fluent_bundle-banner-light-web-min.webp" width="100%">
  </picture>
</p>

<p align="center">
  <a href="https://pub.dev/packages/fluent_bundle"><img src="https://img.shields.io/pub/v/fluent_bundle.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/fluent_bundle/score"><img src="https://img.shields.io/pub/likes/fluent_bundle" alt="likes"></a>
  <a href="https://pub.dev/packages/fluent_bundle/score"><img src="https://img.shields.io/pub/points/fluent_bundle" alt="pub points"></a>
  <a href="https://github.com/whuppi/fluent_bundle"><img src="https://img.shields.io/github/stars/whuppi/fluent_bundle?style=flat&logo=github" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</p>

[Project Fluent](https://projectfluent.org/) is Mozilla's translation system — the one Firefox uses — now for Dart and Flutter. Your code asks for a message by name and passes in values; a translator writes what that message says in a plain `.ftl` text file, including the plural and gender rules their language needs. This package reads those files and gives you back the finished text. A broken translation never crashes your app — it returns the best text it can and hands you the error separately.

Pure Dart. No native code, no build step, no platform plugins — the same package runs in a phone app, a command-line tool, a server, and a browser tab.

> **Building a Flutter app?** Start with [`fluent_flutter`](https://pub.dev/packages/fluent_flutter) — it includes everything here and adds the Flutter parts: loading `.ftl` files from your assets, switching languages, the `MaterialApp` hook-up, and widgets. Use this package on its own for pure Dart: command-line tools, servers, your own setup.

> **Status:** 0.x. The API can change between minor versions until `1.0.0` — pre-1.0, the minor is the breaking axis, so pin `^0.N.0` and read the changelog on minor bumps.

> like it? a [⭐ star](https://github.com/whuppi/fluent_bundle) or [👍 like](https://pub.dev/packages/fluent_bundle) is the entire marketing budget. [Bugs & features →](https://github.com/whuppi/fluent_bundle/issues)

---

<details>
<summary><b>👀 Peek inside</b></summary>

- [Install](#install)
- [Quick start](#quick-start)
- [Numbers, dates, and plurals need a backend](#numbers-dates-and-plurals-need-a-backend)
- [Usage](#usage)
  - [Messages, terms, attributes](#messages-terms-attributes)
  - [Selectors and plurals](#selectors-and-plurals)
  - [NUMBER and DATETIME](#number-and-datetime)
  - [Right-to-left text and transforms](#right-to-left-text-and-transforms)
  - [Custom functions](#custom-functions)
  - [Locale negotiation and bundle chains](#locale-negotiation-and-bundle-chains)
  - [Inline markup](#inline-markup)
  - [Live updates](#live-updates)
  - [Using the parser on its own](#using-the-parser-on-its-own)
- [Error handling](#error-handling)
- [Platform support](#platform-support)
- [When to use Fluent (and when not)](#when-to-use-fluent-and-when-not)
- [The family](#the-family)
- [Docs](#docs)
- [License](#license)

</details>

---

## Install

```yaml
dependencies:
  fluent_bundle:
```

Nothing else to do, on any platform.

---

## Quick start

An FTL resource in, a formatted string out — the whole round trip:

```dart
import 'package:fluent_bundle/fluent_bundle.dart';

final bundle = FluentBundle('en')..addResource(r'''
-brand = Fluent
welcome = Welcome to { -brand }, { $name }!
login = Sign in
    .title = Sign in to { -brand }
''');

print(bundle.formatMessage('welcome', args: {'name': 'Aria'}));
// "Welcome to Fluent, Aria!"  (the name is wrapped so right-to-left text can't scramble the line — see Usage)

print(bundle.formatMessage('login', attribute: 'title'));
// "Sign in to Fluent"
```

Every call works the same way: add `.ftl` text to a bundle, ask for a message by name, pass values as a map. `hasMessage`, `getMessage`, `formatMessage`, and `formatMessageAsSpans` all follow that pattern — each answers a slightly different question.

The FTL syntax itself is the translator's language, not this README's job — the [Fluent syntax guide](https://projectfluent.org/fluent/guide/) covers it in twenty minutes.

---

## Numbers, dates, and plurals need a backend

Getting plurals and number and date formatting right for every language takes a lot of data — which languages have how many plural forms, which use a comma for the decimal point, and so on. `fluent_bundle` doesn't carry that data itself. Instead it hands the formatting to a *backend* that you choose:

|  | Built-in (no backend) | [`fluent_intl`](https://pub.dev/packages/fluent_intl) | [`fluent_icu`](https://pub.dev/packages/fluent_icu) |
|---|---|---|---|
| **Runs on** | nothing extra | `package:intl` | ICU4X via [`icu_kit`](https://pub.dev/packages/icu_kit) |
| **Plurals** | no real rules — everything counts as one category | full rules for every language, plus ordinals (1st, 2nd) | same, for every language |
| **Numbers & dates** | correct digits, but no separators, symbols, or locale styling | locale-aware, most number and date options | every number and date option — units, calendars, time zones, other digit systems |
| **Setup** | none | none | one line at startup; the engine ships with icu_kit |
| **Size added** | none | none (pure Dart) | a compiled engine (icu_kit's README covers trimming it) |

```dart
// Switching backend changes nothing else — same messages, same calls:
final bundle = FluentBundle('pl', backend: IntlBackend())..addResource(ftl);
```

That's the point: your `.ftl` files, your Dart calls, and your tests stay identical no matter which backend you use. Start with the built-in one; when you notice a plural like `[one]` not matching correctly, add `fluent_intl` or `fluent_icu`.

<details>
<summary><b>🧩 what does the built-in option actually do?</b></summary>

<br>

Three honest shortcuts, each easy to spot:

- **Plurals** — every number lands in one catch-all category. Exact-number cases (`[1]`, `[21]`) still match, because that's plain matching, not language data.
- **Numbers** — it applies digit settings (`minimumFractionDigits`, `maximumSignificantDigits`, …) correctly, but without grouping separators or currency symbols.
- **Dates** — it prints the plain ISO date format (`2026-01-15T…`).

Whichever backend you use, `fluent_bundle` still *checks* your option names, so a typo fails the same way everywhere. What changes between backends is how faithfully a value renders — and when a backend can't honour an option, it says so out loud (see [Error handling](#error-handling)).

</details>

---

## Usage

Highlights below — every method and full signature lives in the [API reference](https://pub.dev/documentation/fluent_bundle/latest/). Each snippet's output is checked by the example test, so what you see is what actually renders.

### Messages, terms, attributes

```dart
final bundle = FluentBundle('en', useIsolating: false)..addResource(r'''
-brand = Fluent
welcome = Welcome to { -brand }, { $name }!
login = Sign in
    .title = Sign in to { -brand }
    .aria-label = Sign in button
''');

bundle.formatMessage('welcome', args: {'name': 'Aria'});
// "Welcome to Fluent, Aria!"

// Attributes are sibling patterns on a message — tooltips, ARIA labels,
// placeholder text — addressed by name:
bundle.formatMessage('login', attribute: 'title');
// "Sign in to Fluent"

// Terms (-brand) are private to the FTL file: referenced by messages,
// never formattable from code. Rename the product in ONE line.
```

### Selectors and plurals

A selector picks a variant per argument value. Exact keys always match; plural *categories* (`one`, `few`, `many`) are the backend's job:

```dart
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

bundle.formatMessage('items', args: {'count': 1});      // "one item"
bundle.formatMessage('items', args: {'count': 5});      // "5 items"
bundle.formatMessage('platform', args: {'os': 'mac'});  // "Command"
```

Add `fluent_intl` or `fluent_icu` and a `[one]` variant fires exactly when that language's rules say it should — in Russian, that includes 21, 31, and 101.

### NUMBER and DATETIME

FTL's two built-in functions take options with the same names JavaScript's `Intl` uses:

```dart
final bundle = FluentBundle('en', useIsolating: false)..addResource(r'''
padded = { NUMBER($n, minimumFractionDigits: 2) }
sig = { NUMBER($n, maximumSignificantDigits: 3) }
launched = { DATETIME($at) }
''');

bundle.formatMessage('padded', args: {'n': 2});          // "2.00"
bundle.formatMessage('sig', args: {'n': 3.14159});       // "3.14"
bundle.formatMessage('launched', args: {'at': DateTime.utc(2026, 1, 15, 12, 30)});
// "2026-01-15T12:30:00.000Z"  (ISO-8601 under the built-in fallback)
```

Currency, units, compact notation, calendars, time zones — all of these options are accepted here and take effect once you add a backend; the [`fluent_intl`](https://pub.dev/packages/fluent_intl) and [`fluent_icu`](https://pub.dev/packages/fluent_icu) READMEs show each one with tested output.

### Right-to-left text and transforms

When you drop a value into a message, Fluent wraps it in two invisible marks so that right-to-left text (Arabic, Hebrew) sitting inside a left-to-right sentence — or the reverse — can't visually rearrange the words around it. This is on by default.

```dart
const ftl = r'hello = Hello, { $name }!';

FluentBundle('en')..addResource(ftl);                        // wrapping on (default)
FluentBundle('en', useIsolating: false)..addResource(ftl);   // wrapping off

// `transform` rewrites only the text the translator wrote — the values you
// pass in, and quoted strings, are left alone. The common use is a quick QA
// pass that forces every translated string to stand out on screen:
final pseudo = FluentBundle('en', useIsolating: false,
    transform: (text) => text.toUpperCase())
  ..addResource(ftl);
pseudo.formatMessage('hello', args: {'name': 'Aria'});   // "HELLO, Aria!"
```

Those wrapping marks are invisible on screen but show up in a test's string comparison, so build test bundles with `useIsolating: false` and ship the default on.

### Custom functions

Extend FTL's callable surface — the translator calls your function like a built-in:

```dart
final bundle = FluentBundle('en', useIsolating: false, functions: {
  'STRLEN': (positional, named, context) =>
      FluentNumber(positional.first.format(context).length),
})..addResource(r'len = { $word } has { STRLEN($word) } letters');

bundle.formatMessage('len', args: {'word': 'fluent'});
// "fluent has 6 letters"
```

### Locale negotiation and bundle chains

Two functions turn "the user wants `de-CH`" into "these bundles, in this order":

```dart
// the languages you want × the languages you have → an ordered fallback list.
// Exact match first, then a broader form (de-CH → de), then any variant of
// the language, then the fallback — never something MORE specific than asked.
final chain = negotiateLocaleChain(
  requested: ['de-CH'],
  available: ['en', 'de', 'de-CH', 'fr'],
  fallback: 'en',
);
// ['de-CH', 'de', 'en']

// One bundle per language, then a chain over them: the first bundle that
// HAS a message formats it, in its own language.
final chained = FluentBundleChain([deCh, de, en]);
chained.formatMessage('only-in-english');   // falls through to en
```

A single bundle can also carry the whole list — `FluentBundle.locales(['de-CH', 'de', 'en'])` formats as `de-CH` and remembers the rest for fallback.

<details>
<summary><b>🧩 why "first bundle that owns it", not "merge everything"?</b></summary>

<br>

Merging three languages' files into one bundle would format a German message using the *top* language's plural rules and number formatting — subtly wrong, and the kind of thing nobody catches in review. Keeping the chain separate means each message formats in the language it was written for: a `de` message uses `de` plurals and `de` numbers even when the top of the chain is `de-CH`. The same holds for a missing attribute — a message found in `de` whose attribute is missing reports it there, instead of quietly walking further down the chain.

</details>

### Inline markup

Translators author inline structure — bold spans, links, styled ranges — directly in the message, and it survives translation reordering:

```dart
import 'package:fluent_bundle/markup.dart';

final bundle = FluentBundle('en', useIsolating: false)..addResource(
  r'banner = Try <bold>{ $plan }</bold> — <cta href="/buy">upgrade</cta>!',
);

final spans = bundle.formatMessageAsSpans('banner', args: {'plan': 'Pro'});
// FluentTextSpan("Try ")
// FluentMarkupSpan(bold, children: [FluentTextSpan("Pro")])
// FluentTextSpan(" — ")
// FluentMarkupSpan(cta, attrs: {href: "/buy"}, children: [...])
// FluentTextSpan("!")
```

`formatMessage` on the same message returns the flat string with the tags intact; `formatMessageAsSpans` gives you the tree. The parser (`parseFluentMarkup`) also runs standalone on any resolved string. In Flutter, [`fluent_flutter`](https://pub.dev/packages/fluent_flutter)'s `markup.dart` turns this tree into `InlineSpan`s — styles, tap recognizers, custom builders.

One trap worth knowing: the tags are parsed by an HTML5 parser, so HTML *void elements* (`<link>`, `<br>`, `<img>`) parse childless and would drop the text you meant to wrap. Pick tag names that aren't void elements (`<a>`, `<cta>`, `<bold>` are all fine).

### Live updates

`addResource` rejects a duplicate message id by default — a second file can't silently shadow the first. Pass `allowOverrides: true` to replace in place, which is exactly what a hot-reload or over-the-air translation update wants:

```dart
final bundle = FluentBundle('en', useIsolating: false)
  ..addResource('status = v1');

bundle.addResource('status = v2-rejected');           // 1 error, still "v1"
bundle.addResource('status = v2', allowOverrides: true);
bundle.formatMessage('status');                       // "v2"
```

### Using the parser on its own

`package:fluent_bundle/syntax.dart` gives you the FTL parser as a standalone tool — for linters, editors, string-extraction tools, and code generators. Every node in the parsed tree remembers where it came from in the source, and a broken entry becomes a `Junk` node instead of failing the whole file:

```dart
import 'package:fluent_bundle/syntax.dart';

final resource = FluentParser().parse('''
# A comment attached to the message below.
hello = Hello, world!
0bad = ids cannot start with a digit
''');

resource.body.whereType<Message>().length;   // 1
resource.body.whereType<Junk>().length;      // 1 — recovered, not fatal
resource.body.whereType<Message>().first.comment?.content;
// "A comment attached to the message below."
```

[`fluent_gen`](https://pub.dev/packages/fluent_gen) is built on this parser — the same source positions drive its build-time warnings.

---

## Error handling

A translation system must never crash your app over a bad string. Every failure here is a value, not an exception: formatting always returns text (the best it can manage), and problems go into a list you pass in — or are dropped if you don't:

```dart
final errors = <FluentError>[];
final out = bundle.formatMessage('mv', args: {}, errors: errors);
// out:    "Hello {$missing}"   ← the pattern, with the failed piece visible
// errors: [FluentReferenceError: Unknown variable: $missing]
```

The hierarchy — every subclass of `FluentError`:

| Error | Recorded when |
|---|---|
| `FluentParseError` | An FTL entry didn't parse (also visible as `Junk` on the resource) |
| `FluentReferenceError` | A message / term / variable / function reference points at nothing |
| `FluentCyclicReferenceError` | Message references form a loop — resolution stops, output survives |
| `FluentResolutionLimitError` | A message referenced other messages so deeply it hit the safety limit |
| `FluentTypeError` | A value or formatting option couldn't be applied (the "when a backend can't do something" case, below) |
| `FluentArgumentError` | A function received arguments it can't accept |
| `FluentFormatError` | A backend formatter rejected the input value |
| `FluentOverrideError` | `addResource` hit a duplicate id without `allowOverrides` |

**When a backend can't do something.** A backend never quietly ignores an option it can't handle. It renders the closest form it can *and* records a `FluentTypeError` — so your tests catch the gap while users still see reasonable text. The test harness (`package:fluent_bundle/testing.dart`) checks both sides for every known gap, in `fluent_bundle` and in each backend.

A real `throw` is reserved for mistakes in your own code — like adding a resource to a read-only chain, or formatting one bundle's message through a different bundle's chain.

---

## Platform support

Pure Dart, no conditional imports, no platform code:

| Android | iOS | macOS | Windows | Linux | Web | Servers / CLI |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

The test suite runs twice — on the VM and in real Chrome — so "works on web" is a gate, not a hope.

---

## When to use Fluent (and when not)

Most translation tools treat each string as a dictionary entry: one English line, one translated line. That's fine until a language needs grammar English doesn't have — a word that changes with gender, a number with six plural forms, a phrase that bends by grammatical case. In those tools *you* add that logic in your code, and every language is then locked into the same shape.

Fluent works the other way. Each language's `.ftl` file can add its own plurals, genders, and special cases on its own — the German file can make a distinction the English file never makes, and you don't touch a line of code. This is the one thing key-value tools (ARB, slang, easy_localization) can't do: they fix each message's shape once, in code, so every language must match it. Mozilla built Fluent for exactly this, so Firefox's translators could use the full grammar of their language without waiting on an engineer.

**Reach for something simpler if** your app ships one language, or your strings are plain with no real plural or gender needs — a translation system isn't worth the setup for text you never vary.

**Coming from ARB / `flutter_localizations`?** It's official and fine for simple substitutions. Once translators need real per-language plural, gender, or case rules, ARB pushes that logic into ICU MessageFormat strings inside JSON — awkward to write and read. Fluent is built for that case.

**Coming from slang / easy_localization?** Same per-language freedom described above — and [`fluent_gen`](https://pub.dev/packages/fluent_gen) adds the typed `t.welcome(...)` calls those tools are loved for, on top of Fluent.

---

## The family

Five packages. You install `fluent_bundle` plus whichever of the others fit your app.

**Which packages do I install?**
- **Flutter app** → `fluent_flutter` + `fluent_intl`
- …need every language, calendar, and unit, or identical output on every platform → swap `fluent_intl` for `fluent_icu`
- …want typos and missing arguments caught before you run → add `fluent_gen`
- **Pure Dart** (command-line tool, server) → `fluent_bundle` + `fluent_intl` (the same two swaps apply)

| Package | What it adds |
|---|---|
| `fluent_bundle` (this) | Reads `.ftl` files and produces the final text — plus markup, language fallback, and the backend hook |
| [`fluent_intl`](https://pub.dev/packages/fluent_intl) | A formatting backend built on `package:intl` — zero setup, pure Dart |
| [`fluent_icu`](https://pub.dev/packages/fluent_icu) | A formatting backend built on ICU4X — every language, every number and date option |
| [`fluent_gen`](https://pub.dev/packages/fluent_gen) | Turns your `.ftl` files into typed Dart calls, so typos and wrong arguments fail to compile |
| [`fluent_flutter`](https://pub.dev/packages/fluent_flutter) | The Flutter parts — switching languages, loading from assets, the `MaterialApp` hook-up, markup widgets, hot reload |

---

## Docs

The README covers the everyday stuff. wanna go deeper?

| Doc | What's inside |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | How it's built: the layers, how backends plug in, the test harness |
| [Capabilities](docs/CAPABILITY_ROADMAP.md) | What's shipped, what's planned, what won't happen |
| [Updating](docs/UPDATING.md) | Maintenance recipes, the spec watchlist, the family release checklist |
| [Example](example/) | The whole tour in one runnable file, output checked by test |

---

## License

MIT. See [LICENSE](LICENSE).
