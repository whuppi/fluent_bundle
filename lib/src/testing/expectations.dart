/// What a particular backend is expected to support. The spec-fallback
/// `FluentBackend` sets everything false; CLDR backends declare exactly
/// what they render. Every flag here has a matching conformance check —
/// a backend's declaration IS tested, in both directions: a `true` flag
/// runs the positive rendering check, and (under
/// [recordsUnsupportedOptionErrors]) a `false` flag runs the degrade
/// check (still renders, records an error, never throws).
class BackendExpectations {
  /// Declares one backend's honest capability set; every flag
  /// defaults to the capable side so a new check is opt-out.
  const BackendExpectations({
    this.localeAwarePlurals = true,
    this.operandAwarePlurals = true,
    this.signDisplay = true,
    this.roundingMode = true,
    this.roundingIncrement = true,
    this.trailingZeroDisplay = true,
    this.numberingSystem = true,
    this.groupingStrategies = true,
    this.compactNotation = true,
    this.scientificNotation = false,
    this.accountingCurrencySign = false,
    this.hourCycle = true,
    this.calendar = true,
    this.timeZone = true,
    this.ecmaDefaultDigits = true,
    this.recordsUnsupportedOptionErrors = false,
  });

  /// Whether the backend classifies numbers into real CLDR plural
  /// categories (vs. always `other`).
  final bool localeAwarePlurals;

  /// Whether plural selection honors visible fraction digits (CLDR operand
  /// `v`) — the F8 case. A backend that classifies by the bare numeric value
  /// sets this false until it can consume a digit string.
  final bool operandAwarePlurals;

  /// ECMA-402 `signDisplay` (always / never / exceptZero / negative).
  final bool signDisplay;

  /// ECMA-402 `roundingMode` (the nine modes).
  final bool roundingMode;

  /// ECMA-402 `roundingIncrement` (nickel rounding etc.).
  final bool roundingIncrement;

  /// ECMA-402 `trailingZeroDisplay: stripIfInteger`.
  final bool trailingZeroDisplay;

  /// ECMA-402 `numberingSystem` on NUMBER (e.g. `arab` digits).
  final bool numberingSystem;

  /// ECMA-402 v3 `useGrouping` strategy strings (`min2` / `always`), on
  /// top of the boolean forms every backend handles.
  final bool groupingStrategies;

  /// ECMA-402 `notation: compact` (+ `compactDisplay`).
  final bool compactNotation;

  /// ECMA-402 `notation: scientific` / `engineering`. Off by default —
  /// ICU4X ships no exponent-symbol data, so the icu backend degrades.
  final bool scientificNotation;

  /// ECMA-402 `currencySign: accounting`. Off by default — ICU4X ships
  /// no accounting patterns, so the icu backend degrades.
  final bool accountingCurrencySign;

  /// ECMA-402 `hourCycle` on DATETIME (h11 / h12 / h23 / h24).
  final bool hourCycle;

  /// ECMA-402 `calendar` on DATETIME (buddhist, japanese, islamic, …).
  final bool calendar;

  /// ECMA-402 `timeZone` on DATETIME (IANA zone ids).
  final bool timeZone;

  /// ECMA-402 default digit resolution when NO digit options are given:
  /// decimal caps at 3 fraction digits, percent at 0, currency renders
  /// its per-currency minor units. Rendering must also agree with the
  /// 3-digit default the core's plural operands resolve with.
  final bool ecmaDefaultDigits;

  /// Whether an option the backend does NOT support (a `false` flag
  /// above) still renders a usable string AND records a `FluentError`.
  /// The uniform-degrade contract; backends flip this on once their
  /// degrade paths are wired.
  final bool recordsUnsupportedOptionErrors;
}
