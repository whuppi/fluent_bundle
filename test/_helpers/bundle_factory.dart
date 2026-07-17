/// Test bundle factory with bidi-isolation OFF by default so unit tests
/// can assert plain output without isolation marks (FSI / PDI,
/// U+2068 / U+2069) cluttering the expected strings.
///
/// Behavioral tests that verify bidi marks live in
/// `test/bundle/bidi_isolation_test.dart` and construct their own
/// bundles with `useIsolating: true`.
library;

import 'package:fluent_bundle/fluent_bundle.dart';

/// Build a [FluentBundle] for unit tests.
///
/// Defaults differ from production: `useIsolating: false` so resolved
/// strings are easier to assert against. The backend defaults to the
/// spec-fallback [FluentBackend]; pass `IntlBackend()` when a test needs
/// real CLDR plurals or locale-aware formatting.
FluentBundle testBundle(
  String locale, {
  Map<String, FluentFunction>? functions,
  FluentBackend backend = const FluentBackend(),
  bool useIsolating = false,
}) {
  return FluentBundle(
    locale,
    functions: functions,
    backend: backend,
    useIsolating: useIsolating,
  );
}
