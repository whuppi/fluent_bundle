# fluent_bundle — Capabilities

What's shipped, what's partial, what's deliberately out of scope. For the architectural map, see [`ARCHITECTURE.md`](ARCHITECTURE.md); for maintenance recipes, [`UPDATING.md`](UPDATING.md). This file holds the FAMILY capability matrices (option × backend); the satellites' roadmaps point here and add only backend-specific tables.

---

## Syntax (parser + AST)

Tracking [Fluent Syntax 1.0](https://github.com/projectfluent/fluent/blob/master/spec/syntax.md). Every fixture in Mozilla's `fluent-rs` corpus passes.

| Feature | Status |
|---|:---:|
| Messages with simple text values | ✓ |
| Messages with attributes | ✓ |
| Terms (private references) | ✓ |
| Comments (line / standalone / resource) | ✓ |
| Junk recovery (parse continues past errors) | ✓ |
| Multi-line patterns with `\n` indent stripping | ✓ |
| String literals with `\uXXXX` / `\UXXXXXX` escapes | ✓ |
| Number literals (positive / negative / decimals) | ✓ |
| Variable references `{ $var }` | ✓ |
| Message references `{ msg }` and `{ msg.attr }` | ✓ |
| Term references `{ -term }` and `{ -term(args) }` | ✓ |
| Function references `{ FN(args) }` with named args | ✓ |
| Select expressions `{ $sel -> [a] x [b] y *[default] z }` | ✓ |
| Identifier keys + number-literal keys in select variants | ✓ |
| Span tracking on every node (offset + length) | ✓ |
| `FluentParseError` E0003–E0029 | ✓ |

---

## Runtime (resolver + bundle)

| Feature | Status |
|---|:---:|
| `FluentBundle.addResource` parses + compiles + indexes | ✓ |
| `formatMessage(id, args:, errors:)` never throws | ✓ |
| `formatPattern(pattern, args:, errors:)` for direct calls | ✓ |
| `hasMessage(id)` lookup | ✓ |
| `getMessage(id)` returns `CompiledMessage` for advanced use | ✓ |
| Variable args coerce: `String` → `FluentString`, `num` → `FluentNumber`, `DateTime` → `FluentDateTime` | ✓ |
| Custom `FluentValue` subclasses pass through unchanged | ✓ |
| Bidi isolation (FSI/PDI wrap on multi-element placeables) | ✓ |
| `useIsolating: false` opt-out for tests | ✓ |
| `transform` hook for locale-aware lowercase / cleanup | ✓ |
| Recursive message + term references with cycle detection | ✓ |
| Inert errors via `errors` out-list — single bad ref doesn't break the string | ✓ |
| `formatMessageAsSpans(id, args:, errors:)` — inline markup as `List<FluentSpan>` | ✓ |
| Hot reload via `addResource(source, allowOverrides: true)` (re-add and swap; the `watch` dev tool feeds it) | ✓ |
| `FluentBundleChain` — bundle-level locale fallback (first member owning the id formats it; read-only view; markup + generated accessors chain for free) | ✓ |
| `negotiateLocaleChain` / `negotiateLocale` — the family's one tag-negotiation ladder | ✓ |

---

## Built-ins

`NUMBER` and `DATETIME` ship in the core; they render through the
bundle's `backend:` (`IcuBackend` from `fluent_icu`, `IntlBackend` from
`fluent_intl`, or the spec-fallback base). Apps can override any builtin
via `bundle.functions`.

| Builtin | Backend support |
|---|---|
| `NUMBER(...)` — the full ECMA-402 option matrix below | `intl` + `icu` per matrix |
| `DATETIME($value, dateStyle:, timeStyle:, hour12:, hourCycle:, calendar:, numberingSystem:, timeZone:, ...)` | `intl` (skeleton composition; gregorian; hourCycle via j/H family — calendar / timeZone / numberingSystem / narrow weekday / offset-generic zone names / h11-h24 degrade with a recorded error, per call) + `icu` (full: calendar / numbering / hour-cycle / IANA timeZone, harness-proven positive) |
| Custom `FluentFunction` registration via `bundle.functions` | ✓ |

