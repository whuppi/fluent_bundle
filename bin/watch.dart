// Dev-time watcher for .ftl files.
//
// Usage (from a project that depends on fluent_bundle):
//   dart run fluent_bundle:watch --root lib/i18n
//
// Or globally:
//   dart pub global activate fluent_bundle
//   watch --root lib/i18n
//
// Watches every .ftl file under the given root and prints a JSON event
// to stdout each time one changes. The event shape is stable so
// downstream tools (or a thin shell wrapper around vm_service) can pipe
// it into a running app, which re-reads the changed file and applies it
// via `FluentBundle.addResource(source, allowOverrides: true)`.
//
// Example output:
//
//   {"event":"watching","root":"/abs/path/lib/i18n","count":3}
//   {"event":"change","path":"/abs/path/lib/i18n/en.ftl","kind":"modified"}
//   {"event":"change","path":"/abs/path/lib/i18n/fr.ftl","kind":"created"}
//
// Why JSON-line output and no built-in VM service connection:
//
//   * The app's vm_service URI lives in a place the watcher can't
//     guess (localhost, devtools port, isolate name). Different IDE
//     setups expose it differently.
//   * Apps using state-management preferences (Riverpod, ChangeNotifier,
//     plain Streams) want different glue.
//
// So the watcher does the one thing that's the same everywhere —
// detect file changes — and emits machine-readable events. App-side
// integration is the consumer's wiring.
//
// Design notes:
//
//   * Uses `dart:io`'s `Directory.watch` (recursive). This is
//     cross-platform but per-platform reliability varies. macOS and
//     Linux are reliable; Windows occasionally drops events. The
//     watcher does NOT poll as a fallback — apps that need rock-solid
//     change detection should run a real file-watcher (chokidar, watchman)
//     and feed events in via stdin.
//
//   * Debounce: 100ms. Editors often write a file as a sequence of
//     truncate-then-write operations; without debounce the watcher
//     fires twice per save. 100ms is short enough to feel instant.
//
//   * No `replaceResource` call here — the watcher is purely a
//     change-detection CLI. It doesn't import any of the runtime.
//     Tree-shaken: this file isn't part of the package's library
//     surface.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final root = _parseRoot(args);
  if (root == null) {
    stderr.writeln('Usage: dart run fluent_bundle:watch --root <dir>');
    exit(64); // EX_USAGE
  }

  final dir = Directory(root);
  if (!dir.existsSync()) {
    stderr.writeln('Root directory does not exist: $root');
    exit(66); // EX_NOINPUT
  }

  final ftlFiles =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.ftl'))
          .toList();

  _emit({
    'event': 'watching',
    'root': dir.absolute.path,
    'count': ftlFiles.length,
  });

  // Debounce: collapse rapid bursts of events for the same path. Map
  // path → most-recent timer; firing the timer emits the event.
  final pending = <String, Timer>{};
  const debounce = Duration(milliseconds: 100);

  void scheduleEmit(String path, String kind) {
    pending[path]?.cancel();
    pending[path] = Timer(debounce, () {
      pending.remove(path);
      _emit({'event': 'change', 'path': path, 'kind': kind});
    });
  }

  // Some platforms (notably Linux) don't natively support recursive
  // Directory.watch. We attempt recursive first; if that fails, we
  // fall back to per-subdirectory watchers.
  StreamSubscription<FileSystemEvent>? subscription;
  try {
    subscription = dir
        .watch(recursive: true, events: FileSystemEvent.all)
        .listen((e) => _handleEvent(e, scheduleEmit));
  } on FileSystemException {
    // Fall back to non-recursive on each subdirectory.
    final dirsToWatch =
        dir.listSync(recursive: true).whereType<Directory>().toList()..add(dir);
    final subs = <StreamSubscription<FileSystemEvent>>[];
    for (final d in dirsToWatch) {
      try {
        subs.add(
          d
              .watch(events: FileSystemEvent.all)
              .listen((e) => _handleEvent(e, scheduleEmit)),
        );
      } on FileSystemException {
        // Some directories may not be watchable; skip silently.
      }
    }
    // Combine all subs into one logical "subscription" so Ctrl-C still
    // cleans up. We don't actually need to cancel — process exit does.
    subscription = null;
  }

  // Wait forever (until Ctrl-C). The Dart process holds open as long
  // as the file-system watch is active.
  await ProcessSignal.sigint.watch().first;
  for (final t in pending.values) {
    t.cancel();
  }
  await subscription?.cancel();
  exit(0);
}

void _handleEvent(
  FileSystemEvent event,
  void Function(String path, String kind) scheduleEmit,
) {
  // Only .ftl files. Filtering here keeps `change` events scoped to
  // the files the watcher cares about; stat events on parent
  // directories don't fire spurious updates.
  if (!event.path.endsWith('.ftl')) return;

  final kind = switch (event.type) {
    FileSystemEvent.create => 'created',
    FileSystemEvent.modify => 'modified',
    FileSystemEvent.delete => 'deleted',
    FileSystemEvent.move => 'moved',
    _ => 'changed',
  };
  scheduleEmit(event.path, kind);
}

String? _parseRoot(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--root' && i + 1 < args.length) {
      return args[i + 1];
    }
    if (arg.startsWith('--root=')) {
      return arg.substring('--root='.length);
    }
  }
  return null;
}

void _emit(Map<String, Object?> event) {
  // One event per line, stable JSON shape, flushed immediately so
  // downstream pipes see events in real time.
  stdout.writeln(jsonEncode(event));
}
