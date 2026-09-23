import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';
import '../../core/services/event_bus.dart';
import '../../core/services/camera_coordinator.dart';
import '../../core/asha_core/perception_aggregator.dart';
import '../neurosense/face_models.dart';

/// Developer simulation panel (§66): test without a patient.
class SimulationPanel extends StatelessWidget {
  final AppScope scope;
  const SimulationPanel({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulation (developer)')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          _btn(context, 'Simulate Awake', () => _awake()),
          _btn(context, 'Simulate Triple Blink', () => _tripleBlink()),
          _btn(context, 'Simulate Smile', () => _smile()),
          _btn(context, 'Simulate Water Request', () => _water()),
          _btn(context, 'Simulate Elevated HR', () => _elevatedHr()),
          _btn(context, 'Simulate Poor Vital Confidence', () => _poorVital()),
          _btn(context, 'Simulate Camera Lost', () => _cameraLost()),
          _btn(context, 'Simulate Maira Offline', () => _mairaOffline()),
          _btn(context, 'Simulate Caregiver Call', () => _call()),
          _btn(context, 'Simulate Emergency', () => _emergency()),
        ]),
        const SizedBox(height: 16),
        const Text('Event history', style: TextStyle(fontWeight: FontWeight.w700)),
        ...scope.bus.history.reversed.take(15).map((e) => ListTile(
              dense: true,
              title: Text('${e.type.name} · ${e.source}'),
              subtitle: Text('${e.timestamp.toIso8601String()}'),
            )),
      ]),
    );
  }

  Widget _btn(BuildContext context, String label, VoidCallback onTap) => ElevatedButton(
        style: ElevatedButton.styleFrom(minimumSize: const Size(180, 52)),
        onPressed: () {
          onTap();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
        },
        child: Text(label, textAlign: TextAlign.center),
      );

  void _awake() {
    scope.perception.update(PerceptionSnapshot(
      patientState: 'awake', stateConfidence: 0.92,
      commMode: 'neurosense', commAvailable: true, commConfidence: 0.88,
      faceVisible: true, faceTracking: 0.91, hr: 78, resp: 15,
      vitalConfidence: 0.82, vitalStatus: 'RELIABLE', lighting: 'good',
    ));
    scope.bus.emit(AshaEvent(AshaEventType.patientAwake, source: 'simulation'));
    scope.agent.handleWakeCheckIn().then((plan) => scope.tts.speak(plan.speakText));
  }

  void _tripleBlink() {
    // Feed 3 deliberate blinks through the real BlinkDetector path.
    final cal = scope.neurosense.calibration;
    int t = 1000;
    for (int i = 0; i < 3; i++) {
      scope.neurosense.processFrame(FaceFrame(timestampMs: t, earLeft: 0.27, earRight: 0.27, faceQuality: 0.95));
      t += 100;
      scope.neurosense.processFrame(FaceFrame(timestampMs: t, earLeft: 0.08, earRight: 0.08, blendLeft: 0.9, blendRight: 0.9, faceQuality: 0.95));
      t += 350;
      scope.neurosense.processFrame(FaceFrame(timestampMs: t, earLeft: 0.27, earRight: 0.27, faceQuality: 0.95));
      t += 400;
    }
    scope.bus.emit(AshaEvent(AshaEventType.gestureCandidate, source: 'simulation', payload: {'gesture': 'triple_blink'}));
  }

  void _smile() {
    scope.neurosense.processFrame(FaceFrame(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        earLeft: 0.27, earRight: 0.27, smileLeft: 0.6, smileRight: 0.62, faceQuality: 0.9));
  }

  void _water() {
    scope.bus.emit(AshaEvent(AshaEventType.patientRequest,
        source: 'simulation', payload: {'command': 'water', 'phrase': 'I need water.'}));
    scope.tts.speak('Okay. You need water. Would you like me to call your caregiver?');
  }

  void _elevatedHr() {
    scope.vitals.setBaseline(scope.vitals.baseline);
    scope.vitals.ingest(
        bpm: 108, resp: 18, roiStability: 0.9, lighting: 0.8,
        motion: 0.1, sqi: 0.9, peakClarity: 0.2, facialTension: 0.74);
  }

  void _poorVital() {
    scope.vitals.ingest(
        bpm: 75, resp: 15, roiStability: 0.3, lighting: 0.15,
        motion: 0.9, sqi: 0.2, peakClarity: 0.02);
  }

  void _cameraLost() {
    scope.camera.noteFrame(FrameMeta(timestamp: DateTime.now(), facePresent: false, handPresent: false, lighting: 0.1));
    scope.bus.emit(AshaEvent(AshaEventType.cameraQualityLow, source: 'simulation'));
  }

  void _mairaOffline() {
    scope.maira.setOnline(false);
    scope.asha.setDegraded(true);
  }

  void _call() {
    scope.bus.emit(AshaEvent(AshaEventType.caregiverCallRequested, source: 'simulation', payload: {'contact_id': 'primary'}));
  }

  void _emergency() {
    scope.bus.emit(AshaEvent(AshaEventType.emergencyRequested, source: 'simulation'));
  }
}
