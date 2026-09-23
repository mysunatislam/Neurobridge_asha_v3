import '../../core/rag/memory_store.dart';

/// Companion mode (§14): jokes, stories, reassurance, routine, saved messages.
/// Never claims to be human; supplements family/caregiver.
class CompanionService {
  final MemoryStore memory;
  String talkativeness = 'Balanced'; // Short | Balanced | Conversational
  String humor = 'Gentle'; // Off | Gentle | Frequent
  CompanionService(this.memory);

  String greeting() {
    final mems = memory.retrieve('likes routine daughter music', topK: 3);
    final hint = mems.isEmpty ? '' : ' I remember ${mems.first.text}';
    return "I'm here with you.$hint Would you like a joke, some music, or quiet company?";
  }

  String joke() => 'A cricket ball walks into a calm room and says: no rush — I\'ll wait for your smile before I bounce.';

  String story() =>
      'A short story: a river learned to wait. It did not hurry the boat; it carried it gently. Like Asha — I wait, I listen, and I stay nearby.';

  String reassurance() =>
      'You are doing well. I am staying with you. Your caregiver can be called any time you ask.';

  /// Context-aware: smile during a joke is NOT an AAC command unless
  /// dialogue is in an expected-response window (caller must enforce).
  bool shouldTreatSmileAsCommand({required bool inResponseWindow}) => inResponseWindow;
}