### NUMBER — the ECMA-402 option matrix

Every `Intl.NumberFormat` option, per backend. **No blank cells**: ✓ = rendered
(proven by the conformance harness in `lib/testing.dart` — each backend's
`conformance_test.dart` declares these exact flags); ✗ = degrades to the nearest
supported rendering **with a recorded `FluentTypeError`** (also harness-proven,
via `recordsUnsupportedOptionErrors`). The `icu` column holds identically on all
three icu_kit engines (native FFI / WASM / browser-Intl).

| Option | `icu` backend | `intl` backend | Notes |
|---|:---:|:---:|---|
| `style: decimal / percent / currency / unit` | ✓ | ✓ except `unit` ✗ | package:intl has no unit formatter |
| `currency` + `currencyDisplay: symbol / narrowSymbol / code / name` | ✓ | ✓ (narrowSymbol = symbol) | intl name form via `l10n_currencies` |
| `currencySign: accounting` | ✗ | ✗ | ICU4X ships no accounting patterns; intl has no knob |
| `unit` + `unitDisplay` | ✓ | ✗ | |
| `useGrouping` booleans (`"true"` / `"false"`) | ✓ | ✓ | |
| `useGrouping` v3 strategies (`auto` / `always` / `min2`) | ✓ | ✗ (`auto` = intl's native behavior) | icu: `IcuGroupingStrategy` on every style, all three engines; intl patterns carry fixed grouping |
| min/max fraction, integer, significant digits | ✓ | ✓ | |
| `style: currency` without a 3-letter code | ✗ (degrades to decimal) | ✗ (degrades to decimal) | ECMA throws a TypeError; both adapters record + degrade — intl's silent locale-default-currency substitution is guarded out |
| ECMA default digit resolution (no digit options: decimal 3fd / percent 0fd / currency per-currency minor units) | ✓ | ✓ | icu resolves in the adapter — per-currency digits via a baked CLDR-47 fractions table (`currency_digits.dart`: JPY 0, BHD 3, default 2); intl inherits the same digits from its CLDR data. JPY harness-proven on both. |
| `notation: compact` + `compactDisplay` | ✓ (decimal style) | ✓ (decimal + compact-currency) | icu: `IcuCompactFormat` (vendored capi patch); compact on other styles degrades. Both pin the ECMA 1-2 significant-digit compact default (1234567 → "1.2M") |
| `notation: scientific / engineering` | ✗ | ✓ scientific (coarse `#E0`) / ✗ engineering | ICU4X ships no exponent-symbol data (`DecimalSymbols`, verified at source) |
| `signDisplay` (always / never / exceptZero / negative) | ✓ | ✗ | icu: `Decimal.applySignDisplay`, post-rounding per ECMA |
| `roundingMode` (all nine) | ✓ | ✗ | intl rounds half-even internally, no knob |
| `roundingIncrement` (the 15-value set) | ✓ | ✗ | icu: `roundWithModeAndIncrement`; currency default 2/2 resolved in the adapter |
| `trailingZeroDisplay: stripIfInteger` | ✓ | ✗ | icu: `Decimal.trimEndIfInteger` |
| `numberingSystem` | ✓ | ✗ | icu: `-u-nu-` locale fold on every style |

The parser (`NUMBER()` builtin) accepts and validates the WHOLE surface for both
backends — out-of-set values record a `FluentFormatError` and drop; the
`roundingIncrement` cross-constraints (equal fraction bounds, no sig digits) are
enforced core-side where unambiguous and backend-side where style defaults decide.
The `DATETIME()` builtin gets the same treatment: every field option is validated
against its ECMA-402 value set, `fractionalSecondDigits` against 1-3, and
`calendar` / `numberingSystem` against Unicode extension subtag shape.

**Plural selection honors the rounding options.** `FluentNumber.resolveDigits`
computes plural operands with `Intl.PluralRules` semantics — exact digit-string
arithmetic honoring `roundingMode` (all nine), `roundingIncrement`, and
`trailingZeroDisplay`, with the PluralRules digit defaults (min 0, max
`max(min, 3)`). `NUMBER($n, maximumFractionDigits: 0, roundingMode: "floor")`
with `n = 1.9` renders "1" AND selects `one` (harness-proven). `notation` never
affects selection — `Intl.PluralRules` takes rounding options but not notation.

---

## Backends — the `FluentBackend` seam

The core's `FluentBackend` base class IS the Fluent spec fallback; the
satellites subclass it. The three methods:

| Method | Spec fallback (core base) | `IntlBackend` (fluent_intl) | `IcuBackend` (fluent_icu) |
|---|---|---|---|
| `pluralCategory` | `other` always | Cardinals: all CLDR via `Intl.pluralLogic`. Ordinals: the 42 non-trivial CLDR locales, inlined + compliance-tested. | Cardinals + ordinals: every CLDR locale via ICU4X. |
| `formatNumber` | locale-blind but digit-correct (`resolveDigits`) | `package:intl` `NumberFormat` (incl. compact + coarse scientific). Currency name via `l10n_currencies`. | icu_kit facades: decimal / percent / currency / unit / compact. |
| `formatDateTime` | ISO 8601 | `DateFormat` skeleton composition (gregorian only). | icu_kit field-set constructors. Calendar / numbering / hour-cycle via `-u-` folds; IANA `timeZone`. |

| Choice | Use when |
|---|---|
| Core only (no `backend:`) | Spec-fallback behavior. Embedded targets, sandboxed code, minimum deps. |
| `fluent_intl` | Apps already on `package:intl`; smallest footprint, zero setup. Honest API ceiling — see its roadmap. |
| `fluent_icu` | Full ECMA-402 fidelity. 3 engines; web data size reducible via `IcuData` policies — see icu_kit's README and `docs/ARCHITECTURE.md` (sibling repo, `whuppi/icu_kit`). |

---

## Compliance

Mozilla's `fluent-rs` ships the canonical reference test corpus. Every fixture passes our parser + resolver.

| Test type | Source | Coverage |
|---|---|---|
| Parser conformance | `fluent-rs/fluent-syntax/tests/fixtures/parser/*.json` (vendored in `test/_corpus/syntax/`) | ~600 fixtures (errors, escapes, multiline, references, selects) |
| Resolver conformance | `fluent-rs/fluent-bundle/tests/fixtures/*.yaml` (vendored byte-identical in BOTH satellites' `test/_corpus/bundle/`) | 158 asserts per satellite (resolution, bidi, plural selection); upstream skips stay skipped |
| Conformance harness | `lib/testing.dart`, run by each satellite's `conformance_test.dart` | Every `BackendExpectations` flag, both directions (✓ positive, ✗ degrade) |
| Behavioral tests | `test/bundle/*.dart`, `test/syntax/*.dart` | One file per concern |

Provenance: [`test/_corpus/PROVENANCE.md`](../test/_corpus/PROVENANCE.md). Refresh procedure: [`UPDATING.md`](UPDATING.md).

---

## Maintenance

| Task | Cadence |
|---|---|
| Pull latest `fluent-rs` corpus | Once per `fluent-rs` release |
| Refresh inlined ordinal rules (intl backend) | Once per CLDR release; `fluent_intl/tool/regen_cldr_ordinal_fixture.dart` regenerates the compliance fixture (recipe: fluent_intl's UPDATING §3) |
| Refresh `package:intl` + `l10n_currencies` versions | Standard pub upgrade |
| Validate the icu backend against `icu_kit` updates | When `icu_kit` ships a breaking change |

---

## Markup (`package:fluent_bundle/markup.dart`)

Opt-in barrel — `FluentSpan` + `parseFluentMarkup`. The package is pure
Dart end to end; mapping spans to Flutter `InlineSpan`s (or any other
render tree) is app-side code walking the span tree. There is no
Flutter barrel in the core.

---

## Span parser (`formatMessageAsSpans` internals)

Backed by `package:html` (Dart team's HTML5 parser) so translator
intuition matches browser HTML.

| Feature | Status |
|---|:---:|
| HTML5 case-folded tag names (`<Bold>` → `bold`) | ✓ |
| Three quote styles for attributes (`"`, `'`, none) | ✓ |
| Named character entities decoded (`&amp;`, `&copy;`, `&hellip;`, …) | ✓ |
| Self-closing void elements (`<br/>`, `<br>`, `<br></br>`) | ✓ |
| Implicit close on unclosed tags (`<bold>oops`) | ✓ |
| Adoption-agency restructure on mismatched nesting (`<b><i>x</b></i>`) | ✓ |
| Comments dropped (`<!-- secret -->`) | ✓ |
| Bidi-isolation marks stripped from attribute values, kept in text | ✓ |

---

## Dev tools

| Tool | Status |
|---|:---:|
| `dart run fluent_bundle:watch --root <dir>` — JSON-line file-change events | ✓ |
| `dart pub global activate fluent_bundle` puts `watch` on $PATH | ✓ |

---

## Companion packages

Separate packages that compose with `fluent_bundle` for optional capabilities.

| Package | What it adds |
|---|---|
| [`fluent_flutter`](../../fluent_flutter/) (in-workspace sibling; pre-release, `publish_to: none`) | The Flutter integration: FTL asset loading (locales discovered from the AssetManifest), locale lifecycle (`setLocale` / `useDeviceLocale` / persistence seam), `LocalizationsDelegate`s serving bundle-chain fallback (plain + a typed fluent_gen bridge), markup → `InlineSpan` rendering, and FTL hot reload. |
| [`fluent_gen`](../../fluent_gen/) (in-workspace sibling; pre-release, `publish_to: none`) | Compile-time code generator. Reads your base-locale `.ftl` at build time and emits a typed accessor class — typo'd message ids and missing required arguments become compile errors instead of runtime placeholders. Types every `$variable` from how it's used in the FTL source. Ships only as a `dev_dependency`; tree-shakes to nothing for apps that prefer the runtime API. |

---

## Next up

Designed, not yet shipped. Tracked here so the roadmap reflects intent.

(no in-flight items at the moment)

---

## Out of scope

| Feature | Why not |
|---|---|
| ICU MessageFormat compatibility | Fluent is a different (better, more translator-friendly) syntax. Translators write `*[other]` not `{plural, ...}`. |
| Async `FluentFunction` | Fluent functions are sync per spec. If you need async data, fetch it before formatting. |
| Source-map-style trace from rendered string back to source span | The runtime AST drops spans. The syntax AST keeps them — tools that need traces walk the syntax AST instead. |
| Built-in pluggable backends beyond `intl` and `icu` | Other backends are user code. Subclass `FluentBackend` and build your own (stamping recipe: [`UPDATING.md`](UPDATING.md) §4). |
| Backend-side walls (icu's scientific / accounting / flexible dayPeriod, intl's API ceiling) | Backend limitations, not core scope — the matrix cells above mark them ✗; the WHY + retire triggers live in each satellite's own `docs/CAPABILITY_ROADMAP.md`, with the compensation ledger in fluent_icu's `docs/UPDATING.md` §6. |
| fluent.js-style bidi isolation of message/term refs | Deliberate divergence: this resolver matches **fluent-rs** (production Firefox), which skips isolation marks on message refs, term refs, and string literals. The vendored corpus keeps fluent.js's cases as upstream-skipped fixtures. See `resolver.dart` `_writePlaceable`. |

---

## The one-line summary

> **Full Fluent Syntax 1.0 + bidi isolation + inert errors. One backend-free core owning the full ECMA-402 option contract; two satellite packages (`fluent_icu`, `fluent_intl`) subclass `FluentBackend` and declare their honest ceilings — every ✗ degrades loud, harness-proven both directions. Inline markup → `FluentSpan` tree via the opt-in `markup.dart` barrel. Mozilla `fluent-rs` corpus passes 100% through every backend. No async, no MessageFormat — those are different shapes.**
