import 'package:fluent_bundle/src/backend/format_context.dart';
import 'package:fluent_bundle/src/values/fluent_value.dart';

/// A Fluent built-in or user-supplied callable (e.g. `NUMBER`, `DATETIME`,
/// or a custom `RELATIVE()`).
///
/// Receives the already-resolved [positional] and [named] arguments, plus
/// the [FluentFormatContext] — so a function can read the locale chain and
/// record errors, then return a [FluentValue] to substitute. Functions are
/// synchronous (the Fluent spec has no async functions) and must not throw;
/// the resolver treats a thrown exception as a type error and substitutes a
/// fallback.
typedef FluentFunction =
    FluentValue Function(
      List<FluentValue> positional,
      Map<String, FluentValue> named,
      FluentFormatContext context,
    );
