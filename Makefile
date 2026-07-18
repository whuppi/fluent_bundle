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

# make test-guards  Mechanical suite rules for the battery/runner layout.
#                   Test logic lives in *_battery.dart files (register
#                   functions); test/runners/ holds the only *_test.dart
#                   entry points — one per world (VM, Chrome). Guards:
#                   dart:io / dart:ffi only in batteries marked
#                   'vm-only: <reason>'; no test entry outside runners;
#                   every battery imported by the vm runner, and by the
#                   web runner unless vm-only.
test-guards:
	@bad=""; \
	for f in $$(grep -rlE "import 'dart:(io|ffi)'" test/ --include="*.dart" | grep -v "test/runners/"); do \
	  grep -qi "vm-only:" "$$f" || bad="$$bad$$f\n"; \
	done; \
	if [ -n "$$bad" ]; then \
	  echo "dart:io/ffi in a battery without a 'vm-only: <reason>' marker:"; \
	  printf "$$bad"; exit 1; fi
	@bad=$$(find test -name "*_test.dart" ! -path "test/runners/*"); \
	if [ -n "$$bad" ]; then \
	  echo "Test entry outside test/runners/ — suites are batteries, runners"; \
	  echo "are the only *_test.dart entry points:"; \
	  echo "$$bad"; exit 1; fi
	@bad=""; \
	for f in $$(find test -name "*_battery.dart"); do \
	  rel=$${f#test/}; \
	  grep -q "$$rel" test/runners/vm_runner_test.dart || bad="$$bad$$f (missing from vm runner)\n"; \
	  if grep -qi "vm-only:" "$$f"; then \
	    grep -q "$$rel" test/runners/web_runner_test.dart && bad="$$bad$$f (vm-only battery in web runner)\n"; \
	  else \
	    grep -q "$$rel" test/runners/web_runner_test.dart || bad="$$bad$$f (missing from web runner)\n"; \
	  fi; \
	done; \
	if [ -n "$$bad" ]; then \
	  echo "battery/runner completeness violation:"; \
	  printf "$$bad"; exit 1; fi
	@echo "✓ test guards clean"

# ═══════════════════════════════════════════════════════════════════
# § 3 — Test
# ═══════════════════════════════════════════════════════════════════
#
# make test     The full VM suite.

test:
	@echo "=== VM lane (batteries via test/runners/vm_runner_test.dart) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	@$(DART) test $(TIMEOUT) test/runners/vm_runner_test.dart --file-reporter json:$(TEST_RESULTS_DIR)/vm.json

# make test-web  The same suites in real Chrome (dart test -p chrome).
test-web:
	@echo "=== Chrome lane (batteries via test/runners/web_runner_test.dart) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	@$(DART) test -p chrome $(TIMEOUT) test/runners/web_runner_test.dart --file-reporter json:$(TEST_RESULTS_DIR)/web.json

# make test-example  The pub.dev showcase (example/main.dart) run with
#                    its output pinned — every Example-tab claim proven.
test-example:
	@echo "=== Example showcase (pinned output) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	@$(DART) test $(TIMEOUT) test/runners/example_runner_test.dart --file-reporter json:$(TEST_RESULTS_DIR)/example.json

# ═══════════════════════════════════════════════════════════════════
# § 4 — Clean
# ═══════════════════════════════════════════════════════════════════

clean:
	@rm -rf .dart_tool $(TEST_RESULTS_DIR)
	@echo "✓ clean"
