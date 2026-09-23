import 'package:flutter/foundation.dart';
import '../../core/database/models.dart';
import '../neurosense/face_models.dart';

/// Automated patient assessment (§29-30): communication ability, vision
/// quality, NeuroSense + FingerSpeak + VitalSense calibration → recommendation.
/// Never a neurological diagnosis.
class AssessmentResult {
  final CommunicationCapabilityProfile capability;
  final String recommendedPrimary;
  final String recommendedBackup;
  final List<String> reliableGestures;
  final List<String> unreliable;
  final List<String> guidance;
  final String vitalQuality;
  AssessmentResult({
    required this.capability, required this.recommendedPrimary,
    required this.recommendedBackup, required this.reliableGestures,
    required this.unreliable, required this.guidance, required this.vitalQuality,
  });
}

class AssessmentService extends ChangeNotifier {
  int step = 0;
  final Map<String, bool> checks = {};
  final Map<String, double> quality = {};

  void mark(String key, {bool value = true, double q = 1}) {
    checks[key] = value;
    quality[key] = q;
    notifyListeners();
  }

  AssessmentResult complete() {
    final finger = (checks['finger_yes'] == true || checks['finger_water'] == true);
    final fingerConf = quality['finger'] ?? (finger ? 0.8 : 0.2);
    final blink = checks['blink'] != false;
    final smile = checks['smile'] != false;
    final head = checks['head_left'] == true && checks['head_right'] == true;
    final cap = CommunicationCapabilityProfile(
      fingerControl: finger, fingerConfidence: fingerConf,
      blinkControl: blink, smileControl: smile, headControl: head,
    )..autoRoute();
    final reliable = <String>[];
    final unreliable = <String>[];
    if (blink) reliable.add('blink ×3'); else unreliable.add('blink');
    if (smile) reliable.add('smile'); else unreliable.add('smile');
    if (head) reliable.addAll(['head left-return', 'head right-return']);
    else unreliable.add('head gestures currently unreliable');
    if (finger) reliable.add('FingerSpeak gestures');
    final guidance = <String>[];
    if (!head) guidance.add('Blink recognition is reliable, but head-turn detection is inconsistent. Recalibrate head movement with the camera slightly farther away.');
    if (!finger) guidance.add('Hand tracking quality is low. Improve lighting or switch to facial communication.');
    if ((quality['vital'] ?? 1) < 0.45) guidance.add('VitalSense cannot obtain a reliable signal because of movement. Try again when the patient is still.');
    if (guidance.isEmpty) guidance.add('Calibration looks good. Test with the intended user and record false activations and misses.');
    return AssessmentResult(
      capability: cap,
      recommendedPrimary: cap.preferredChannel == 'fingerspeak' ? 'FingerSpeak' : 'NeuroSense blink communication',
      recommendedBackup: cap.preferredChannel == 'fingerspeak' ? 'NeuroSense blink communication' : 'FingerSpeak (if hand returns)',
      reliableGestures: reliable, unreliable: unreliable,
      guidance: guidance,
      vitalQuality: (quality['vital'] ?? 0.8) >= 0.7 ? 'good' : 'poor',
    );
  }

  FaceCalibrationProfile draftFromChecks() {
    // Simplified: real build() in calibration.js uses stage statistics;
    // here we mark calibrated when core gestures validated.
    return FaceCalibrationProfile(calibrated: (checks['blink'] == true && checks['smile'] == true));
  }
}
