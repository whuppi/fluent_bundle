import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:test/test.dart';

const String _fsi = '\u2068';
const String _pdi = '\u2069';

void main() {
  group('Bidi isolation — useIsolating: true (spec default)', () {
    test('placeable values are wrapped in FSI/PDI', () {
      // Default: useIsolating: true.
      final bundle = FluentBundle('en');
      bundle.addResource(
        r'm = Hi, { $name }!'
        '\n',
      );
      expect(
        bundle.formatMessage('m', args: {'name': 'World'}),
        'Hi, ${_fsi}World$_pdi!',
      );
    });

    test('multiple placeables each get their own isolate', () {
      final bundle = FluentBundle('en');
      bundle.addResource(
        r'm = { $first } and { $second }'
        '\n',
      );
      expect(
        bundle.formatMessage('m', args: {'first': 'A', 'second': 'B'}),
        '${_fsi}A$_pdi and ${_fsi}B$_pdi',
      );
    });

    test('a single-element pattern is NOT wrapped (no surrounding text)', () {
      // Per spec: only wrap when the pattern has > 1 element. A single
      // placeable with no other text has nothing to isolate from.
      final bundle = FluentBundle('en');
      bundle.addResource(
        r'm = { $name }'
        '\n',
      );
      expect(bundle.formatMessage('m', args: {'name': 'World'}), 'World');
    });

    test('FluentNone fallback is wrapped like any other placeable value', () {
      // The fallback `{$missing}` is the placeable's rendered string;
      // it is wrapped just like a real value would be.
      final bundle = FluentBundle('en');
      bundle.addResource(
        r'm = Hi, { $missing }!'
        '\n',
      );
      expect(bundle.formatMessage('m'), 'Hi, $_fsi{\$missing}$_pdi!');
    });

    test('numbers passing through the formatter are wrapped', () {
      final bundle = FluentBundle('en');
      bundle.addResource(
        r'count = You have { $n } items'
        '\n',
      );
      expect(
        bundle.formatMessage('count', args: {'n': 5}),
        'You have ${_fsi}5$_pdi items',
      );
    });

    test('placeholder before RTL Arabic text — isolate prevents direction '
        'leak', () {
      // Mixed content: "before { $name } after" where surrounding text
      // would render LTR but $name might be Arabic. The marks ensure
      // each side keeps its own direction.
      final bundle = FluentBundle('ar');
      bundle.addResource(
        r'm = Hello { $name } world'
        '\n',
      );
      final out = bundle.formatMessage('m', args: {'name': 'محمد'});
      // Whatever the surrounding renderer does, the placeable's raw
      // value is preserved between FSI and PDI.
      expect(out, contains('$_fsiمحمد$_pdi'));
    });
  });

  group('Bidi isolation — useIsolating: false (opt-out)', () {
    test('no marks are emitted', () {
      final bundle = FluentBundle('en', useIsolating: false);
      bundle.addResource(
        r'm = Hi, { $name }!'
        '\n',
      );
      expect(bundle.formatMessage('m', args: {'name': 'World'}), 'Hi, World!');
    });
  });
}
