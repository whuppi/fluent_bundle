import 'package:fluent_bundle/src/compiled/compiled_pattern.dart';
import 'package:meta/meta.dart';

/// A compiled term. Terms always have a value (the parser rejects
/// value-less terms as Junk).
///
/// Terms are not callable from the bundle's public API — they are only
/// reachable through `{ -name }` references inside other patterns.
@immutable
final class CompiledTerm {
  /// Bundles one compiled term.
  const CompiledTerm({
    required this.id,
    required this.value,
    required this.attributes,
  });

  /// The term id without the leading `-`.
  final String id;

  /// The compiled value pattern (terms always have one).
  final CompiledPattern value;

  /// Compiled attribute patterns by attribute name.
  final Map<String, CompiledPattern> attributes;
}
