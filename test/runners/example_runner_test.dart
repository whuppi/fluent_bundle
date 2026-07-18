// Example-showcase lane — the pinned pub.dev example output as its own
// make target / CI job. The battery also rides the vm and web runners;
// this entry point exists so `make test-example` reports it separately.
library;

import 'package:test/test.dart';

import '../example/example_battery.dart';

void main() {
  group('example', registerExampleTests);
}
