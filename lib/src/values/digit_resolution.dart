part of 'fluent_value.dart';

// The exact-arithmetic machinery behind FluentNumber.resolveDigits:
// digit-string decomposition of the shortest decimal representation,
// the nine ECMA-402 rounding modes, significant-digit and increment
// rounding via BigInt carries, and the fraction pad/strip that yields
// the plural operand v. No doubles are compared — everything is string
// + BigInt exact.

/// Split non-negative finite [abs] into unsigned integer + fraction digit
/// strings, expanding any exponent in the shortest representation.
(String, String) _decompose(num abs) {
  var s = abs.toString();
  var exp = 0;
  final e = s.indexOf('e');
  if (e >= 0) {
    exp = int.parse(s.substring(e + 1));
    s = s.substring(0, e);
  }
  var intPart = s;
  var fracPart = '';
  final dot = s.indexOf('.');
  if (dot >= 0) {
    intPart = s.substring(0, dot);
    fracPart = s.substring(dot + 1);
  }
  if (exp > 0) {
    if (fracPart.length <= exp) {
      intPart += fracPart.padRight(exp, '0');
      fracPart = '';
    } else {
      intPart += fracPart.substring(0, exp);
      fracPart = fracPart.substring(exp);
    }
  } else if (exp < 0) {
    final shift = -exp;
    if (intPart.length <= shift) {
      fracPart = intPart.padLeft(shift, '0') + fracPart;
      intPart = '0';
    } else {
      fracPart = intPart.substring(intPart.length - shift) + fracPart;
      intPart = intPart.substring(0, intPart.length - shift);
    }
  }
  return (_trimLeadingZeros(intPart), fracPart);
}

/// Whether discarding [remainder] rounds the kept digits up by one, under
/// the nine ECMA-402 rounding modes. [negative] flips the directed modes
/// (magnitudes are unsigned here; `floor` on a negative value grows the
/// magnitude). [lastKept] decides half-even ties.
bool _roundsUp(String mode, bool negative, String remainder, String lastKept) {
  if (!remainder.contains(RegExp('[1-9]'))) return false;
  switch (mode) {
    case 'trunc':
      return false;
    case 'expand':
      return true;
    case 'floor':
      return negative;
    case 'ceil':
      return !negative;
    default:
      final first = remainder.codeUnitAt(0) - 0x30;
      if (first > 5) return true;
      if (first < 5) return false;
      if (remainder.substring(1).contains(RegExp('[1-9]'))) return true;
      // Exact tie.
      return switch (mode) {
        'halfTrunc' => false,
        'halfCeil' => !negative,
        'halfFloor' => negative,
        'halfEven' => (lastKept.codeUnitAt(0) - 0x30).isOdd,
        // halfExpand — the default.
        _ => true,
      };
  }
}

/// Round unsigned `intPart.fracPart` to at most [keep] fraction digits.
(String, String) _roundAtFraction(
  String intPart,
  String fracPart,
  int keep,
  String mode,
  bool negative,
) {
  if (fracPart.length <= keep) return (intPart, fracPart);
  final kept = fracPart.substring(0, keep);
  final remainder = fracPart.substring(keep);
  final lastKept =
      kept.isNotEmpty ? kept[kept.length - 1] : intPart[intPart.length - 1];
  var combined = (intPart + kept).padLeft(keep + 1, '0');
  if (_roundsUp(mode, negative, remainder, lastKept)) {
    combined = (BigInt.parse(combined) + BigInt.one).toString().padLeft(
      keep + 1,
      '0',
    );
  }
  final cut = combined.length - keep;
  return (
    _trimLeadingZeros(combined.substring(0, cut)),
    combined.substring(cut),
  );
}

/// Round unsigned `intPart.fracPart` to [maxSig] significant digits, then
/// strip trailing fractional zeros while at least [minSig] remain.
(String, String) _roundSignificant(
  String intPart,
  String fracPart, {
  required int minSig,
  required int maxSig,
  required String mode,
  required bool negative,
}) {
  final digits = intPart + fracPart;
  final firstSig = digits.indexOf(RegExp('[1-9]'));
  if (firstSig < 0) {
    return ('0', minSig > 1 ? '0' * (minSig - 1) : '');
  }
  // value = 0.<sig> × 10^e
  var e = intPart.length - firstSig;
  var sig = digits.substring(firstSig);
  if (sig.length > maxSig) {
    final kept = sig.substring(0, maxSig);
    final remainder = sig.substring(maxSig);
    sig = kept;
    if (_roundsUp(mode, negative, remainder, kept[kept.length - 1])) {
      sig = (BigInt.parse(kept) + BigInt.one).toString();
      if (sig.length > maxSig) {
        // 999 → 1000: the carry shifts the magnitude.
        e += 1;
        sig = sig.substring(0, maxSig);
      }
    }
  }
  // Trailing zeros in the FRACTION strip down to minSig; integer-part
  // zeros are positional and always stay.
  var keepLen = sig.length;
  final minKeep = minSig > e ? minSig : e;
  while (keepLen > minKeep && sig[keepLen - 1] == '0') {
    keepLen--;
  }
  sig = sig.substring(0, keepLen);
  if (sig.length < minSig) sig = sig.padRight(minSig, '0');

  if (e <= 0) return ('0', '0' * -e + sig);
  if (sig.length <= e) return (sig.padRight(e, '0'), '');
  return (sig.substring(0, e), sig.substring(e));
}

/// Round unsigned `intPart.fracPart` to the nearest multiple of
/// [increment] × 10^-[maxFrac], keeping exactly [maxFrac] fraction digits
/// (an increment requires equal fraction bounds, so no stripping).
(String, String) _roundToIncrement(
  String intPart,
  String fracPart,
  int maxFrac,
  int increment,
  String mode,
  bool negative,
) {
  var x = BigInt.parse(intPart + fracPart);
  final BigInt unit;
  if (fracPart.length >= maxFrac) {
    unit =
        BigInt.from(increment) * BigInt.from(10).pow(fracPart.length - maxFrac);
  } else {
    x *= BigInt.from(10).pow(maxFrac - fracPart.length);
    unit = BigInt.from(increment);
  }
  var q = x ~/ unit;
  final r = x - q * unit;
  if (r != BigInt.zero) {
    final up = switch (mode) {
      'trunc' => false,
      'expand' => true,
      'floor' => negative,
      'ceil' => !negative,
      _ => switch ((r * BigInt.two).compareTo(unit)) {
        > 0 => true,
        < 0 => false,
        _ => switch (mode) {
          'halfTrunc' => false,
          'halfCeil' => !negative,
          'halfFloor' => negative,
          'halfEven' => q.isOdd,
          _ => true,
        },
      },
    };
    if (up) q += BigInt.one;
  }
  final scaled = (q * BigInt.from(increment)).toString().padLeft(
    maxFrac + 1,
    '0',
  );
  final cut = scaled.length - maxFrac;
  return (_trimLeadingZeros(scaled.substring(0, cut)), scaled.substring(cut));
}

/// Pad [frac] with zeros up to [minFrac], or strip trailing zeros down
/// to it — the ECMA "cut" that produces the plural operand `v`.
String _padOrStripFraction(String frac, int minFrac) {
  if (frac.length < minFrac) return frac.padRight(minFrac, '0');
  var end = frac.length;
  while (end > minFrac && frac[end - 1] == '0') {
    end--;
  }
  return frac.substring(0, end);
}

String _trimLeadingZeros(String s) {
  var i = 0;
  while (i < s.length - 1 && s[i] == '0') {
    i++;
  }
  return s.substring(i);
}
