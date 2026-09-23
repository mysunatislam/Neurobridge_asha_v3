import 'package:flutter/foundation.dart';
import 'face_models.dart';
import '../../core/services/event_bus.dart';
import '../../core/database/local_store.dart';

/// NeuroSense Face service: temporal personalized facial AAC.
/// Consumed by Asha Core as structured events, never raw UI state.
class NeuroSenseService extends ChangeNotifier {
  final AshaEventBus bus;
  final EventLogService logs;
  FaceCalibrationProfile calibration = FaceCalibrationProfile();
  late BlinkDetector blink;
  late HeadTurnDetector headYaw;
  late HeadTurnDetector nod;
  late SmileDetector smile;
  final NeuroSenseCommandEngine commands = NeuroSenseCommandEngine();

  bool tracking = false;
  double trackingQuality = 0;
  String lastGesture = '—';
  int tripleBlinkCount = 0;

  // Smile intensity tracking for yes/no mapping
  double smileIntensity = 0;
  bool smileHeld = false;

  NeuroSenseService({required this.bus, required this.logs}) {
    blink = BlinkDetector(calibration);
    headYaw = HeadTurnDetector(calibration);
    nod = HeadTurnDetector(calibration, isNod: true);
    smile = SmileDetector();
  }

  void loadCalibration(FaceCalibrationProfile c) {
    calibration = c;
    blink = BlinkDetector(c);
    headYaw = HeadTurnDetector(c);
    nod = HeadTurnDetector(c, isNod: true);
    smile = SmileDetector();
    notifyListeners();
  }

  /// Feed one processed frame (MediaPipe Tasks callback in production).
  List<Map<String, dynamic>> processFrame(FaceFrame f) {
    trackingQuality = f.faceQuality;
    tracking = f.faceQuality >= 0.65;
    if (!tracking) {
      blink.reset();
      notifyListeners();
      return [];
    }
    final events = <FaceGestureEvent>[
      ...blink.update(f),
      ...headYaw.update(f.yaw, f.timestampMs, f.faceQuality),
      ...nod.update(f.pitch, f.timestampMs, f.faceQuality),
      ...smile.update((f.smileLeft + f.smileRight) / 2,
          f.smileLeft >= calibration.closedSmileThresholdLeft ||
              f.smileRight >= calibration.closedSmileThresholdRight,
          f.timestampMs, f.faceQuality),
    ];
    smileIntensity = (f.smileLeft + f.smileRight) / 2;
    for (final e in events) {
      lastGesture = e.type;
      logs.log({'source': 'neurosense', 'event': e.type, 'confidence': e.confidence});
      bus.emit(AshaEvent(AshaEventType.faceGestureConfirmed,
          source: 'neurosense', payload: e.toJson()));
    }
    final cmds = commands.ingest(events, f.timestampMs);
    for (final c in cmds) {
      bus.emit(AshaEvent(AshaEventType.patientRequest,
          source: 'neurosense', payload: {'command': c['command'], 'phrase': c['phrase']}));
      logs.log({'source': 'neurosense', 'event': 'command', 'action': c['command']});
    }
    notifyListeners();
    return cmds;
  }

  /// Contextual AAC: listen for N intentional blinks OR held smile in window.
  Future<String?> awaitResponse({
    required int blinkTarget,
    required Duration timeout,
    void Function(int blinks, bool smiling)? onProgress,
  }) async {
    // Production: subscribes to live events. Prototype: simulated hook
    // used by simulation panel + tests via injectTestGestures.
    return null;
  }

  Map<String, dynamic> status() => {
        'tracking': trackingQuality,
        'calibrated': calibration.calibrated,
        'lastGesture': lastGesture,
        'smile': smileIntensity,
      };
}
