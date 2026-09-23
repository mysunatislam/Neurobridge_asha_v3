import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Local-first JSON store (no native plugins for prototype reliability).
/// Interface mirrors a SQLite/Drift repository so drift/sqflite can replace
/// the backend later without touching callers.
class LocalStore {
  final Map<String, dynamic> _mem = {};
  final String? filePath;
  LocalStore({this.filePath});

  Future<void> load() async {
    if (filePath == null) return;
    try {
      final f = File(filePath!);
      if (await f.exists()) {
        final raw = await f.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _mem.addAll(decoded);
        }
      }
    } catch (_) {
      // Fail-soft: prototype keeps running on in-memory state.
    }
  }

  Future<void> _persist() async {
    if (filePath == null) return;
    try {
      await File(filePath!).writeAsString(jsonEncode(_mem));
    } catch (_) {}
  }

  dynamic get(String key) => _mem[key];
  Future<void> set(String key, dynamic value) async {
    _mem[key] = value;
    await _persist();
  }

  Map<String, dynamic> snapshot() => Map.of(_mem);
}

/// Event log with capped ring buffer.
class EventLogService {
  final List<Map<String, dynamic>> _events = [];
  final StreamController<Map<String, dynamic>> _stream =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get stream => _stream.stream;
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);

  void log(Map<String, dynamic> event) {
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      ...event,
    };
    _events.add(entry);
    if (_events.length > 1000) _events.removeAt(0);
    _stream.add(entry);
  }

  List<Map<String, dynamic>> recent({int n = 20}) =>
      _events.reversed.take(n).toList();
}
