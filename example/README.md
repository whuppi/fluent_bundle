# fluent_bundle example

A console tour exercising every core capability — the syntax barrel
(parse, spans, junk recovery, unescape), the bundle (arguments,
attributes, terms, selectors), the NUMBER / DATETIME builtins, bidi
isolation, the pseudo-localization transform, custom functions, inert
errors, hot reload, locale fallback chains, and the markup span tree.
Everything renders through the spec-fallback `FluentBackend`, so the
tour runs anywhere `dart` runs — no CLDR data, no native build, no
setup.

## Run

```bash
# from the package root
fvm dart run example/main.dart
```

## Tests

```bash
# from the package root
make test-example

# or directly
fvm dart test test/example
```

The test runs this exact showcase and pins every output line, so every
claim in the tour is proven on every run — including the invisible
ones (the FSI/PDI bidi-isolation marks are asserted as `\u2068` /
`\u2069` escapes). The suite is two-world: it also runs in real
Chrome as part of `make test-web`.

## What's inside

Ten sections, one per capability area:

| Section | Surface | What it covers |
|---|---|---|
| **Parse** | `package:fluent_bundle/syntax.dart` | `FluentParser` → spanned AST, attached comments, junk recovery for bad syntax, `unescapeFluentString` |
| **Bundle** | `FluentBundle` | `hasMessage` / `getMessage`, argument substitution, attribute access, terms |
| **Selectors** | select expressions | Exact-number keys (always match), string keys, `*[other]` defaults — and why `[one]` is the backend's job |
| **Builtins** | `NUMBER` / `DATETIME` | Digit options honored locale-blind (`minimumFractionDigits`, significant digits), ISO-8601 dates |
| **Bidi + transform** | `useIsolating`, `transform` | FSI/PDI wrapping of substituted values; pseudo-localization of author text only |
| **Custom functions** | `FluentFunction` | A user-supplied `STRLEN()` callable from FTL |
| **Errors** | `FluentError` out-lists | Missing variable, missing message, reference cycle, parse junk — output always comes back, errors land in the caller's list |
| **Hot reload** | `addResource(allowOverrides:)` | Duplicates rejected by default; overrides replace in place |
| **Locale chain** | `FluentBundle.locales` | The priority-ordered fallback chain the app negotiated |
| **Markup** | `package:fluent_bundle/markup.dart` | `formatMessageAsSpans` → walkable `FluentSpan` tree, tag attributes, the standalone `parseFluentMarkup` |

## One file on purpose

The whole tour lives in `main.dart` because pub.dev renders that file
as the package's Example tab — splitting it would hide everything else
from that page.

## Backend-blind on purpose

The core never renders CLDR. Plurals classify as `other`, numbers are
digit-correct but locale-blind, dates are ISO-8601 — that IS the
Fluent spec fallback. Swap in `IcuBackend` (fluent_icu) or
`IntlBackend` (fluent_intl) and every message in this tour renders
locale-aware without changing a line of FTL.
