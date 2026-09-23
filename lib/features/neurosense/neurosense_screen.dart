import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';

/// NeuroSense module screen: calibration status, live gesture state.
/// Technical values (EAR/yaw) live here, never on the patient dashboard.
class NeuroSenseScreen extends StatelessWidget {
  final AppScope scope;
  const NeuroSenseScreen({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: scope.neurosense,
      builder: (context, _) {
        final s = scope.neurosense.status();
        return Scaffold(
          appBar: AppBar(title: const Text('NeuroSense Face')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Temporal personalized detection: blink OPEN→CLOSED→OPEN, head excursion+return, smile hysteresis. Tracking loss invalidates incomplete cycles.',
                style: TextStyle(color: Color(0xFF93A1BB))),
            const SizedBox(height: 10),
            ListTile(title: const Text('Tracking quality'), trailing: Text('${((s['tracking'] as double) * 100).toStringAsFixed(0)}%')),
            ListTile(title: const Text('Calibrated twin'), trailing: Text('${s['calibrated']}')),
            ListTile(title: const Text('Last gesture'), trailing: Text('${s['lastGesture']}')),
            ListTile(title: const Text('Smile intensity'), trailing: Text('${(s['smile'] as double).toStringAsFixed(2)}')),
          ]),
        );
      },
    );
  }
}
