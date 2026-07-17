# fluent_bundle — Architecture

How the package is wired. For usage examples see [`../README.md`](../README.md). For capability status see [`CAPABILITY_ROADMAP.md`](CAPABILITY_ROADMAP.md); for maintenance recipes see [`UPDATING.md`](UPDATING.md).

fluent_bundle is the CORE of the fluent family: the Fluent-spec runtime plus the ECMA-402 option contract, with zero locale data. The satellites — `fluent_icu` (ICU4X via icu_kit) and `fluent_intl` (`package:intl`) — implement rendering; each has its own `docs/` tree.

---

## The contract

1. **The core is backend-free, not options-free.** It never imports a
   rendering library and never renders a locale-aware string. It DOES own
   the whole ECMA-402 option contract: the option bags, FTL parsing +
   validation, merge semantics, plural-operand digit math, the error
   shapes, and the conformance harness. The line: *does this code need
   icu_kit or package:intl to run?* No → core. Yes → satellite.
2. **Inert resolution.** `formatMessage` never throws. Every error lands
   on the optional `errors` out-list; the rendered string is always a
   string. One bad reference in a translation never breaks the UI.
3. **Two-stage AST.** A rich, span-tracked syntax AST for tools; a
   compact runtime AST for fast resolution. The compiler lowers one to
   the other; the resolver consumes only the runtime form.
4. **fluent-rs semantics.** Where fluent-rs (Firefox's production
   implementation) and fluent.js deliberately diverge — bidi isolation
   of Message/Term references and StringLiterals — this package follows
   fluent-rs, and the vendored fluent-rs corpus proves it.
5. **The degrade contract.** A backend that cannot honor an option still
   renders the nearest supported form AND records a `FluentTypeError` —
   never a throw, never a silent drop. The error shape is a core factory
   (`FluentTypeError.unsupportedOption`) so every satellite degrades with
   the same sentence, and the conformance harness asserts the contract in
   both directions on every backend.
6. **Plural selection agrees with rendering.** `FluentNumber.resolveDigits`
   computes plural operands with `Intl.PluralRules` semantics — exact
   digit-string + BigInt arithmetic honoring all nine rounding modes,
   `roundingIncrement`, and `trailingZeroDisplay` — so the selected
   variant matches the rendered digits on any backend that supports the
   option, and selection stays identical ACROSS backends when one
   degrades the render.

---

## Source tree

```
lib/
  fluent_bundle.dart           — RUNTIME barrel: FluentBundle, FluentBackend,
                                 values, errors, builtins surface
  markup.dart                  — OPT-IN barrel: FluentSpan tree + parseFluentMarkup
  syntax.dart                  — PARSE-TIME barrel: parser + syntax AST (for tools)
  testing.dart                 — CONFORMANCE barrel: BackendExpectations +
                                 fluentBackendConformanceChecks (for satellites)
  src/
    backend/                   — FluentBackend interface + FluentFormatContext +
                                 PluralCategory; the spec-fallback default backend
    builtins/                  — NUMBER() + DATETIME(): FTL named-arg parsing +
                                 full ECMA-402 value-set validation
    bundle/                    — FluentBundle + FluentBundleChain (locale
                                 fallback across bundles), resolver, scope,
                                 FluentFunction
    compiled/                  — compiler + runtime AST (CompiledMessage /
                                 CompiledTerm / CompiledPattern / expressions)
    errors/                    — sealed FluentError + FluentParseError hierarchies,
                                 the degrade-contract factories, isValidCurrencyCode
    locale/                    — negotiateLocaleChain / negotiateLocale: the one
                                 tag-negotiation ladder (fluent_gen's emitted enum
                                 and fluent_flutter both delegate here)
    markup/                    — FluentSpan tree + the package:html-backed parser
    syntax/
      ast/                     — one Dart library; part-files per node family
      parser/                  — FluentParser + ParserStream
      unescape.dart
    testing/                   — the conformance harness: expectations, harness
                                 (ConformanceHarness + check assembler), and the
                                 check groups (core / number / datetime / degrade)
    values/                    — FluentValue sealed family; digit_resolution.dart
                                 holds resolveDigits' exact-arithmetic machinery
bin/
  watch.dart                   — dev-time .ftl watcher (JSON change events; apps
                                 apply via addResource(allowOverrides: true))
tool/
example/
  main.dart                    — the pub.dev showcase: every core capability in
                                 one runnable file (output pinned by the test)
test/
  _corpus/syntax/              — vendored fluent-rs PARSER fixtures + PROVENANCE.md
                                 (the resolver corpus needs a CLDR backend, so it
                                 lives with each satellite — see their docs/)
  example/example_test.dart    — runs the showcase, pins every output line
  ...                          — mirrors lib/src folder-for-folder
Makefile                       — the gate: `make check` = analyze + floor +
                                 VM suite + chrome suite + example showcase
```

