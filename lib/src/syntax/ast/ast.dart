/// The Fluent Syntax 1.0 AST as one Dart library.
///
/// All AST nodes live in this library so that sealed-class boundaries
/// remain coherent. In particular, `Placeable` is both a
/// [PatternElement] and an [InlineExpression] — that's only legal when
/// every concrete node and every sealed parent share a library.
library;

import 'package:meta/meta.dart';

part 'base.dart';
part 'literal.dart';
part 'expression.dart';
part 'pattern.dart';
part 'message.dart';
part 'resource.dart';
