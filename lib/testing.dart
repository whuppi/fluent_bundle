/// A conformance suite for `FluentBackend` implementations.
///
/// A backend author (or a satellite package) runs `fluentBackendConformanceChecks`
/// against a real bundle and wires each returned check into their test
/// runner — this library deliberately does NOT depend on `package:test`,
/// so the core stays pure:
///
/// ```dart
/// import 'package:fluent_bundle/testing.dart';
/// import 'package:fluent_intl/fluent_intl.dart';
/// import 'package:test/test.dart';
///
/// void main() {
///   for (final c in fluentBackendConformanceChecks(IntlBackend.new)) {
///     test(c.name, c.run);
///   }
/// }
/// ```
///
/// The pieces live under `src/testing/`: `BackendExpectations` declares a
/// backend's capability set; the check groups (`checks_core`,
/// `checks_number`, `checks_datetime`, `checks_degrade`) test every flag
/// in both directions — positive render when `true`, degrade+error when
/// `false`.
library;

export 'src/testing/expectations.dart' show BackendExpectations;
export 'src/testing/harness.dart'
    show ConformanceCheck, fluentBackendConformanceChecks;
