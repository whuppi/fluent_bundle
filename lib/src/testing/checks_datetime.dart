import 'package:fluent_bundle/src/testing/expectations.dart';
import 'package:fluent_bundle/src/testing/harness.dart';

/// The per-option DATETIME capability checks — hour cycle, calendar, and
/// time zone, each asserted structurally (a shift the option must cause).
List<ConformanceCheck> datetimeChecks(
  ConformanceHarness h,
  BackendExpectations expectations,
) {
  final checks = <ConformanceCheck>[];

  if (expectations.hourCycle) {
    checks.add((
      name: 'hourCycle: h23 keeps 13:00, h12 folds it to 1',
      run: () {
        final d = DateTime.utc(2026, 1, 2, 13, 0);
        final h23 = h.fmt(
          r'{ DATETIME($d, hour: "numeric", minute: "numeric", '
          r'hourCycle: "h23") }',
          {'d': d},
        );
        if (!h23.contains('13')) {
          throw StateError('hourCycle h23: expected 13 in "$h23"');
        }
        final h12 = h.fmt(
          r'{ DATETIME($d, hour: "numeric", minute: "numeric", '
          r'hourCycle: "h12") }',
          {'d': d},
        );
        if (h12.contains('13')) {
          throw StateError('hourCycle h12: 13 leaked into "$h12"');
        }
      },
    ));
  }

  if (expectations.calendar) {
    checks.add((
      name: 'calendar: buddhist shifts the rendered year',
      run: () {
        final d = DateTime.utc(2026, 6, 15);
        final gregorian = h.fmt(r'{ DATETIME($d, year: "numeric") }', {'d': d});
        final buddhist = h.fmt(
          r'{ DATETIME($d, year: "numeric", calendar: "buddhist") }',
          {'d': d},
        );
        if (buddhist == gregorian) {
          throw StateError(
            'calendar buddhist: same output as gregorian "$buddhist"',
          );
        }
      },
    ));
  }

  if (expectations.timeZone) {
    checks.add((
      name: 'timeZone: an IANA zone shifts the rendered hour',
      run: () {
        final d = DateTime.utc(2026, 1, 2, 12, 0);
        final utc = h.fmt(
          r'{ DATETIME($d, hour: "numeric", minute: "numeric", '
          r'hourCycle: "h23", timeZone: "UTC") }',
          {'d': d},
        );
        final tokyo = h.fmt(
          r'{ DATETIME($d, hour: "numeric", minute: "numeric", '
          r'hourCycle: "h23", timeZone: "Asia/Tokyo") }',
          {'d': d},
        );
        if (tokyo == utc) {
          throw StateError('timeZone Asia/Tokyo: same hour as UTC "$tokyo"');
        }
        if (!tokyo.contains('21')) {
          throw StateError('timeZone Asia/Tokyo: expected 21 in "$tokyo"');
        }
      },
    ));
  }

  return checks;
}
