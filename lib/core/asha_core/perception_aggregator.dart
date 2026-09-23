/// Perception fusion → normalized snapshot for Maira (§38).
class PerceptionSnapshot {
  final String patientState; // awake | resting | probable_sleep | transition
  final double stateConfidence;
  final String commMode;
  final bool commAvailable;
  final double commConfidence;
  final bool faceVisible;
  final double faceTracking;
  final double? hr, resp;
  final double vitalConfidence;
  final String vitalStatus; // RELIABLE | UNCERTAIN | UNRELIABLE
  final String lighting;
  final double facialTension;
  final DateTime timestamp;

  PerceptionSnapshot({
    required this.patientState,
    required this.stateConfidence,
    required this.commMode,
    required this.commAvailable,
    required this.commConfidence,
    required this.faceVisible,
    required this.faceTracking,
    this.hr,
    this.resp,
    required this.vitalConfidence,
    required this.vitalStatus,
    required this.lighting,
    this.facialTension = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'patient': {'state': patientState, 'state_confidence': stateConfidence},
        'communication': {'mode': commMode, 'available': commAvailable, 'confidence': commConfidence},
        'face': {'visible': faceVisible, 'tracking': faceTracking},
        'vitals': {'hr': hr, 'respiration': resp, 'confidence': vitalConfidence, 'status': vitalStatus},
        'environment': {'lighting': lighting},
        'facial': {'tension': facialTension},
      };
}

class PerceptionAggregator {
  PerceptionSnapshot current = PerceptionSnapshot(
    patientState: 'resting', stateConfidence: 0.5,
    commMode: 'neurosense', commAvailable: true, commConfidence: 0.7,
    faceVisible: false, faceTracking: 0,
    vitalConfidence: 0, vitalStatus: 'UNRELIABLE', lighting: 'unknown',
  );

  void update(PerceptionSnapshot snap) => current = snap;

  /// Only structured features go to cloud — never raw video (§18).
  Map<String, dynamic> forMaira() => current.toJson();
}
