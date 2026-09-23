/// Proactive companion throttling (§15). Asha may initiate, never nag.
class ProactiveContext {
  final String patientState;
  final DateTime? lastInteraction;
  final bool quietHours;
  final bool caregiverPrefersQuiet;
  final double vitalConfidence;
  final int failedComms;
  final int hourOfDay;
  ProactiveContext({
    required this.patientState, this.lastInteraction,
    this.quietHours = false, this.caregiverPrefersQuiet = false,
    this.vitalConfidence = 1, this.failedComms = 0, required this.hourOfDay,
  });
}

class ProactiveInteractionPolicy {
  /// Returns a short prompt, or null when silence is kinder.
  String? decide(ProactiveContext c) {
    if (c.quietHours || c.caregiverPrefersQuiet) return null;
    if (c.patientState == 'probable_sleep' || c.patientState == 'resting') return null;
    final idleMin = c.lastInteraction == null
        ? 999
        : DateTime.now().difference(c.lastInteraction!).inMinutes;
    if (c.failedComms >= 3 && c.vitalConfidence > 0.5) {
      return 'Would you like me to call your caregiver?';
    }
    if (idleMin > 120) {
      return 'Would you like some music, a joke, or would you prefer quiet?';
    }
    return null;
  }
}
