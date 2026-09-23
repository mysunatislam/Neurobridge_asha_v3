import 'package:flutter/foundation.dart';

/// Conservative sleep/wake observer (§19). Never claims medical sleep stages.
/// Outputs awake | resting | probable_sleep | transition + confidence.
class SleepWakeState {
  final String state;
  final double confidence;
  SleepWakeState(this.state, this.confidence);
}

class SleepWakeService extends ChangeNotifier {
  SleepWakeState current = SleepWakeState('resting', 0.6);
  double _eyeClosedSecs = 0;
  double _stillSecs = 0;

  void update({
    required bool facePresent,
    required bool eyesClosed,
    required double movement, // 0..1 landmark displacement proxy
    required double dtSecs,
  }) {
    if (!facePresent) {
      _set('transition', 0.4);
      return;
    }
    if (eyesClosed && movement < 0.15) {
      _eyeClosedSecs += dtSecs;
      _stillSecs += dtSecs;
    } else if (movement < 0.1) {
      _stillSecs += dtSecs;
      _eyeClosedSecs = 0;
    } else {
      _eyeClosedSecs = 0;
      _stillSecs = 0;
      _set('awake', 0.9);
      return;
    }
    if (_eyeClosedSecs > 120 && _stillSecs > 120) {
      _set('probable_sleep', 0.85); // sustained probable sleep/rest
    } else if (_stillSecs > 30) {
      _set('resting', 0.75);
    } else {
      _set('transition', 0.55);
    }
  }

  void _set(String s, double c) {
    // Require confidence before announcing wake (no single eye-opening).
    if (s == 'awake' && current.state != 'awake' && c < 0.8) {
      current = SleepWakeState('transition', 0.6);
    } else {
      current = SleepWakeState(s, c);
    }
    notifyListeners();
  }
}
