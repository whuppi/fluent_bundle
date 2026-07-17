# Vendored compliance corpus - provenance

`syntax/*.ftl` + `*.json` - parser AST round-trip fixtures. Always
runnable; no CLDR backend required, so they live in the core package.

The `bundle/*.yaml` end-to-end fixtures need a real CLDR backend, so they
live with the `fluent_intl` satellite that provides one — see
`fluent_intl/test/_corpus/PROVENANCE.md`.

Fixtures come from Mozilla's Project Fluent reference impl.

## Source

- **Upstream repo:** https://github.com/projectfluent/fluent-rs
- **Source commit:** `b822cfe0ac5f35099ee71d3cf6f43b7c01d5fc6d`
- **Source date:** 2026-03-27
- **Vendored on:** 2026-04-27
- **License:** Apache-2.0 (compatible with this package's Apache-2.0)

## Source paths

| Local path | Upstream path |
|---|---|
| `syntax/*.ftl` | `fluent-syntax/tests/fixtures/*.ftl` |
| `syntax/*.json` | `fluent-syntax/tests/fixtures/*.json` |

## Updating the corpus

See [`../../docs/UPDATING.md`](../../docs/UPDATING.md) for the full
procedure.

The short version:

```sh
# Pull the latest fluent-rs into a scratch checkout
git clone --depth 1 https://github.com/projectfluent/fluent-rs.git /tmp/fluent-rs

# Diff our copy against upstream
diff -r /tmp/fluent-rs/fluent-syntax/tests/fixtures \
        test/_corpus/syntax

# If diffs look intentional (upstream added/changed fixtures), copy
# the new files in, run the corpus suite, fix any newly-failing
# fixtures, then update this file's commit + date.
```

## Why we vendor as plain copies (not a git submodule)

A git submodule is the right call when vendored upstream source is
**compiled into the shipped binary** at build time. Our corpus is
**read-only test data** that's never compiled or shipped to consumers.
A submodule would add a clone step that doesn't pay for itself, and the
indirection hurts discoverability. This file is the manual ledger. Bump
it on every refresh.

## What's NOT vendored

We do NOT vendor:

- `fluent-rs`'s Rust source - we're a clean-room Dart implementation,
  not a wrapper. Spec adherence is verified through the corpus, not
  through line-by-line parity with another impl.
- `fluent.js`'s TypeScript source - same reason.
- The Project Fluent EBNF grammar - the spec is read from
  https://projectfluent.org/fluent/guide/ and from the Mozilla syntax
  RFC. Changes to the spec would show up as new fixtures upstream
  first; the corpus is our truth.
