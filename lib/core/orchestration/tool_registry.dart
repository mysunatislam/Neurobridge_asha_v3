import '../safety/safety_engine.dart';
import '../verification/verification_engine.dart';
import '../services/event_bus.dart';
import '../database/local_store.dart';

/// Tool permission tiers (§24).
enum ToolRisk { low, medium, high }

class ToolDef {
  final String name;
  final ToolRisk risk;
  final bool requiresConfirmation;
  ToolDef(this.name, this.risk, {bool? requiresConfirmation})
      : requiresConfirmation = requiresConfirmation ?? (risk == ToolRisk.high);
}

final Map<String, ToolDef> kToolDefs = {
  'speak': ToolDef('speak', ToolRisk.low),
  'ask_patient': ToolDef('ask_patient', ToolRisk.low),
  'start_fingerspeak': ToolDef('start_fingerspeak', ToolRisk.low),
  'start_neurosense': ToolDef('start_neurosense', ToolRisk.low),
  'get_vitals': ToolDef('get_vitals', ToolRisk.low),
  'get_patient_state': ToolDef('get_patient_state', ToolRisk.low),
  'get_patient_profile': ToolDef('get_patient_profile', ToolRisk.low),
  'retrieve_patient_memory': ToolDef('retrieve_patient_memory', ToolRisk.low),
  'tell_joke': ToolDef('tell_joke', ToolRisk.low),
  'show_patient_message': ToolDef('show_patient_message', ToolRisk.low),
  'get_recent_events': ToolDef('get_recent_events', ToolRisk.low),
  'save_patient_memory': ToolDef('save_patient_memory', ToolRisk.medium),
  'send_caregiver_alert': ToolDef('send_caregiver_alert', ToolRisk.medium),
  'set_reminder': ToolDef('set_reminder', ToolRisk.medium),
  'play_saved_audio': ToolDef('play_saved_audio', ToolRisk.medium),
  'start_companion_chat': ToolDef('start_companion_chat', ToolRisk.medium),
  'start_patient_assessment': ToolDef('start_patient_assessment', ToolRisk.medium),
  'log_event': ToolDef('log_event', ToolRisk.medium),
  'call_caregiver': ToolDef('call_caregiver', ToolRisk.high),
  'open_emergency_flow': ToolDef('open_emergency_flow', ToolRisk.high),
  'share_patient_info': ToolDef('share_patient_info', ToolRisk.high),
  'transmit_image': ToolDef('transmit_image', ToolRisk.high),
  'modify_safety_settings': ToolDef('modify_safety_settings', ToolRisk.high),
};

typedef ToolHandler = Future<Map<String, dynamic>> Function(Map<String, dynamic> args);

/// Central AshaToolRegistry (§23). Maira proposes structured actions;
/// registry validates schema → permission → confirmation → execution → verify.
class AshaToolRegistry {
  final Map<String, ToolHandler> _handlers = {};
  final SafetyEngine safety;
  final VerificationEngine verification;
  final AshaEventBus bus;
  final EventLogService logs;
  AshaToolRegistry({required this.safety, required this.verification, required this.bus, required this.logs});

  void register(String name, ToolHandler handler) => _handlers[name] = handler;
  bool get hasTools => _handlers.isNotEmpty;
  List<String> get tools => _handlers.keys.toList()..sort();

  Future<Map<String, dynamic>> execute({
    required String tool,
    Map<String, dynamic>? args,
    required double perceptionConfidence,
    required bool patientConfirmed,
    bool isEmergency = false,
  }) async {
    final a = args ?? {};
    final def = kToolDefs[tool];
    if (def == null) {
      return {'ok': false, 'error': 'hallucinated tool: $tool'};
    }
    if (!_handlers.containsKey(tool)) {
      return {'ok': false, 'error': 'tool not registered: $tool'};
    }
    final decision = safety.checkTool(
      tool: tool, args: a,
      perceptionConfidence: perceptionConfidence,
      patientConfirmed: patientConfirmed,
      isEmergency: isEmergency,
    );
    if (!decision.allowed) {
      logs.log({'source': 'policy', 'tool': tool, 'blocked': decision.reason});
      return {'ok': false, 'error': 'blocked: ${decision.reason}'};
    }
    if (def.requiresConfirmation && !patientConfirmed && !isEmergency) {
      return {'ok': false, 'error': 'confirmation required', 'needs_confirmation': true};
    }
    late Map<String, dynamic> result;
    try {
      result = await _handlers[tool]!(a);
    } catch (e) {
      result = {'ok': false, 'error': e.toString()};
    }
    final v = verification.verifyToolResult(tool: tool, executed: true, returnValue: result);
    logs.log({'source': 'tool', 'tool': tool, 'args': a, 'result': result, 'verification': v.detail});
    return {...result, 'verification': v.detail};
  }
}
