.PHONY: check hooks lint-shell analyze analyze-floor platforms test-guards format test test-web test-example \
        clean

# ═══════════════════════════════════════════════════════════════════
# SDK resolution
#
# Uses fvm by default. Contributors without fvm can override:
# make check DART=dart
# fluent_bundle is pure Dart — no Flutter dependency anywhere in the
# gate; the chrome lane needs only Chrome.
# ═══════════════════════════════════════════════════════════════════

DART    ?= fvm dart
# analyze_core.sh requires FLUTTER even in pure-Dart packages (it
# analyzes a Flutter example when one exists; ours are bare files).
FLUTTER ?= fvm flutter
TEST_RESULTS_DIR ?= test-results
TIMEOUT := $(if $(CI),--timeout=30x,)
VERBOSE := $(if $(CI),--verbose,)

# ═══════════════════════════════════════════════════════════════════
# § 1 — Gate
# ═══════════════════════════════════════════════════════════════════
#
# make check    Full local gate before handing work over.

check: lint-shell analyze analyze-floor platforms test-guards test test-web test-example

# make hooks    Activate the repo's git hooks (commit-msg, pre-commit).
#               Run once after cloning — they stay dormant otherwise.
#               Idempotent. The hooks live at the repo root
#               (.githooks/), stamped from the shared whuppi set.
hooks:
	@git config core.hooksPath .githooks
	@echo "✓ git hooks active (core.hooksPath → .githooks)"

# make lint-shell  Shell portability gate: shellcheck + a bash-version scan
#                  over the repo's shell scripts. Shared gate
#                  tool/lint_shell.sh (canonical in whuppi/ci, stamped).
lint-shell:
	@bash tool/lint_shell.sh


# make platforms  Gate pub.dev platform support: pana (the exact analyzer
#                 pub.dev runs, pinned via tool/versions.env) must still
#                 report all 6 platforms, else a regression like an
#                 unconditional dart:io import in the wrong layer silently
#                 drops a platform. Shared gate tool/platforms_gate.sh
#                 (canonical in whuppi/ci, stamped into tool/).
platforms:
	@DART="$(DART)" EXPECTED_PLATFORMS="android ios linux macos windows web" bash tool/platforms_gate.sh

# ═══════════════════════════════════════════════════════════════════
# § 2 — Analyze
# ═══════════════════════════════════════════════════════════════════
#
# make analyze  Resolve, format, analyze at --fatal-infos. Resolve runs
#               FIRST because `dart format` reads the resolved language
#               version — an unresolved tree formats differently.
#               Locally format fixes in place; under CI a diff fails.

analyze:
	@echo "=== Dart: pub get ==="
	@$(DART) pub get
	@echo "=== Dart: format ==="
	@if [ -n "$$CI" ]; then \
	  $(DART) format --set-exit-if-changed lib bin test tool example; \
	else \
	  $(DART) format lib bin test tool example; \
	fi
	@echo "=== Dart: analyze (shared core) ==="
	@DART="$(DART)" FLUTTER="$(FLUTTER)" ANALYZE_DIRS="lib bin test tool example" EXAMPLE_DIR="" bash tool/analyze_core.sh

# make analyze-floor  Resolve to the OLDEST in-range dependencies and
#                     analyze the shipped code (lib bin). The wide lower
#                     bounds are only honest if the code analyzes against
#                     them, not just the newest a fresh resolve picks.
#                     Tests are excluded on purpose — a consumer sees
#                     lib, never your tests. Snapshots and restores the
#                     lock so a local run leaves the tree clean.
analyze-floor:
	@$(DART) pub get >/dev/null
	@cp pubspec.lock pubspec.lock.floorbak; \
	$(DART) pub downgrade >/dev/null && $(DART) analyze --fatal-infos lib bin; rc=$$?; \
	mv pubspec.lock.floorbak pubspec.lock; \
	$(DART) pub get >/dev/null 2>&1 || true; \
	exit $$rc

# make format   Format in place (analyze also formats; this is the
#               standalone entry).
format:
	@$(DART) format lib bin test tool example

# make test-guards  Mechanical suite rules. Every suite here runs on BOTH
#                   the VM and Chrome (`make test-web`), so a VM-only import
#                   in a two-world suite breaks the browser world silently
#                   at load time. dart:io / dart:ffi are allowed only in
#                   files that declare @TestOn('vm').
test-guards:
	@bad=""; \
	for f in $$(grep -rlE "import 'dart:(io|ffi)'" test/ --include="*.dart"); do \
	  grep -q "@TestOn('vm')" "$$f" || bad="$$bad$$f\n"; \
	done; \
	if [ -n "$$bad" ]; then \
	  echo "VM-only import in a two-world suite (add @TestOn('vm')):"; \
	  printf "$$bad"; exit 1; fi
	@echo "✓ test guards clean"

# ═══════════════════════════════════════════════════════════════════
# § 3 — Test
# ═══════════════════════════════════════════════════════════════════
#
# make test     The full VM suite.

test:
	@echo "=== VM suite ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	@$(DART) test $(TIMEOUT) --file-reporter json:$(TEST_RESULTS_DIR)/vm.json

# make test-web  The same suites in real Chrome (dart test -p chrome).
test-web:
	@echo "=== Chrome suite (dart test -p chrome) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	@$(DART) test -p chrome $(TIMEOUT) --file-reporter json:$(TEST_RESULTS_DIR)/web.json

# make test-example  The pub.dev showcase (example/main.dart) run with
#                    its output pinned — every Example-tab claim proven.
test-example:
	@echo "=== Example showcase (pinned output) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	@$(DART) test $(TIMEOUT) test/example --file-reporter json:$(TEST_RESULTS_DIR)/example.json

# ═══════════════════════════════════════════════════════════════════
# § 4 — Clean
# ═══════════════════════════════════════════════════════════════════

clean:
	@rm -rf .dart_tool $(TEST_RESULTS_DIR)
	@echo "✓ clean"
