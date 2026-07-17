import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:test/test.dart';

void main() {
  group('negotiateLocaleChain', () {
    test('exact match leads the chain', () {
      expect(
        negotiateLocaleChain(
          requested: ['de-CH'],
          available: ['de-CH', 'de', 'en'],
          fallback: 'en',
        ),
        ['de-CH', 'de', 'en'],
      );
    });

    test('matching is case-insensitive, output keeps available casing', () {
      expect(
        negotiateLocaleChain(requested: ['EN-us'], available: ['en-US', 'en']),
        ['en-US', 'en'],
      );
    });

    test('progressive truncation walks every subtag step', () {
      expect(
        negotiateLocaleChain(
          requested: ['zh-Hant-TW'],
          available: ['zh-Hant', 'zh', 'en'],
        ),
        ['zh-Hant', 'zh'],
      );
    });

    test('language-prefix best fit picks the shortest available tag', () {
      expect(
        negotiateLocaleChain(
          requested: ['en'],
          available: ['en-GB', 'en-US-posix'],
        ),
        ['en-GB'],
      );
    });

    test('the bridge is skipped when an exact or truncated match exists', () {
      // `de` matched exactly — `de-CH` (more specific than the request)
      // must NOT enter the chain.
      expect(
        negotiateLocaleChain(
          requested: ['de'],
          available: ['de-CH', 'de', 'en'],
          fallback: 'en',
        ),
        ['de', 'en'],
      );
    });

    test('a repeated requested tag never falls into the bridge', () {
      expect(
        negotiateLocaleChain(
          requested: ['de', 'de'],
          available: ['de-CH', 'de'],
        ),
        ['de'],
      );
    });

    test('language-prefix ties break on available order', () {
      expect(
        negotiateLocaleChain(requested: ['pt'], available: ['pt-PT', 'pt-BR']),
        ['pt-PT'],
      );
    });

    test('multiple requested tags keep priority order', () {
      expect(
        negotiateLocaleChain(
          requested: ['es-MX', 'fr-CA'],
          available: ['fr', 'en'],
          fallback: 'en',
        ),
        ['fr', 'en'],
      );
    });

    test('deduplicates across ladder steps and requested tags', () {
      expect(
        negotiateLocaleChain(
          requested: ['de-CH', 'de'],
          available: ['de', 'en'],
          fallback: 'de',
        ),
        ['de'],
      );
    });

    test('fallback is appended verbatim even when not in available', () {
      expect(
        negotiateLocaleChain(
          requested: ['ja'],
          available: ['fr'],
          fallback: 'en',
        ),
        ['en'],
      );
    });

    test('empty when nothing matches and no fallback', () {
      expect(
        negotiateLocaleChain(requested: ['ja'], available: ['fr', 'de']),
        isEmpty,
      );
      expect(negotiateLocaleChain(requested: ['ja'], available: []), isEmpty);
    });

    test('result list is unmodifiable', () {
      final chain = negotiateLocaleChain(requested: ['en'], available: ['en']);
      expect(() => chain.add('x'), throwsUnsupportedError);
    });
  });

  group('negotiateLocale', () {
    test('returns the single best match', () {
      expect(negotiateLocale('fr-CA', available: ['fr', 'en']), 'fr');
    });

    test('returns null when nothing matches', () {
      expect(negotiateLocale('ja', available: ['fr', 'en']), isNull);
    });
  });
}
