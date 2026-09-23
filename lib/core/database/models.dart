/// Canonical data models. Repository abstractions allow encrypted
/// cloud sync later; local store is file/in-memory for the prototype.
class PatientProfile {
  final String id;
  String name;
  String language; // 'en' | 'bn'
  CommunicationCapabilityProfile capability;
  VitalBaseline? vitalBaseline;
  Map<String, dynamic> preferences;
  PatientProfile({
    required this.id,
    this.name = 'Patient',
    this.language = 'en',
    CommunicationCapabilityProfile? capability,
    this.vitalBaseline,
    Map<String, dynamic>? preferences,
  })  : capability = capability ?? CommunicationCapabilityProfile(),
        preferences = preferences ?? {};

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'language': language,
        'capability': capability.toJson(),
        'vitalBaseline': vitalBaseline?.toJson(),
        'preferences': preferences,
      };
}

class CommunicationCapabilityProfile {
  bool fingerControl;
  double fingerConfidence;
  bool blinkControl;
  bool smileControl;
  bool headControl;
  bool speechAvailable;
  String preferredChannel; // 'fingerspeak' | 'neurosense'
  double responseLatencyMs;
  CommunicationCapabilityProfile({
    this.fingerControl = false,
    this.fingerConfidence = 0.0,
    this.blinkControl = true,
    this.smileControl = true,
    this.headControl = false,
    this.speechAvailable = false,
    this.preferredChannel = 'neurosense',
    this.responseLatencyMs = 800,
  });

  /// Routing rule from spec: reliable finger -> FingerSpeak else NeuroSense.
  static String route({required bool finger, required double conf}) =>
      (finger && conf >= 0.6) ? 'fingerspeak' : 'neurosense';

  void autoRoute() {
    preferredChannel = route(finger: fingerControl, conf: fingerConfidence);
  }

  Map<String, dynamic> toJson() => {
        'finger_control': fingerControl,
        'finger_confidence': fingerConfidence,
        'blink_control': blinkControl,
        'smile_control': smileControl,
        'head_control': headControl,
        'speech_available': speechAvailable,
        'preferred_channel': preferredChannel,
      };
}

class VitalBaseline {
  final double restingHr, normalLow, normalHigh, restingResp;
  final DateTime calibratedAt;
  VitalBaseline({
    required this.restingHr,
    required this.normalLow,
    required this.normalHigh,
    this.restingResp = 16,
    DateTime? calibratedAt,
  }) : calibratedAt = calibratedAt ?? DateTime.now();

  /// Port of vitalsense/calibration.py calibrate_from_baseline:
  /// mean ± 2*sd clamped, sd clamped 3..12.
  static VitalBaseline fromSamples(List<double> hr, {List<double>? resp}) {
    final valid = hr.where((h) => h > 40 && h < 220).toList();
    if (valid.isEmpty) throw ArgumentError('no valid baseline HR samples');
    final mean = valid.reduce((a, b) => a + b) / valid.length;
    double variance = valid.map((h) => (h - mean) * (h - mean)).reduce((a, b) => a + b) / valid.length;
    double sd = variance <= 0 ? 5.0 : _sqrt(variance);
    sd = sd.clamp(3.0, 12.0);
    final r = (resp != null && resp.isNotEmpty)
        ? resp.reduce((a, b) => a + b) / resp.length
        : 16.0;
    return VitalBaseline(
      restingHr: _r1(mean),
      normalLow: _r1((mean - 2 * sd).clamp(40, 200)),
      normalHigh: _r1((mean + 2 * sd).clamp(40, 200)),
      restingResp: _r1(r),
    );
  }

  static double _sqrt(double v) {
    double x = v / 2;
    for (int i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  static double _r1(double v) => (v * 10).round() / 10;

  Map<String, dynamic> toJson() => {
        'restingHr': restingHr, 'normalLow': normalLow,
        'normalHigh': normalHigh, 'restingResp': restingResp,
        'calibratedAt': calibratedAt.toIso8601String(),
      };
}

class CareContact {
  final String id, name, phone;
  final String role; // primary | secondary | emergency
  CareContact({required this.id, required this.name, required this.phone, required this.role});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'role': role};
}

class PatientEventLog {
  final DateTime timestamp;
  final String source, event;
  final double confidence;
  final String context, interpretedIntent, verification, action;
  PatientEventLog({
    required this.source, required this.event, this.confidence = 0,
    this.context = '', this.interpretedIntent = '', this.verification = '',
    this.action = '', DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(), 'source': source,
        'event': event, 'confidence': confidence, 'context': context,
        'interpreted_intent': interpretedIntent,
        'verification': verification, 'action': action,
      };
}

class ToolExecutionRecord {
  final String tool;
  final Map<String, dynamic> args;
  final String permission, result;
  final DateTime timestamp;
  ToolExecutionRecord(this.tool, this.args, this.permission, this.result)
      : timestamp = DateTime.now();
}

class ConversationMessage {
  final String role; // asha | patient | system | caregiver
  final String text;
  final String modality;
  final DateTime timestamp;
  ConversationMessage(this.role, this.text, {this.modality = 'voice'})
      : timestamp = DateTime.now();
}
