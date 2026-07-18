// VM lane — every battery, including the VM-only ones (the syntax corpus
// reads its fixtures from disk).
//
// Batteries register their groups when called; the call-site group() wrap
// scopes any battery-level setUpAll to that battery alone.
@TestOn('vm')
library;

import 'package:test/test.dart';

import '../_corpus/syntax_corpus_battery.dart';
import '../barrel/runtime_barrel_battery.dart';
import '../barrel/syntax_barrel_battery.dart';
import '../builtins/datetime_builtin_battery.dart';
import '../builtins/number_builtin_battery.dart';
import '../bundle/backend_battery.dart';
import '../bundle/bidi_isolation_battery.dart';
import '../bundle/bundle_chain_battery.dart';
import '../bundle/bundle_battery.dart';
import '../bundle/term_attribute_selector_cycles_battery.dart';
import '../bundle/transform_battery.dart';
import '../compiled/compiler_battery.dart';
import '../example/example_battery.dart';
import '../locale/negotiation_battery.dart';
import '../markup/fluent_span_equality_battery.dart';
import '../markup/format_message_as_spans_battery.dart';
import '../markup/markup_parser_battery.dart';
import '../syntax/ast/clone_equals_battery.dart';
import '../syntax/parser/expression_battery.dart';
import '../syntax/parser/parser_battery.dart';
import '../syntax/parser/pattern_battery.dart';
import '../syntax/parser/select_battery.dart';
import '../syntax/parser/span_battery.dart';
import '../syntax/parser/stream_battery.dart';
import '../syntax/parser/term_battery.dart';
import '../syntax/unescape_battery.dart';
import '../values/fluent_value_battery.dart';
import '../values/resolve_digits_battery.dart';

void main() {
  group('syntax_corpus', registerSyntaxCorpusTests);
  group('runtime_barrel', registerRuntimeBarrelTests);
  group('syntax_barrel', registerSyntaxBarrelTests);
  group('datetime_builtin', registerDatetimeBuiltinTests);
  group('number_builtin', registerNumberBuiltinTests);
  group('backend', registerBackendTests);
  group('bidi_isolation', registerBidiIsolationTests);
  group('bundle_chain', registerBundleChainTests);
  group('bundle', registerBundleTests);
  group(
    'term_attribute_selector_cycles',
    registerTermAttributeSelectorCyclesTests,
  );
  group('transform', registerTransformTests);
  group('compiler', registerCompilerTests);
  group('example', registerExampleTests);
  group('negotiation', registerNegotiationTests);
  group('fluent_span_equality', registerFluentSpanEqualityTests);
  group('format_message_as_spans', registerFormatMessageAsSpansTests);
  group('markup_parser', registerMarkupParserTests);
  group('clone_equals', registerCloneEqualsTests);
  group('expression', registerExpressionTests);
  group('parser', registerParserTests);
  group('pattern', registerPatternTests);
  group('select', registerSelectTests);
  group('span', registerSpanTests);
  group('stream', registerStreamTests);
  group('term', registerTermTests);
  group('unescape', registerUnescapeTests);
  group('fluent_value', registerFluentValueTests);
  group('resolve_digits', registerResolveDigitsTests);
}
