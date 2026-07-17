/// CLDR plural categories. The order is fixed by Unicode; a select
/// expression matches a numeric selector against the identifier key of a
/// variant (`one`, `other`, …) by asking the bundle's `FluentBackend` for
/// the value's category.
enum PluralCategory {
  /// CLDR "zero" (e.g. Arabic 0).
  zero,

  /// CLDR "one" (singular).
  one,

  /// CLDR "two" (dual).
  two,

  /// CLDR "few" (paucal).
  few,

  /// CLDR "many".
  many,

  /// CLDR "other" — the required default; the only category the
  /// spec-fallback backend ever returns.
  other;

  /// Resolve a [PluralCategory] from its CLDR name, or `null` if [name] is
  /// not a recognized category.
  static PluralCategory? fromName(String name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// Which CLDR plural-rule table a selection consults.
///
/// `cardinal` counts things ("1 file", "2 files"); `ordinal` ranks them
/// ("1st", "2nd", "3rd"). A FluentNumber carries this via `NUMBER($n,
/// type: "ordinal")`; the resolver routes it to the backend so
/// `[1]/[2]/[3]/*[other]` ordinal-style variants match correctly.
/// Which CLDR plural rule set drives selection.
enum PluralRuleType {
  /// Quantity rules ("1 item", "2 items").
  cardinal,

  /// Ordering rules ("1st", "2nd").
  ordinal,
}