---

## 1. The four barrels

Each barrel pulls only what it needs; consumers pay for nothing they
don't import.

| Barrel | Surface | Who imports it |
|---|---|---|
| `fluent_bundle.dart` | `FluentBundle`, `FluentBackend`, `FluentValue` family + options, errors, `FluentFunction` | Apps (usually via a satellite's re-export) |
| `syntax.dart` | `FluentParser`, the span-tracked syntax AST, `unescapeFluentString`, parse errors | Tools: linters, codegen, editors |
| `markup.dart` | `FluentSpan` sealed tree + `parseFluentMarkup` | Apps rendering inline markup (`<bold>…</bold>`) |
| `testing.dart` | `BackendExpectations`, `ConformanceCheck`, `fluentBackendConformanceChecks` | Satellite test suites |

Each satellite's own barrel re-exports `fluent_bundle.dart`, so a
consumer adds ONE dependency (`fluent_icu` or `fluent_intl`) and one
import gives them `FluentBundle` plus that backend.

---

## 2. Two-stage AST

**Syntax AST** (`src/syntax/ast/`, exported via `syntax.dart`): rich,
span-tracked, loses nothing. Each node carries its source span so tools
point at exact column ranges. One Dart library split across part-files —
the node types are mutually recursive and the shared mixins compose
freely only within one library.

**Runtime AST** (`src/compiled/`): spans stripped, keys interned,
variants pre-indexed. Compiled once per `addResource` and cached. The
resolver consumes only this form.

The compiler (`src/compiled/compiler.dart`) walks the syntax AST
top-down and emits the runtime form.

---

## 3. The resolver

`bundle.formatMessage(id, args: …, errors: …)`:

```
1. Look up CompiledMessage by id
   ├─ missing → record FluentReferenceError, return the id
   └─ found   → resolve its pattern with a fresh Scope
2. Walk the CompiledPattern element by element:
   ├─ text            → append
   └─ placeable       → resolve the expression:
        literals      → FluentString / FluentNumber
        $variable     → coerce the caller's arg to a FluentValue
        message/term  → recurse (cycle-guarded; Scope.dirty)
        FUNCTION(...) → look up in bundle.functions, call, format result
        select { … }  → match variant by (a) exact key, (b) plural
                        category from backend.pluralCategory, (c) default
3. Format leaf values through the backend
   (backend.formatNumber / formatDateTime / plural selection)
4. Apply the bundle transform if set; return the string
```

Guard rails: `MAX_PLACEABLES` halts expansion with
`FluentResolutionLimitError` (Billion-Laughs guard); cyclic references
resolve to the default variant with `FluentCyclicReferenceError` —
including cycles through term-attribute selectors.

### Bidi isolation — fluent-rs semantics

With `useIsolating: true` (default), interpolations in multi-element
patterns are wrapped in FSI (U+2068) / PDI (U+2069). Deliberately
matching fluent-rs, Message references, Term references, and
StringLiterals are NOT isolated (fluent.js isolates all placeables).
The vendored fluent-rs corpus's "(Rust)" fixtures prove this choice;
the fluent.js-behavior fixtures stay upstream-skipped. Do not "fix"
this toward fluent.js — the divergence is documented at
`src/bundle/resolver.dart` `_writePlaceable`.

---

## 4. The option contract

The core owns everything about what NUMBER/DATETIME options *mean*;
satellites own turning them into strings.

- **`FluentNumberOptions` / `FluentDateTimeOptions`** (`src/values/`) —
  every ECMA-402 option as a nullable field; `merge` composes partial
  overrides (named args win). One FTL `useGrouping` key feeds two typed
  fields: booleans → `useGrouping`, the v3 strategy strings
  (`auto`/`always`/`min2`, `"true"` normalizing to `always`) →
  `groupingStrategy`.
- **The builtins** (`src/builtins/`) — parse FTL named args and validate
  every enum-shaped option against its ECMA-402 value set, the
  roundingIncrement cross-constraints, and the Unicode-extension subtag
  shapes. Out-of-set values record a `FluentFormatError` and drop
  (Fluent never throws).
- **`FluentNumber.resolveDigits`** (`src/values/fluent_number.dart` +
  `digit_resolution.dart`) — `Intl.PluralRules` digit resolution:
  significant-digit rules when present, else min/max fraction rules with
  the PluralRules defaults (min 0, max `max(min, 3)`), honoring
  `roundingMode` / `roundingIncrement` / `trailingZeroDisplay`. Exact
  digit-string + BigInt arithmetic on the value's shortest decimal
  representation — the same source both ICU4X and package:intl round
  from. `notation` never affects selection (PluralRules takes rounding
  options but not notation). The result feeds every backend's plural
  selection.
- **The degrade-contract shapes** (`src/errors/fluent_error.dart`) —
  `FluentTypeError.unsupportedOption` (the one sentence every satellite
  degrade records) and `FluentTypeError.invalidCurrencyCode` +
  `isValidCurrencyCode` (strict 3-alpha ECMA well-formedness; both
  backends degrade invalid codes to decimal instead of letting the
  formatter guess).

---

## 5. The FluentBackend interface

```dart
abstract class FluentBackend {
  PluralCategory pluralCategory(
      FluentNumber value, PluralRuleType type, FluentFormatContext context);
  String formatNumber(FluentNumber value, FluentFormatContext context);
  String formatDateTime(FluentDateTime value, FluentFormatContext context);
}
```

The default (spec-fallback) backend classifies every number as `other`
and renders digits / ISO-8601 — correct per spec, zero locale awareness,
zero dependencies. The satellites subclass with real CLDR behavior. The
bundle stores nothing about CLDR; the backend is everything.

---

## 6. The conformance harness (`testing.dart`)

The machine-readable version of the capability matrix. A satellite
declares its truth as `BackendExpectations` flags;
`fluentBackendConformanceChecks(createBackend, expectations)` returns
named checks that test every flag in BOTH directions:

- flag `true` → a positive structural rendering check (real output
  asserted, digit/marker-shaped so CLDR versions can differ);
- flag `false` (under `recordsUnsupportedOptionErrors`) → a degrade
  check: renders a usable string AND records an error — formatted TWICE
  on ONE bundle, so an error recorded only inside a cached formatter
  builder (silent from the second call) fails the suite.

Layout: `src/testing/expectations.dart` (the flags),
`harness.dart` (`ConformanceHarness` + the assembler), and the check
groups (`checks_core` / `checks_number` / `checks_datetime` /
`checks_degrade`). The harness deliberately does not depend on
`package:test`; satellites wire each returned check into their runner.

A satellite cannot lie: declaring ✓ without the ability fails the
positive check; declaring ✗ but degrading silently fails the degrade
check. The declaration IS the proof.

---

## 7. The satellite template — locked layout

Two satellite species exist. This template is for BACKEND satellites
(`FluentBackend` implementations: fluent_icu, fluent_intl).
INTEGRATION satellites (fluent_flutter — locale lifecycle, loading,
widget access) implement no backend and carry their own shape,
documented in their own `docs/ARCHITECTURE.md`.

Every backend satellite has the IDENTICAL skeleton. Backend-specific
implementation only ever lives INSIDE the fixed slots — never as new
top-level files or folders. A future satellite is stamped from this
template; deviation is drift.

```
fluent_<x>/
  lib/fluent_<x>.dart              barrel: re-exports fluent_bundle + the backend
  lib/src/
    backend.dart                   class <X>Backend extends FluentBackend
    common/                        backend infra shared across concerns
    datetime/datetime_map.dart     create<X>DateTimeFormatter — the folder's entry
    datetime/…                     free: backend-specific datetime helpers
    number/number_map.dart         create<X>NumberFormatter — router + degrades
    number/…                       free: backend-specific number helpers
    plural/plural_map.dart         <x>PluralRules — the folder's entry
    plural/…                       free: helpers
  test/
    _corpus/bundle/*.yaml          vendored fluent-rs resolver fixtures
                                   (byte-identical across satellites; each
                                   PROVENANCE.md pins the same commit)
    _corpus/bundle_corpus_test.dart  runner wired to THIS backend
    conformance_test.dart          REQUIRED: the shared harness with this
                                   backend's declared BackendExpectations
    common/… datetime/… number/… plural/…   mirror lib/src file-for-file
  docs/                            ARCHITECTURE / CAPABILITY_ROADMAP / UPDATING
```

Locked: the folder set, the entry-file names, the corpus + conformance
presence, the barrel shape, the docs triple. Free: everything else
inside the folders (the icu satellite has shaping/styles/field_mapping/
zoned; the intl one has builder/currency_name — guts differ, skeleton
never does).

Cross-satellite duplication is pushed DOWN into this core, never
tolerated sideways. If two satellites re-author the same sentence or
rule, extract it here.

**Add-a-satellite recipe:** the full step list lives in
[`UPDATING.md`](UPDATING.md) §4.

---

## 8. Inline markup (`markup.dart`)

Translators write HTML5-shaped tags inside messages; `parseFluentMarkup`
turns the resolved string into a `List<FluentSpan>` tree callers walk to
build UI. Backed by `package:html` (the Dart team's html5lib port) —
same entity decoding, case folding, and malformed-tag recovery every
browser uses. Bidi isolation marks survive inside text spans but are
stripped from attribute values (URLs and keys are machine-consumed).
The core stays Flutter-free; span → `InlineSpan` mapping lives in the
`fluent_flutter` satellite (`fluentSpansToInline` + `FluentText`).

---

## 9. Hot reload

`addResource(source, allowOverrides: true)` replaces existing messages/
terms in place (conflicts without the flag record `FluentOverrideError`
and keep the existing definition). `bin/watch.dart` is the dev-loop
half: it watches `.ftl` files and emits stable JSON change events on
stdout; the app-side wiring (vm_service, dev endpoint) is deliberately
the consumer's — different IDE setups expose the running app
differently.

---

## 10. Test architecture

The test tree mirrors `lib/src` folder-for-folder. Special categories:

| Where | What |
|---|---|
| `test/_corpus/syntax/` | Vendored fluent-rs parser fixtures (`.ftl` + AST `.json` pairs), run by `syntax_corpus_test.dart`. Provenance: [`../test/_corpus/PROVENANCE.md`](../test/_corpus/PROVENANCE.md). |
| `test/builtins/` | The option parsers: every ECMA value set, cross-constraints, polymorphic useGrouping, merge semantics. |
| `test/values/resolve_digits_test.dart` | The exact-rounding machinery: all nine modes, increments, stripIfInteger, exponent decomposition, PluralRules defaults. |
| `test/bundle/` | Resolver behavior: isolation, cycles, transform, backend seam. |
| `test/barrel/` | Barrel-surface guards. |

The resolver corpus (fluent-rs `bundle/*.yaml`) cannot run here — it
needs a real CLDR backend — so each satellite vendors the same pristine
fixture set and runs it against its own backend. The parser corpus needs
nothing, so it lives here.

---

## 11. Where to look when X happens

| Symptom | First place to look |
|---|---|
| A NUMBER option "does nothing" | Is it validated in `src/builtins/number_builtin.dart` (out-of-set values drop with a recorded error — check the `errors` out-list first)? Then the satellite's `number/number_map.dart` routing. |
| Plural category disagrees with the rendered digits | `resolveDigits` (core) computes the operand; the satellite renders. If a rounding option is involved and the backend degrades it, selection follows the REQUESTED options by design — the degrade error flags the render. |
| A fixture in the satellite corpus fails but core tests pass | The satellite's mapping, not the resolver — resolution is corpus-proven per satellite. |
| Isolation marks appear/disappear unexpectedly | fluent-rs semantics (§3): Message/Term refs and StringLiterals are never isolated. Check `_writePlaceable` before assuming a bug. |

---

## 12. The one-line summary

> **The core owns the Fluent spec AND the ECMA-402 option contract —
> parsing, validation, merge, exact plural-operand math, error shapes,
> and the conformance harness — and renders nothing. Satellites are
> whole-package adapters stamped from one locked template, each
> corpus-proven and harness-proven against its declared capability
> flags. Inert resolution, fluent-rs isolation semantics, degrade loud
> or render right — never silent.**
