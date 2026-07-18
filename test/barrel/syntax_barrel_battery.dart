// Verifies the parse-time barrel `package:fluent_bundle/syntax.dart`
// exposes the AST types tools need to walk a parsed resource.
import 'package:fluent_bundle/syntax.dart';
import 'package:test/test.dart';

void registerSyntaxBarrelTests() {
  group('syntax barrel', () {
    test('parses and walks the AST', () {
      final parser = FluentParser();
      final Resource r = parser.parse(
        '# A greeting\n'
        'hello = Hi, { \$name }!\n'
        '    .label = Greeting\n',
      );

      // Find the message and inspect its parts.
      final m = r.body.firstWhere((e) => e is Message) as Message;
      expect(m.id.name, 'hello');
      expect(m.attributes, hasLength(1));
      expect(m.attributes.first.id.name, 'label');
      expect(m.value, isNotNull);

      // Pattern walk: text + placeable + text.
      final elements = m.value!.elements;
      expect(elements.first, isA<TextElement>());
      expect(elements.any((e) => e is Placeable), isTrue);
    });

    test('exposes parse errors as a typed hierarchy', () {
      // ExpectedTokenError is a FluentParseError subclass — just confirm
      // the type is reachable from this barrel.
      const FluentParseError e = ExpectedTokenError('=', 0);
      expect(e.code, 'E0003');
    });
  });
}
