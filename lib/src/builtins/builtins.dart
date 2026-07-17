import 'package:fluent_bundle/src/builtins/datetime_builtin.dart';
import 'package:fluent_bundle/src/builtins/number_builtin.dart';
import 'package:fluent_bundle/src/bundle/fluent_function.dart';

/// The Fluent spec built-in functions, registered on every bundle before
/// user-supplied functions (which may override them by name).
///
/// The spec defines `NUMBER` and `DATETIME` as always available; a message
/// like `{ NUMBER($x) }` resolves whether or not a locale backend is wired
/// (the base backend renders digit-correct but locale-blind).
Map<String, FluentFunction> coreBuiltins() => const {
  'NUMBER': numberBuiltin,
  'DATETIME': dateTimeBuiltin,
};
