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

[Project Fluent](https://projectfluent.org/) — Mozilla's localization system, the one Firefox ships — for Dart & Flutter. Translators write plurals, gender, and per-locale special cases directly in the `.ftl` file; your code asks for a message by id and passes arguments. This package is the complete runtime: a spec-complete parser, a resolver where every failure is a value instead of a crash, inline markup that comes back as a walkable span tree, locale negotiation, and a pluggable backend seam for CLDR-grade formatting.

Pure Dart. No native code, no build steps, no platform plugins — the same package runs in a phone app, a CLI, a server, and a browser tab.

> **Building a Flutter app?** Start at [`fluent_flutter`](https://pub.dev/packages/fluent_flutter) — it re-exports this entire runtime and adds the app wiring: asset loading, locale lifecycle, delegates, widgets. This package is the front door for pure Dart — CLIs, servers, your own integrations.

> **Status:** 0.x. The API can change between minor versions until `1.0.0` — pre-1.0, the minor is the breaking axis, so pin `^0.N.0` and read the changelog on minor bumps.

> like it? a [⭐ star](https://github.com/whuppi/fluent_bundle) or [👍 like](https://pub.dev/packages/fluent_bundle) is the entire marketing budget. [Bugs & features →](https://github.com/whuppi/fluent_bundle/issues)

---

<details>
<summary><b>👀 Peek inside</b></summary>

- [Install](#install)
- [Quick start](#quick-start)
- [The backend seam](#the-backend-seam)
- [Usage](#usage)
  - [Messages, terms, attributes](#messages-terms-attributes)
  - [Selectors and plurals](#selectors-and-plurals)
  - [NUMBER and DATETIME](#number-and-datetime)
  - [Bidi isolation and transforms](#bidi-isolation-and-transforms)
  - [Custom functions](#custom-functions)
  - [Locale negotiation and bundle chains](#locale-negotiation-and-bundle-chains)
  - [Inline markup](#inline-markup)
  - [Live updates](#live-updates)
  - [The syntax barrel](#the-syntax-barrel)
- [Error handling](#error-handling)
- [Platform support](#platform-support)
- [Choosing Fluent (and when not to)](#choosing-fluent-and-when-not-to)
- [The family](#the-family)
- [Docs](#docs)
- [License](#license)

</details>

---

## Install

```yaml
dependencies:
  fluent_bundle: ^0.1.0-dev.0
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
// "Welcome to Fluent, Aria!"  (the value is bidi-isolated — see Usage)

print(bundle.formatMessage('login', attribute: 'title'));
// "Sign in to Fluent"
```

That's the shape of every call: add FTL to a bundle, ask for a message by id, pass arguments as a map. `hasMessage`, `getMessage`, `formatMessage`, `formatMessageAsSpans` — same shape, a different question.

The FTL syntax itself is the translator's language, not this README's job — the [Fluent syntax guide](https://projectfluent.org/fluent/guide/) covers it in twenty minutes.

---

## The backend seam

Plural rules and locale-aware formatting are *data* problems — CLDR knows that Polish has four plural forms and that German swaps the comma and the period. The core deliberately doesn't carry that data. Instead, every `FluentBundle` formats through a `FluentBackend`, and you pick which one:

|  | Spec fallback (built in) | [`fluent_intl`](https://pub.dev/packages/fluent_intl) | [`fluent_icu`](https://pub.dev/packages/fluent_icu) |
|---|---|---|---|
| **Engine** | none — pure spec behavior | `package:intl` | ICU4X via [`icu_kit`](https://pub.dev/packages/icu_kit) |
| **Plural rules** | everything is `other` | CLDR cardinals + ordinals | CLDR cardinals + ordinals, every locale |
| **NUMBER / DATETIME** | digit options only, ISO-8601 dates | locale-aware, most ECMA-402 options | full ECMA-402: units, calendars, time zones, numbering systems |
| **Setup** | nothing | nothing | one init call; icu_kit ships the engine |
| **Footprint** | zero | pure Dart | a compiled engine (icu_kit's README has the size dial) |

```dart
// The one-line swap — no message changes, no call-site changes:
final bundle = FluentBundle('pl', backend: IntlBackend())..addResource(ftl);
```

The seam is the whole point: your FTL, your call sites, and your tests are identical under every backend. Start with the built-in fallback, feel the moment `[one]` stops matching, add a satellite.

<details>
<summary><b>🧩 what exactly does the built-in fallback do?</b></summary>

<br>

Three honest simplifications, each loud enough to notice:

- **Plural categories** — every number classifies as `other`. Exact-number variants (`[1]`, `[21]`) still match, because exact matching is spec behavior, not CLDR data.
- **NUMBER** — honors every ECMA-402 *digit* option (`minimumFractionDigits`, `maximumSignificantDigits`, …) with locale-blind rendering: correct digits, no grouping separators, no symbols.
- **DATETIME** — renders ISO-8601.

The full option surface is *validated* by the core regardless of backend, so a typo'd option name fails the same way everywhere. What varies per backend is rendering fidelity — and where a backend can't honor an option, it degrades loud (see [Error handling](#error-handling)).

</details>

---

## Usage

Highlights below — every method and full signature lives in the [API reference](https://pub.dev/documentation/fluent_bundle/latest/). Each snippet's output is pinned by the example test, so what you see is what actually renders.

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

Swap in a satellite backend and a `[one]` variant fires exactly when that locale's CLDR rules say it should — in Russian, that includes 21, 31, and 101.

### NUMBER and DATETIME

FTL's two built-in functions take the ECMA-402 option bags — the same names JavaScript's `Intl` uses:

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

Currency, units, compact notation, calendars, time zones — the full bags are accepted here and rendered by the satellites; each satellite's README shows its surface with pinned output.

### Bidi isolation and transforms

```dart
const ftl = r'hello = Hello, { $name }!';

// Default: substituted values are wrapped in FSI (U+2068) / PDI (U+2069)
// so RTL user content can't visually reorder the surrounding text.
FluentBundle('en')..addResource(ftl);                        // isolation on
FluentBundle('en', useIsolating: false)..addResource(ftl);   // plain output

// `transform` rewrites author-written pattern text only — substituted
// values and string literals pass through untouched. The classic use is
// pseudo-localization during QA: every hardcoded string in the UI stays
// lowercase and exposes itself.
final pseudo = FluentBundle('en', useIsolating: false,
    transform: (text) => text.toUpperCase())
  ..addResource(ftl);
pseudo.formatMessage('hello', args: {'name': 'Aria'});   // "HELLO, Aria!"
```

The isolation marks are invisible in a UI and jarring in a test assertion — construct test bundles with `useIsolating: false`, ship the default.

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

Two primitives turn "the user wants `de-CH`" into "these bundles, in this order":

```dart
// requested tags × available tags → an ordered fallback chain.
// Exact match, then truncation (de-CH → de), then a language-prefix
// bridge, then the fallback — never pulling in a MORE specific variant.
final chain = negotiateLocaleChain(
  requested: ['de-CH'],
  available: ['en', 'de', 'de-CH', 'fr'],
  fallback: 'en',
);
// ['de-CH', 'de', 'en']

// One bundle per chain member, then a chain view over them: the first
// bundle that OWNS a message formats it, in its own locale's context.
final chained = FluentBundleChain([deCh, de, en]);
chained.formatMessage('only-in-english');   // falls through to en
```

A single bundle can also carry the chain for the backend's benefit — `FluentBundle.locales(['de-CH', 'de', 'en'])` formats as `de-CH` and documents the rest.

<details>
<summary><b>🧩 why "first bundle that owns it", not "merge everything"?</b></summary>

<br>

Merging resources from three locales into one bundle would format a German message with the *chain head's* plural rules and formatters — subtly wrong in ways nobody catches in review. The chain view keeps each message in the locale it was written for: a `de` message formats with `de` plurals and `de` numbers even when the chain head is `de-CH`. Attribute misses stay on the owning bundle too — a message found in `de` whose attribute is absent reports the miss there instead of silently walking further down.

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

One trap worth knowing: the tags ride an HTML5 parser, so HTML *void elements* (`<link>`, `<br>`, `<img>`) parse childless and would swallow the text you meant to wrap. Pick tag names that aren't void elements (`<a>`, `<cta>`, `<bold>` are all fine).

### Live updates

`addResource` rejects a duplicate message id by default — a second file can't silently shadow the first. Pass `allowOverrides: true` to replace in place, which is exactly what a hot-reload or over-the-air translation update wants:

```dart
final bundle = FluentBundle('en', useIsolating: false)
  ..addResource('status = v1');

bundle.addResource('status = v2-rejected');           // 1 error, still "v1"
bundle.addResource('status = v2', allowOverrides: true);
bundle.formatMessage('status');                       // "v2"
```

### The syntax barrel

`package:fluent_bundle/syntax.dart` is the parser as a standalone tool — for linters, editors, extraction tooling, and generators. Every AST node carries its source span; malformed entries become `Junk` nodes instead of failing the file:

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

[`fluent_gen`](https://pub.dev/packages/fluent_gen) is built on this barrel — the same spans power its build-time diagnostics.

---

## Error handling

A localization runtime must never take the app down over a bad translation. Every failure here is an **inert value**: formatting always returns output (the best rendering it can), and problems land in a list you pass in — or are dropped if you don't:

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
| `FluentResolutionLimitError` | A pattern expanded past the spec's placeable limit |
| `FluentTypeError` | A value or formatting option can't be honored (this is the degrade signal — see below) |
| `FluentArgumentError` | A function received arguments it can't accept |
| `FluentFormatError` | A backend formatter rejected the input value |
| `FluentOverrideError` | `addResource` hit a duplicate id without `allowOverrides` |

**The degrade contract.** Backends never silently drop an option they can't honor. They render the nearest supported form *and* record a `FluentTypeError` — so QA sees every gap in the error stream while users still see reasonable output. The conformance harness (`package:fluent_bundle/testing.dart`) proves this in both directions for every declared gap, in the core and in every satellite.

Plain `throw`s are reserved for programmer error — adding a resource to a read-only chain view, formatting a foreign bundle's pattern through a chain.

---

## Platform support

Pure Dart, no conditional imports, no platform code:

| Android | iOS | macOS | Windows | Linux | Web | Servers / CLI |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

The test suite runs twice — on the VM and in real Chrome — so "works on web" is a gate, not a hope.

---

## Choosing Fluent (and when not to)

Fluent's pitch over key-value formats (ARB, JSON): **grammar lives in the translation file, not in your code.** A Polish translator writes Polish's four plural forms in the `.ftl`; your Dart passes `count` and never learns Polish grammar. Message references keep product names in one line. Selectors handle gender and platform variants without new code paths.

**"I already use ARB / `flutter_localizations` gen-l10n."** Keep it if your strings are simple substitutions — it's official and well-worn. The moment translators need real plural/gender/case logic per locale, ARB pushes that logic into ICU MessageFormat strings inside JSON, which nobody enjoys editing. Fluent is the format designed for exactly that moment.

**"I use slang / easy_localization."** Same trade: excellent ergonomics over key-value maps, and the grammar ceiling arrives with the first grammatically-rich locale. Fluent raises the ceiling; [`fluent_gen`](https://pub.dev/packages/fluent_gen) gives you back the typed-accessor ergonomics.

And if your app ships one language and never will more — string constants. Don't add a localization runtime for data you never vary.

---

## The family

One core, four satellites — add exactly what your app needs:

| Package | What it adds |
|---|---|
| `fluent_bundle` (this) | The runtime: parser, resolver, markup, negotiation, backend seam |
| [`fluent_intl`](https://pub.dev/packages/fluent_intl) | CLDR backend on `package:intl` — zero setup, pure Dart |
| [`fluent_icu`](https://pub.dev/packages/fluent_icu) | Full-fidelity ECMA-402 backend on ICU4X — every locale, every option |
| [`fluent_gen`](https://pub.dev/packages/fluent_gen) | Build-time typed accessors — message ids and arguments checked by the analyzer |
| [`fluent_flutter`](https://pub.dev/packages/fluent_flutter) | Flutter integration — locale lifecycle, asset loading, delegates, `InlineSpan` markup, hot reload |

---

## Docs

The README covers the everyday stuff. wanna go deeper?

| Doc | What's inside |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | How it's built: the layers, the backend seam, the conformance harness |
| [Capabilities](docs/CAPABILITY_ROADMAP.md) | What's shipped, what's planned, what won't happen |
| [Updating](docs/UPDATING.md) | Maintenance recipes, the spec watchlist, the family release checklist |
| [Example](example/) | The whole tour in one runnable file, output pinned by test |

---

## License

MIT. See [LICENSE](LICENSE).
