# Contributing

Contributions are welcome.

---

## Setup

```bash
git clone https://github.com/whuppi/fluent_bundle.git
cd fluent_bundle
make hooks               # activates commit-msg + pre-commit (run once)
fvm install              # downloads the SDK version pinned in .fvmrc
fvm dart pub get
fvm dart test            # pure Dart — nothing to compile
```

**Requires:** [FVM](https://fvm.app) (`.fvmrc` pins the exact SDK
version).

**Without FVM:** all Makefile commands accept `DART` and `FLUTTER`
overrides:

```bash
make check DART=dart FLUTTER=flutter
```

---

## Before submitting a PR

```bash
make check
```

Runs `lint-shell` + `analyze` (resolve + format + the shared analyze
core at --fatal-infos) + `analyze-floor` (lowest allowed deps) +
`platforms` (the same pana pub.dev runs) + `test-guards` (two-world
suite rules) + `test` (VM) + `test-web` (the same suites in real
Chrome) + `test-example` (the pinned showcase).
Must pass. Don't suppress with `// ignore:` — fix the underlying
issue.

---

## PR workflow

All PRs target `dev`. That's the only branch contributors touch.

```
your fork / feature branch ──PR──► dev
                                    ↓ CI: make targets via the make-target action
                                    ↓ PR title: Conventional Commits (feat: / fix: / etc.)
                                    ↓ squash-merge when green
                                    ↓ Full test suite via "ready-to-test" label
                                      (suites × OS matrix)
```

CI calls Makefile targets — same commands locally and in CI.

You don't write changelog entries, bump versions, or touch `prod`.
The maintainer handles releases.

---

## Code style

- Match existing code in the repo.
- Errors are inert values — formatting NEVER throws for bad input.
  New failure modes get a typed `FluentError` subclass, recorded into
  the caller's list, with output still returned.
- Every suite runs on the VM AND in Chrome unless it declares
  `@TestOn('vm')` — `make test-guards` enforces this for dart:io /
  dart:ffi importers.
- The core carries no CLDR data or backend-specific behavior — that
  belongs in the satellites. The `FluentBackend` seam is the wall.
- Invisible characters (FSI/PDI, U+202F) appear in source only as
  `\uXXXX` escapes, never raw bytes.

---

## Maintenance recipes

Step-by-step recipes (corpus refresh, spec watchlist, the family
release checklist) live in [`docs/UPDATING.md`](docs/UPDATING.md).

---

## Releases

Handled by the maintainer, via the family release checklist
(the fluent_bundle repo's `docs/UPDATING.md`).
