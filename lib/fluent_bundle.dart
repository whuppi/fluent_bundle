/// Runtime API for Project Fluent.
///
/// Most apps need only this barrel: construct a `FluentBundle`, call
/// `FluentBundle.addResource` with the FTL source, then resolve messages
/// via `FluentBundle.formatMessage` or `FluentBundle.formatPattern`.
///
/// `NUMBER` and `DATETIME` are always available. A bare `FluentBundle('en')`
/// uses the spec-fallback `FluentBackend` — digit-correct but locale-blind,
/// plurals always `other`. For CLDR-aware output pass a `backend:`:
///
///   * `IntlBackend` from `package:fluent_intl` — `package:intl`; the
///     lighter setup, real cardinal plurals for every locale.
///   * `IcuBackend` from `package:fluent_icu` — ICU4X; full ECMA-402,
///     all-locale ordinals, calendars, numbering systems, units.
///
/// Write your own by extending `FluentBackend` and overriding any subset
/// of its methods; the base is always the spec fallback.
///
/// Tools that walk the parse-time AST import
/// `package:fluent_bundle/syntax.dart`. Inline `<bold>` / `<a>` markup
/// rendered to a span tree lives in `package:fluent_bundle/markup.dart`.
library;

// Backend — how numbers, dates, and plurals are handled.
export 'src/backend/backend.dart';
export 'src/backend/format_context.dart';
export 'src/backend/plural_category.dart';
// Bundle + the callable-function type.
export 'src/bundle/bundle_chain.dart';
export 'src/bundle/fluent_bundle.dart';
export 'src/bundle/fluent_function.dart';
// Compiled handles — the opaque types FluentBundle.getMessage returns and
// formatPattern accepts. The runtime expression AST beneath them is
// deliberately internal.
export 'src/compiled/compiled_message.dart' show CompiledMessage;
export 'src/compiled/compiled_pattern.dart' show CompiledPattern;
// Errors.
export 'src/errors/fluent_error.dart';
export 'src/errors/parse_error.dart';
// Locale negotiation — pure tag algebra shared by fluent_gen's emitted
// enum and fluent_flutter's delegate.
export 'src/locale/negotiation.dart';
// Value types.
export 'src/values/fluent_value.dart';
