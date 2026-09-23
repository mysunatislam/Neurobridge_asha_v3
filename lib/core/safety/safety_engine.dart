/// Deterministic safety rules OUTSIDE the LLM. Maira proposes,
/// SafetyEngine disposes. Mirrors spec §41.
class SafetyDecision {
  final bool allowed;
  final String reason;
  SafetyDecision(this.allowed, this.reason);
}

class SafetyEngine {
  /// Returns allowed=false with reason when blocked.
  SafetyDecision checkTool({
    required String tool,
    required Map<String, dynamic> args,
    required double perceptionConfidence,
    required bool patientConfirmed,
    required bool isEmergency,
  }) {
    // High-risk tools need confirmation + decent perception.
    const highRisk = {'call_caregiver', 'open_emergency_flow', 'share_patient_info', 'transmit_image', 'modify_safety_settings'};
    if (highRisk.contains(tool)) {
      if (!patientConfirmed && !isEmergency) {
        return SafetyDecision(false, 'High-risk tool $tool requires patient confirmation');
      }
      if (perceptionConfidence < 0.5 && tool == 'open_emergency_flow' && !isEmergency) {
        return SafetyDecision(false, 'Emergency needs sustained evidence, not a single noisy frame');
      }
    }
    if (tool == 'transmit_image' && args['authorized'] != true) {
      return SafetyDecision(false, 'Image transmission requires explicit authorization');
    }
    return SafetyDecision(true, 'ok');
  }

  /// Language guard: observations vs confirmed reports.
  static String healthPhrase({
    required bool confirmedByPatient,
    required String observation,
    required String question,
  }) {
    if (confirmedByPatient) return 'You told me that you are uncomfortable.';
    return '$observation $question';
  }

  static const bannedPhrases = [
    'You are having a medical emergency',
    'You are in pain', // unless patient communicated pain
  ];

  static String sanitize(String text, {required bool painConfirmed}) {
    var out = text;
    if (!painConfirmed) {
      out = out.replaceAll('You are in pain.', 'You seem uncomfortable.');
    }
    return out;
  }
}
