/// Parse-time AST and parser for Project Fluent.
///
/// Imported by tools that walk or transform the source-level AST:
/// linters, IDE plugins, codegen (`fluent_gen`), formatters,
/// translation-memory exporters.
///
/// Apps that only format messages at runtime should import
/// `package:fluent_bundle/fluent_bundle.dart` instead. The two surfaces are
/// deliberately separate so apps don't ship the full parse-time AST in
/// their release binary.
library;

// Errors that surface during parsing.
export 'src/errors/parse_error.dart';
// AST — the unified library that holds every spec-defined node. The
// library is internally split into `part` files (`base`, `literal`,
// `expression`, `pattern`, `message`, `resource`); from a consumer's
// perspective they're all reached via this single `ast.dart` library.
export 'src/syntax/ast/ast.dart';
// Parser
export 'src/syntax/parser/parser.dart';
// String-literal unescape utility — decodes escape sequences from the
// raw source-preserved [StringLiteral.value] into actual codepoints.
export 'src/syntax/unescape.dart';
