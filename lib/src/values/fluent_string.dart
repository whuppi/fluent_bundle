part of 'fluent_value.dart';

/// A locale-independent string. Used for string literals (`"hello"`) and
/// for any host-language `String` argument the bundle receives.
@immutable
class FluentString extends FluentValue {
  /// Wraps [value].
  const FluentString(this.value);

  /// The string content.
  final String value;

  @override
  String get rawString => value;

  @override
  String toString() => 'FluentString("$value")';
}
