import 'package:fluent_bundle/src/compiled/compiled_pattern.dart';
import 'package:meta/meta.dart';

/// A compiled message. The [value] is null when the source message had
/// only attributes (e.g. `email = .label = X`), in which case attributes
/// are the only callable surface.
@immutable
final class CompiledMessage {
  /// Bundles one compiled message.
  const CompiledMessage({
    required this.id,
    required this.value,
    required this.attributes,
  });

  /// The message id as written in the FTL.
  final String id;

  /// The compiled value pattern; null for attribute-only messages.
  final CompiledPattern? value;

  /// Compiled attribute patterns by attribute name.
  final Map<String, CompiledPattern> attributes;
}
