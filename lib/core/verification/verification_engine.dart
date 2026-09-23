/// Confidence-aware verification loops (§27-28).
/// Every perception and every tool call passes planned→checked→executed→verified.
class GestureVerification {
  final bool passed;
  final String reason;
  final double confidence;
  GestureVerification(this.passed, this.reason, this.confidence);
}

class VerificationEngine {
  static const double minGestureConfidence = 0.58;
  static const double minToolConfidence = 0.5;

  /// Port of engine.js + app.js gating:
  /// candidate → confidence → temporal consistency → personal calibration
  /// match → OOD → intent window → confirmation if consequential.
  GestureVerification verifyGesture({
    required double confidence,
    required bool temporalConsistent,
    required bool calibrationMatch,
    required bool inDistribution,
    required bool inIntentWindow,
    required bool consequential,
    required bool userConfirmed,
  }) {
    if (confidence < minGestureConfidence) {
      return GestureVerification(false, 'low confidence ${confidence.toStringAsFixed(2)}', confidence);
    }
    if (!temporalConsistent) return GestureVerification(false, 'temporal pattern incomplete', confidence);
    if (!calibrationMatch) return GestureVerification(false, 'outside personal range', confidence);
    if (!inDistribution) return GestureVerification(false, 'OOD/unknown rejected', confidence);
    if (consequential && !inIntentWindow) {
      return GestureVerification(false, 'needs explicit prompt window', confidence);
    }
    if (consequential && !userConfirmed) {
      return GestureVerification(false, 'needs confirmation', confidence);
    }
    return GestureVerification(true, 'passed', confidence);
  }

  ToolVerification verifyToolResult({
    required String tool,
    required bool executed,
    required dynamic returnValue,
  }) {
    if (!executed) return ToolVerification(false, 'tool $tool did not execute');
    if (returnValue == null) return ToolVerification(false, 'tool $tool returned null');
    if (returnValue is Map && returnValue['ok'] == false) {
      return ToolVerification(false, 'tool $tool reported failure: ${returnValue['error']}');
    }
    return ToolVerification(true, 'tool $tool verified');
  }
}

class ToolVerification {
  final bool ok;
  final String detail;
  ToolVerification(this.ok, this.detail);
}
