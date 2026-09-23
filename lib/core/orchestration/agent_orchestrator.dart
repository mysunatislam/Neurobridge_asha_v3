import '../asha_core/communication_state_machine.dart';
import '../asha_core/perception_aggregator.dart';
import '../rag/memory_store.dart';
import '../services/event_bus.dart';
import '../services/maira_service.dart';
import '../services/tts_service.dart';
import '../database/local_store.dart';
import 'tool_registry.dart';

/// PERCEIVE → INTERPRET → RETRIEVE → REASON → PLAN → VERIFY → ACT
/// → VERIFY RESULT → RESPOND (§21). Deterministic fallback when Maira offline.
class AgentPlan {
  final String speakText;
  final String? tool;
  final Map<String, dynamic> toolArgs;
  final List<ResponseOption> expectedResponses;
  final String reason;
  AgentPlan(this.speakText, {this.tool, Map<String, dynamic>? toolArgs, List<ResponseOption>? expectedResponses, this.reason = ''})
      : toolArgs = toolArgs ?? {}, expectedResponses = expectedResponses ?? [];
}

class AgentOrchestrator {
  final PerceptionAggregator perception;
  final MemoryStore memory;
  final MairaService maira;
  final TtsService tts;
  final AshaToolRegistry tools;
  final CommunicationStateMachine dialogue;
  final AshaEventBus bus;
  final EventLogService logs;

  AgentOrchestrator({
    required this.perception, required this.memory, required this.maira,
    required this.tts, required this.tools, required this.dialogue,
    required this.bus, required this.logs,
  });

  /// Main agentic step for a wake/check-in trigger.
  Future<AgentPlan> handleWakeCheckIn() async {
    final snap = perception.current.toJson();
    final mem = memory.retrieve('wake comfort water caregiver routine', topK: 4)
        .map((d) => {'collection': d.collection, 'text': d.text}).toList();
    if (!maira.isOnline || !maira.settings.configured) {
      return _fallbackWakePlan();
    }
    final res = await maira.reason(
      assessmentContext: 'patient transitioned from sustained rest to awake; check needs gently',
      perception: snap, memory: mem,
    );
    final parsed = res.parsed;
    if (!res.ok || parsed == null) return _fallbackWakePlan();
    try {
      final response = "${parsed['response'] ?? "You're awake. Do you need anything?"}";
      final next = parsed['next_action'] as Map<String, dynamic>?;
      final opts = <ResponseOption>[];
      if (next != null && next['response_options'] is List) {
        for (final o in next['response_options'] as List) {
          if (o is Map) opts.add(ResponseOption('${o['intent']}', '${o['gesture']}'));
        }
      }
      return AgentPlan(response,
          tool: next?['tool']?.toString(),
          expectedResponses: opts.isEmpty
              ? [ResponseOption('yes', 'triple_blink'), ResponseOption('no', 'smile')]
              : opts,
          reason: '${parsed['assessment']}');
    } catch (_) {
      return _fallbackWakePlan();
    }
  }

  AgentPlan _fallbackWakePlan() => AgentPlan(
        "You're awake. Do you need anything?",
        tool: 'ask_patient',
        expectedResponses: [ResponseOption('yes', 'triple_blink'), ResponseOption('no', 'smile')],
        reason: 'deterministic offline fallback',
      );

  /// Speak + enter AWAITING_RESPONSE with explicit mapping announced aloud (§10).
  Future<void> askWithMapping(String question, List<ResponseOption> options) async {
    final mapping = options.map((o) => '${_gesturePhrase(o.gesture)} for ${o.intent}').join('. ');
    final full = '$question $mapping.';
    dialogue.prompt(question, options);
    logs.log({'source': 'agent', 'event': 'prompt', 'question': question, 'mapping': mapping});
    await tts.speak(full);
  }

  static String _gesturePhrase(String gesture) {
    switch (gesture) {
      case 'triple_blink': return 'Blink three times';
      case 'smile': return 'Smile';
      case 'left_return': return 'Turn head left and back';
      case 'right_return': return 'Turn head right and back';
      case 'nod': return 'Nod';
      default: return gesture.replaceAll('_', ' ');
    }
  }

  /// Multimodal discomfort check (§28): HR + tension + confirm.
  Future<AgentPlan> discomfortCheck({required double hr, required double baselineHr, required double tension}) async {
    final elevated = hr > baselineHr + 10;
    if (elevated && tension > 0.6) {
      return AgentPlan(
        'I noticed your heart-rate estimate has stayed above your usual range. Are you uncomfortable?',
        tool: 'ask_patient',
        expectedResponses: [ResponseOption('yes', 'smile'), ResponseOption('no', 'triple_blink')],
        reason: 'multimodal: hr+tension',
      );
    }
    return AgentPlan('Would you like some music, a joke, or would you prefer quiet?',
        tool: 'ask_patient',
        expectedResponses: [ResponseOption('music', 'smile'), ResponseOption('quiet', 'triple_blink')],
        reason: 'routine check-in');
  }
}
