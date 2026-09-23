import 'package:flutter/foundation.dart';
import '../asha_core/asha_state.dart';
import '../asha_core/communication_state_machine.dart';
import '../asha_core/perception_aggregator.dart';
import '../orchestration/agent_orchestrator.dart';
import '../orchestration/tool_registry.dart';
import '../safety/safety_engine.dart';
import '../verification/verification_engine.dart';
import '../rag/memory_store.dart';
import 'event_bus.dart';
import 'maira_service.dart';
import 'tts_service.dart';
import 'camera_coordinator.dart';
import '../database/local_store.dart';
import '../../features/fingerspeak/fingerspeak_service.dart';
import '../../features/neurosense/neurosense_service.dart';
import '../../features/vitalsense/vitalsense_service.dart';
import '../../features/vitalsense/sleep_wake_service.dart';

/// Composition root: wires every service exactly once.
class AppScope extends ChangeNotifier {
  late final AshaEventBus bus;
  late final EventLogService logs;
  late final LocalStore store;
  late final MemoryStore memory;
  late final MairaService maira;
  late final TtsService tts;
  late final SafetyEngine safety;
  late final VerificationEngine verification;
  late final AshaToolRegistry tools;
  late final PerceptionAggregator perception;
  late final AgentOrchestrator agent;
  late final AshaState asha;
  late final CameraCoordinator camera;
  late final FingerSpeakService fingerspeak;
  late final NeuroSenseService neurosense;
  late final VitalSenseService vitals;
  late final SleepWakeService sleepWake;

  bool ready = false;

  Future<void> init() async {
    bus = AshaEventBus();
    logs = EventLogService();
    store = LocalStore();
    await store.load();
    memory = MemoryStore.withDefaults();
    final savedMaira = store.get('maira');
    maira = MairaService(savedMaira is Map<String, dynamic>
        ? MairaSettings.fromJson(Map<String, dynamic>.from(savedMaira))
        : MairaSettings());
    tts = TtsService();
    try {
      await tts.init();
    } catch (_) {
      // Voice stays in log fallback; app must not crash.
    }
    safety = SafetyEngine();
    verification = VerificationEngine();
    tools = AshaToolRegistry(safety: safety, verification: verification, bus: bus, logs: logs);
    perception = PerceptionAggregator();
    asha = AshaState();
    camera = CameraCoordinator();
    fingerspeak = FingerSpeakService(bus: bus, logs: logs);
    neurosense = NeuroSenseService(bus: bus, logs: logs);
    vitals = VitalSenseService(bus: bus, logs: logs);
    sleepWake = SleepWakeService();
    agent = AgentOrchestrator(
      perception: perception, memory: memory, maira: maira,
      tts: tts, tools: tools, dialogue: asha.dialogue, bus: bus, logs: logs,
    );
    _registerTools();
    ready = true;
    notifyListeners();
  }

  void _registerTools() {
    tools.register('speak', (a) async {
      await tts.speak('${a['text'] ?? ''}');
      return {'ok': true};
    });
    tools.register('ask_patient', (a) async {
      await agent.askWithMapping('${a['question'] ?? 'Do you need anything?'}',
          (a['options'] as List? ?? []).map((o) {
        final m = Map<String, dynamic>.from(o as Map);
        return ResponseOption('${m['intent']}', '${m['gesture']}');
      }).toList());
      return {'ok': true};
    });
    tools.register('get_vitals', (a) async => {
          'ok': true, 'hr': vitals.last.bpm, 'resp': vitals.last.resp,
          'confidence': vitals.last.confidence, 'status': vitals.last.status,
        });
    tools.register('get_patient_state', (a) async => {'ok': true, ...perception.current.toJson()});
    tools.register('get_patient_profile', (a) async => {'ok': true, ...asha.patient.toJson()});
    tools.register('retrieve_patient_memory', (a) async {
      final docs = memory.retrieve('${a['query'] ?? ''}', topK: 4);
      return {'ok': true, 'docs': docs.map((d) => d.toJson()).toList()};
    });
    tools.register('save_patient_memory', (a) async {
      memory.upsert(MemoryDocument('${a['id'] ?? DateTime.now().toIso8601String()}',
          '${a['collection'] ?? 'RecentEvents'}', '${a['text'] ?? ''}'));
      return {'ok': true};
    });
    tools.register('tell_joke', (a) async {
      const joke = 'Why did the mobile phone go to the doctor? It had a weak signal — just like my jokes need your smile to get stronger.';
      await tts.speak(joke);
      return {'ok': true, 'joke': joke};
    });
    tools.register('log_event', (a) async {
      logs.log(Map<String, dynamic>.from(a));
      return {'ok': true};
    });
    tools.register('get_recent_events', (a) async => {'ok': true, 'events': logs.recent(n: 20)});
    tools.register('send_caregiver_alert', (a) async {
      bus.emit(AshaEvent(AshaEventType.patientRequest, source: 'agent', payload: {'alert': a['message']}));
      return {'ok': true, 'queued': true};
    });
    tools.register('call_caregiver', (a) async {
      bus.emit(AshaEvent(AshaEventType.caregiverCallStarted, source: 'agent', payload: {'contact': a['contact_id'] ?? 'primary'}));
      return {'ok': true, 'dialing': a['contact_id'] ?? 'primary'};
    });
    tools.register('open_emergency_flow', (a) async {
      bus.emit(AshaEvent(AshaEventType.emergencyRequested, source: 'agent', payload: Map<String, dynamic>.from(a)));
      return {'ok': true};
    });
    tools.register('start_fingerspeak', (a) async => {'ok': true, 'mode': 'fingerspeak'});
    tools.register('start_neurosense', (a) async => {'ok': true, 'mode': 'neurosense'});
    tools.register('start_companion_chat', (a) async => {'ok': true});
    tools.register('start_patient_assessment', (a) async => {'ok': true});
    tools.register('set_reminder', (a) async => {'ok': true});
    tools.register('play_saved_audio', (a) async => {'ok': true});
    tools.register('show_patient_message', (a) async => {'ok': true});
  }
}
