# Security Policy

## Reporting a vulnerability

Report privately via [GitHub Security Advisories](https://github.com/whuppi/fluent_bundle/security/advisories/new). Do not open a public issue.

## What's in scope

- **Resolver resource-exhaustion guards failing** — FTL is often translator- or user-supplied. The resolver caps pattern expansion (`FluentResolutionLimitError`) and detects reference cycles (`FluentCyclicReferenceError`); an input that gets past either guard into unbounded work or memory is a security report.

- **The never-throws contract breaking on untrusted input** — malformed FTL becomes `Junk`, bad references become recorded errors. Any input string that makes `addResource` or `formatMessage` throw (rather than record) is a report: apps rely on this to feed untrusted translations safely.

- **Markup attribute smuggling** — `formatMessageAsSpans` parses translator-authored tags. A crafted message that makes attributes or tags appear on spans the source didn't author (confusing a renderer into attaching the wrong handler) got past a parsing control.

## What's NOT in scope

- **What a renderer DOES with spans** — this package returns a data tree; the widget layer (fluent_flutter or your own) decides styling and gesture wiring. Unsafe rendering of a correctly-parsed tree is the renderer's issue.

- **Formatting fidelity** — a wrong plural category or number rendering is a bug, not a vulnerability. Report it as a [regular issue](https://github.com/whuppi/fluent_bundle/issues).

- **Network attacks** — the package makes no network requests and reads no files; sources arrive as strings from the caller.

## Response

Valid reports are fixed and shipped as patch versions.
