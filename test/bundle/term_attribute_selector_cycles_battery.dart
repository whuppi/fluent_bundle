// First-party proof for behaviors the vendored fluent-rs corpus marks
// `skip: true` (upstream's own harness skips them — see
// fluent_intl/test/_corpus/PROVENANCE.md). The fixtures here replicate
// `patterns.yaml`'s "Cyclic reference in a selector" cases: a cycle
// reached THROUGH a term attribute used as a select-expression selector
// must render the default variant and record a cyclic-reference error,
// never hang or throw.

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:test/test.dart';

void registerTermAttributeSelectorCyclesTests() {
  group('cyclic references through term-attribute selectors', () {
    test('cycle in a selector renders the default variant + Cyclic error', () {
      final bundle = FluentBundle('en-US', useIsolating: false)..addResource('''
-foo =
    { -bar.attr ->
       *[a] Foo
    }
-bar = Bar
    .attr = { -foo }
foo = { -foo }
''');
      final errors = <FluentError>[];
      final out = bundle.formatMessage('foo', errors: errors);
      expect(out, 'Foo');
      expect(errors.any((e) => e is FluentCyclicReferenceError), isTrue);
    });

    test('self-cycle via a term attribute selector renders the default '
        'variant + Cyclic error', () {
      final bundle = FluentBundle('en-US', useIsolating: false)..addResource('''
-foo =
    { -bar.attr ->
       *[a] Foo
    }
    .attr = a
-bar = Bar
    .attr = { -foo }
foo = { -foo }
''');
      final errors = <FluentError>[];
      final out = bundle.formatMessage('foo', errors: errors);
      expect(out, 'Foo');
      expect(errors.any((e) => e is FluentCyclicReferenceError), isTrue);
    });
  });
}
