import 'package:fluent_bundle/src/backend/backend.dart';
import 'package:fluent_bundle/src/errors/fluent_error.dart';

/// The per-format-call context handed to a [FluentBackend], to
/// `FluentValue.format`, and to user-supplied functions.
///
/// It carries the bundle's locale chain (most specific first), the error
/// sink for the resolve call, and the active backend — everything a
/// locale-aware operation needs, without any of the resolver's internal
/// traversal state.
final class FluentFormatContext {
  /// Creates a context for one resolve call.
  const FluentFormatContext({
    required this.locales,
    required this.errors,
    required this.backend,
  });

  /// Locale fallback chain in priority order, most specific first. Never
  /// empty in practice; [locale] guards the empty case.
  final List<String> locales;

  /// The resolve call's error sink. A backend or function that degrades
  /// (unsupported option, missing data) records a [FluentError] here rather
  /// than throwing.
  final List<FluentError> errors;

  /// The backend that formats numbers and dates and classifies plurals.
  final FluentBackend backend;

  /// The primary locale — `locales.first`, or `'en'` if the chain is empty.
  String get locale => locales.isEmpty ? 'en' : locales.first;
}
