import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';

/// Developer / research mode (§63): landmarks, EAR/MAR, yaw/pitch/roll,
/// FPS, latency, confidences, OOD, VitalSense quality, Maira + tool traces.
/// Never exposes API secrets.
class DeveloperScreen extends StatelessWidget {
  final AppScope scope;
  const DeveloperScreen({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    final v = scope.vitals.last;
    final n = scope.neurosense.status();
    return Scaffold(
      appBar: AppBar(title: const Text('Developer mode')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _kv('Face tracking quality', '${((n['tracking'] as double) * 100).toStringAsFixed(1)}%'),
        _kv('Calibrated', '${n['calibrated']}'),
        _kv('Last gesture', '${n['lastGesture']}'),
        _kv('Smile intensity', '${(n['smile'] as double).toStringAsFixed(3)}'),
        _kv('Vital confidence', '${v.confidence.toStringAsFixed(1)}% (${v.status})'),
        _kv('Motion gate', v.motion),
        _kv('Camera', '${scope.camera.quality} @ ${scope.camera.fps.toStringAsFixed(1)} fps (${scope.camera.mode.name})'),
        _kv('Tools', scope.tools.tools.join(', ')),
        _kv('Maira', scope.maira.isOnline ? (scope.maira.settings.configured ? 'connected' : 'not configured') : 'offline'),
        const SizedBox(height: 8),
        const Text('Tool-call trace', style: TextStyle(fontWeight: FontWeight.w700)),
        ...scope.logs.recent(n: 25).map((e) => Text(
            '${e['timestamp']} [${e['source']}] ${e['event'] ?? e['tool'] ?? ''} ${e['verification'] ?? ''}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
      ]),
    );
  }

  Widget _kv(String k, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 170, child: Text(k, style: const TextStyle(color: Color(0xFF93A1BB)))),
          Expanded(child: Text(val, style: const TextStyle(fontFamily: 'monospace'))),
        ]),
      );
}
