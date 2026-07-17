import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_bundle/src/testing/checks_core.dart';
import 'package:fluent_bundle/src/testing/checks_datetime.dart';
import 'package:fluent_bundle/src/testing/checks_degrade.dart';
import 'package:fluent_bundle/src/testing/checks_number.dart';
import 'package:fluent_bundle/src/testing/expectations.dart';

/// One named conformance check: its `run` throws on failure.
typedef ConformanceCheck = ({String name, void Function() run});

/// The shared context every check group formats through: fresh bundles
/// against the backend under test, plus the throw-on-mismatch assert.
/// Deliberately does NOT depend on `package:test`, so the core stays pure.
class ConformanceHarness {
  /// Creates the harness around a backend factory (a FRESH backend
  /// per check keeps caches from hiding per-call bugs).
  ConformanceHarness(this.createBackend);

  /// Constructs the backend under test.
  final FluentBackend Function() createBackend;

  /// A bundle on a fresh backend with [ftl] loaded.
  FluentBundle bundleWith(String locale, String ftl) =>
      FluentBundle(locale, backend: createBackend(), useIsolating: false)
        ..addResource(ftl);

  /// Format the single-message resource `m = <ftl>` in English.
  String fmt(
    String ftl,
    Map<String, Object?> args, [
    List<FluentError>? errors,
  ]) {
    final b = bundleWith('en', 'm = $ftl');
    return b.formatMessage('m', args: args, errors: errors);
  }

  /// Assert [actual] equals [expected], naming [what] on failure.
  void eq(Object? actual, Object? expected, String what) {
    if (actual != expected) {
      throw StateError('$what: expected "$expected", got "$actual"');
    }
  }
}

/// Build the conformance checks for the backend produced by [create],
/// gated by [expectations].
///
/// The headline check is the F8 regression guard: for a locale-aware
/// backend, `NUMBER($n, minimumFractionDigits: 1)` with `n = 1` renders
/// `1.0`, whose visible fraction digit selects `other`, not `one`, in
/// English. A backend that ignores visible fraction digits fails here.
List<ConformanceCheck> fluentBackendConformanceChecks(
  FluentBackend Function() create, {
  BackendExpectations expectations = const BackendExpectations(),
}) {
  final h = ConformanceHarness(create);
  return [
    ...coreChecks(h, expectations),
    ...numberChecks(h, expectations),
    ...datetimeChecks(h, expectations),
    ...degradeChecks(h, expectations),
  ];
}
