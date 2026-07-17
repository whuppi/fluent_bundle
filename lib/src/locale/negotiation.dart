// Locale negotiation — pure tag algebra, no bundle involved.
//
// One ladder for the whole family: fluent_gen's generated
// `AppLocale.negotiate` and fluent_flutter's delegate both resolve
// through these functions, so the two never drift.

/// The ordered locale fallback chain for [requested] against [available].
///
/// For each requested tag, in priority order, the chain collects:
///
/// 1. the exact match;
/// 2. every match of the tag progressively truncated
///    (`zh-Hant-TW` → `zh-Hant` → `zh`);
/// 3. ONLY when neither of those matched: the most general available
///    tag sharing the requested language (`en` requested → `en-US`
///    available). Shortest wins; ties break on [available] order. A
///    bridge into the language family — never an extra rung, since a
///    chain must get more general as it falls back.
///
/// [fallback] is appended last when given — verbatim, whether or not
/// it appears in [available] (the caller owns the fallback's validity).
///
/// Matching is case-insensitive; results carry [available]'s original
/// casing, deduplicated, order-stable. Empty only when nothing matches
/// and [fallback] is null.
List<String> negotiateLocaleChain({
  required List<String> requested,
  required List<String> available,
  String? fallback,
}) {
  final byLower = <String, String>{
    for (final tag in available) tag.toLowerCase(): tag,
  };
  final chain = <String>[];
  void add(String? tag) {
    if (tag != null && !chain.contains(tag)) chain.add(tag);
  }

  for (final want in requested) {
    var tag = want.toLowerCase();
    var matched = byLower.containsKey(tag);
    add(byLower[tag]);
    while (tag.contains('-')) {
      tag = tag.substring(0, tag.lastIndexOf('-'));
      matched = matched || byLower.containsKey(tag);
      add(byLower[tag]);
    }
    if (matched) continue;
    // Language-prefix best fit — a BRIDGE into the language family for
    // a tag with no exact or truncated match (`en` requested, only
    // `en-US` available): the shortest available tag sharing the
    // language. Never taken when something matched above — a chain
    // must get more GENERAL as it falls back, and this rung is more
    // specific than the request.
    final language = '${want.split('-').first.toLowerCase()}-';
    String? best;
    for (final candidate in available) {
      if (!candidate.toLowerCase().startsWith(language)) continue;
      if (best == null || candidate.length < best.length) best = candidate;
    }
    add(best);
  }
  add(fallback);
  return List.unmodifiable(chain);
}

/// The single best available match for [requested], or null when
/// nothing in [available] matches. The first element of
/// [negotiateLocaleChain] for one requested tag, without a fallback.
String? negotiateLocale(String requested, {required List<String> available}) {
  final chain = negotiateLocaleChain(
    requested: [requested],
    available: available,
  );
  return chain.isEmpty ? null : chain.first;
}
