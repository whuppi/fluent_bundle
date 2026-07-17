# Updating fluent_bundle

Maintenance recipes for the core. For architecture context see
[`ARCHITECTURE.md`](ARCHITECTURE.md); for capability status see
[`CAPABILITY_ROADMAP.md`](CAPABILITY_ROADMAP.md). Each satellite has its
own `docs/UPDATING.md` for backend-side maintenance.

fluent_bundle is a clean-room implementation — it wraps neither
fluent-rs nor fluent.js. Upstream is tracked two ways:

| Source | Why |
|---|---|
| Mozilla's fluent-rs fixture corpus | Compliance — parser fixtures here, resolver fixtures in each satellite |
| Project Fluent spec (Syntax 1.0) | Source of truth for parser semantics |

---

## When to update

| Trigger | Recipe |
|---|---|
| New fluent-rs release / new fixtures | §1 — Refresh the corpus (core + BOTH satellites together) |
| A new ECMA-402 option (or option value) should be supported | §2 — Add an option end to end |
| New Fluent Syntax spec revision | §3 — Track the spec |
| A new backend satellite is wanted | §4 — Stamp a satellite |
| `package:html` breaking change | §5 — Standard pub upgrade |
| Cutting a release | §6 — Release (pre-release today) |

---

## §1 — Refresh the fluent-rs corpus

The corpus is split by what it needs:

- **Parser fixtures** (`test/_corpus/syntax/`, here) — no backend needed.
- **Resolver fixtures** (`test/_corpus/bundle/`, vendored byte-identical
  in BOTH `fluent_icu` and `fluent_intl`) — need a real CLDR backend.

All three copies pin the same upstream commit and MUST refresh in the
same session — the PROVENANCE files cross-reference each other.

```sh
# 1. Scratch checkout
git clone --depth 1 https://github.com/projectfluent/fluent-rs.git /tmp/fluent-rs

# 2. Diff each copy against upstream
diff -r /tmp/fluent-rs/fluent-syntax/tests/fixtures  test/_corpus/syntax
diff -r /tmp/fluent-rs/fluent-bundle/tests/fixtures  ../fluent_icu/test/_corpus/bundle
diff -r /tmp/fluent-rs/fluent-bundle/tests/fixtures  ../fluent_intl/test/_corpus/bundle

# 3. Copy intentional changes in (fixtures stay byte-pristine — never
#    hand-edit vendored YAML/JSON), run each package's corpus suite,
#    bump every PROVENANCE.md (commit + dates).
```

A newly-failing fixture is either a new spec feature to implement or a
regression to bisect. The upstream-skip list (`skip: true` in fixtures,
plus the stream-specific skips documented in each runner) is upstream's
own — never add a local skip to make the suite pass.

---

## §2 — Add an ECMA-402 option end to end

The recurring maintenance recipe. One option touches four layers, in
this order:

| Step | Where | What |
|---|---|---|
| 1 | `lib/src/values/fluent_number.dart` (or `fluent_datetime.dart`) | Add the nullable field; wire ctor + `isEmpty` + `merge`. EVERY field joins all three. |
| 2 | `lib/src/builtins/` | Parse the FTL named arg; validate against the ECMA value set (`strOf`) or shape rule; record `FluentFormatError` + drop on bad values. Test in `test/builtins/`. |
| 3 | If the option affects plural operands | Extend `resolveDigits` (PluralRules accepts rounding options, never notation). Test in `test/values/resolve_digits_test.dart`. |
| 4 | Each satellite | Wire rendering OR a per-call degrade (`FluentTypeError.unsupportedOption`). **Every construction-affecting option joins every formatter cache key** — a field left out is a cache-collision bug. |
| 5 | `lib/src/testing/` | Add a `BackendExpectations` flag + a positive check in the matching `checks_*` group + a degrade row in `checks_degrade.dart`. Satellites declare their truth in their `conformance_test.dart`. |
| 6 | Docs | A row in [`CAPABILITY_ROADMAP.md`](CAPABILITY_ROADMAP.md)'s NUMBER matrix (no blank cells: ✓ or ✗-with-degrade per backend). |

Then the full sweep: `fvm dart analyze . && fvm dart test` in all three
packages.

---

## §3 — Track Fluent Syntax spec revisions

