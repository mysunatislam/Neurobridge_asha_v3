import 'package:flutter/foundation.dart';

/// Shared camera coordinator (§46): ONE stream, many subscribers.
/// Face landmarks → NeuroSense, facial ROI → VitalSense, hand → FingerSpeak.
/// Prototype simulates frames; production plugs camera + MediaPipe Tasks.
enum PowerMode { lowPower, activeObservation, communication, assessment }

class FrameMeta {
  final DateTime timestamp;
  final double lighting; // 0..1
  final bool facePresent;
  final bool handPresent;
  FrameMeta({required this.timestamp, this.lighting = 0.8, this.facePresent = true, this.handPresent = false});
}

class CameraCoordinator extends ChangeNotifier {
  bool running = false;
  PowerMode mode = PowerMode.activeObservation;
  double fps = 0;
  String quality = 'good'; // good | low_light | obstructed | unstable
  int _frames = 0;
  DateTime? _since;

  void start() {
    running = true;
    _since = DateTime.now();
    notifyListeners();
  }

  void stop() {
    running = false;
    notifyListeners();
  }

  void setMode(PowerMode m) {
    mode = m;
    notifyListeners();
  }

  /// Target FPS per power mode (§47): never run all models at max 24/7.
  int get targetFps => switch (mode) {
        PowerMode.lowPower => 5,
        PowerMode.activeObservation => 15,
        PowerMode.communication => 30,
        PowerMode.assessment => 30,
      };

  void noteFrame(FrameMeta meta) {
    _frames++;
    if (meta.lighting < 0.25) {
      quality = 'low_light';
    } else if (!meta.facePresent && !meta.handPresent) {
      quality = 'obstructed';
    } else {
      quality = 'good';
    }
    if (_since != null && DateTime.now().difference(_since!).inSeconds >= 2) {
      fps = _frames / DateTime.now().difference(_since!).inSeconds;
      _frames = 0;
      _since = DateTime.now();
      notifyListeners();
    }
  }
}