Target: **Fluent Syntax 1.0**. Revisions are rare. When one lands:
read the changelog at
`https://github.com/projectfluent/fluent/blob/master/spec/`, update
`lib/src/syntax/parser/`, pick up upstream's new fixtures via §1.

---

## §4 — Stamp a new satellite

The locked template lives in [`ARCHITECTURE.md`](ARCHITECTURE.md) §7.

1. Copy the skeleton (`backend.dart` + `common/ datetime/ number/
   plural/` with `*_map.dart` entries; mirrored test tree; `docs/`).
2. The barrel re-exports `fluent_bundle.dart` + the backend class.
3. Implement the three `*_map.dart` entries against the new rendering
   library. Route every unsupported option through
   `FluentTypeError.unsupportedOption` per call — never inside a cached
   builder. Use `isValidCurrencyCode` for the currency guard.
4. Declare honest `BackendExpectations` in `test/conformance_test.dart`
   (`recordsUnsupportedOptionErrors: true` once the degrades are wired).
5. Vendor the resolver corpus (same commit as the siblings; PROVENANCE
   cross-references + sync-together rule).
6. `fvm dart analyze . && fvm dart test` green; add the backend column
   to the CAPABILITY_ROADMAP matrix; write the satellite's three docs.

---

## §5 — Refresh `package:html` (markup parser backing)

```sh
fvm dart pub upgrade html
fvm dart test test/markup/
```

Its API is stable; if a major bump changes `parseFragment`, update
`lib/src/markup/markup_parser.dart` and re-run the markup tests.

---

## §6 — Release

The family packages are pre-release (`publish_to: none`, path deps).
Until DC calls the release there is no per-change changelog; git
history records the work. The release pass, when called, covers per
package:

1. Path deps → hosted deps (`fluent_bundle` version pinned by the
   satellites; `icu_kit` already hosted); drop `publish_to: none`.
   Then activate the platforms gates fully: every satellite's
   `platforms` target is blocked-loud pre-release (each package is
   its own repo; pana snapshots the git repo and can never resolve a
   sibling-repo path dep) — replace the blocked targets with real
   `platforms_gate.sh` runs and flip them into each `check`
   (fluent_intl / fluent_icu / fluent_flutter expect all 6 platforms;
   fluent_gen expects native-only, no web — it is a dart:io
   build_runner tool). fluent_bundle's gate is live already.
2. pubspec description (60–180 chars) + `topics`.
3. CHANGELOG two-lane (core vs satellites move independently after
   1.0; before it, one synchronized version line).
4. Verify the three canonical docs + README against the shipped
   surface (the sprint-end doc check, run once more at release).
5. README family conventions hold (they apply to any future satellite
   too): every package carries the compass blockquote up top naming
   the two front doors (Flutter apps → fluent_flutter, pure Dart →
   fluent_bundle; backends/gen are add-ons, never landing points);
   the full family table lives ONLY in the core's README (satellites
   link, never restate); banner images go on the two front doors
   only — add-ons use the plain centered `<h1>` title. The core keeps
   the which-backend table; fluent_flutter keeps the hot-reload
   recipe. Front-door banner assets
   (`assets/banner_{dark,light}-web-min.webp`) must exist before
   publish — the README blocks reference them.
6. `example/` runs against the hosted deps.
7. `dart pub publish --dry-run` + pana on every package; fix every
   point it flags before the real publish.

---

## Running chrome tests

The suite is pure Dart, so the chrome lane needs only Chrome:

```sh
make test-web        # = dart test -p chrome
```

The icu-backed chrome coverage lives in fluent_icu (its `make test-web`
installs icu_kit's web engine via `dart run icu_kit:setup web`).

---

## Reading the failure modes

| Failure | First check |
|---|---|
| Corpus fixture fails after a refresh | New spec feature vs regression — diff the fixture's expectation against actual, bisect. Never local-skip. |
| A satellite's conformance run fails after a core change | The harness grew a check (flag default `true`): either the satellite wires the capability or declares `false` + degrade. That's the harness working. |
| `dart analyze` finds undefined symbols after `pub upgrade` | The dep broke API — read its CHANGELOG, update the wiring. |
| Chrome run fails fetching `index.mjs` | Web assets not materialized — see above. |

---

## CI staleness check (future)

Not yet implemented: a job that watches fluent-rs tags and opens a
draft PR when the corpus is behind. Manual quarterly refreshes are
acceptable at current cadence.
