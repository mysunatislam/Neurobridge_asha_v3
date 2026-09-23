import 'package:flutter_test/flutter_test.dart';
import 'package:neurobridge_asha/core/safety/safety_engine.dart';
import 'package:neurobridge_asha/core/verification/verification_engine.dart';
import 'package:neurobridge_asha/core/orchestration/tool_registry.dart';
import 'package:neurobridge_asha/core/services/event_bus.dart';
import 'package:neurobridge_asha/core/database/local_store.dart';
import 'package:neurobridge_asha/core/asha_core/communication_state_machine.dart';
import 'package:neurobridge_asha/core/rag/memory_store.dart';
import 'package:neurobridge_asha/core/database/models.dart';

void main() {
  group('SafetyEngine', () {
    final s = SafetyEngine();
    test('high-risk call blocked without confirmation', () {
      final d = s.checkTool(tool: 'call_caregiver', args: {}, perceptionConfidence: 0.9, patientConfirmed: false, isEmergency: false);
      expect(d.allowed, isFalse);
    });
    test('high-risk call allowed with confirmation', () {
      final d = s.checkTool(tool: 'call_caregiver', args: {}, perceptionConfidence: 0.9, patientConfirmed: true, isEmergency: false);
      expect(d.allowed, isTrue);
    });
    test('image needs authorization', () {
      final d = s.checkTool(tool: 'transmit_image', args: {}, perceptionConfidence: 0.9, patientConfirmed: true, isEmergency: false);
      expect(d.allowed, isFalse);
    });
    test('pain language sanitized unless confirmed', () {
      expect(SafetyEngine.sanitize('You are in pain.', painConfirmed: false), contains('uncomfortable'));
      expect(SafetyEngine.sanitize('You are in pain.', painConfirmed: true), contains('pain'));
    });
  });

  group('VerificationEngine', () {
    final v = VerificationEngine();
    test('OOD rejected', () {
      final r = v.verifyGesture(confidence: 0.9, temporalConsistent: true, calibrationMatch: true, inDistribution: false, inIntentWindow: true, consequential: false, userConfirmed: false);
      expect(r.passed, isFalse);
      expect(r.reason, contains('OOD'));
    });
    test('low confidence rejected', () {
      final r = v.verifyGesture(confidence: 0.3, temporalConsistent: true, calibrationMatch: true, inDistribution: true, inIntentWindow: true, consequential: false, userConfirmed: false);
      expect(r.passed, isFalse);
    });
    test('consequential needs confirmation', () {
      final r = v.verifyGesture(confidence: 0.9, temporalConsistent: true, calibrationMatch: true, inDistribution: true, inIntentWindow: true, consequential: true, userConfirmed: false);
      expect(r.passed, isFalse);
    });
    test('tool failure must be reported, never claimed as success', () {
      final r = v.verifyToolResult(tool: 'call_caregiver', executed: true, returnValue: {'ok': false, 'error': 'no permission'});
      expect(r.ok, isFalse);
    });
  });

  group('ToolRegistry policy chain', () {
    test('hallucinated tool rejected', () async {
      final reg = AshaToolRegistry(safety: SafetyEngine(), verification: VerificationEngine(), bus: AshaEventBus(), logs: EventLogService());
      reg.register('speak', (a) async => {'ok': true});
      final r = await reg.execute(tool: 'teleport_patient', perceptionConfidence: 1, patientConfirmed: true);
      expect(r['ok'], isFalse);
      expect('${r['error']}', contains('hallucinated'));
    });
    test('unregistered real tool rejected', () async {
      final reg = AshaToolRegistry(safety: SafetyEngine(), verification: VerificationEngine(), bus: AshaEventBus(), logs: EventLogService());
      final r = await reg.execute(tool: 'speak', perceptionConfidence: 1, patientConfirmed: true);
      expect(r['ok'], isFalse);
    });
    test('patient rejects action → blocked', () async {
      final reg = AshaToolRegistry(safety: SafetyEngine(), verification: VerificationEngine(), bus: AshaEventBus(), logs: EventLogService());
      reg.register('call_caregiver', (a) async => {'ok': true});
      final r = await reg.execute(tool: 'call_caregiver', perceptionConfidence: 0.95, patientConfirmed: false);
      expect(r['ok'], isFalse);
    });
  });

  group('CommunicationStateMachine', () {
    test('full trace IDLE→…→IDLE', () {
      final m = CommunicationStateMachine();
      m.observe();
      m.prompt('Do you need water?', [ResponseOption('yes', 'triple_blink'), ResponseOption('no', 'smile')]);
      expect(m.session.state, CommState.awaitingResponse);
      m.candidate('triple_blink', 0.91);
      expect(m.session.state, CommState.verifying);
      m.confirm('yes', tool: 'send_caregiver_alert');
      m.executing();
      m.actionVerified();
      expect(m.session.state, CommState.idle);
      expect(m.trace.join(' '), contains('awaitingResponse'));
    });
  });

  group('Memory + capability routing', () {
    test('RAG retrieves relevant chunk only', () {
      final mem = MemoryStore.withDefaults();
      final docs = mem.retrieve('smile yes triple blink caregiver', topK: 2);
      expect(docs, isNotEmpty);
      expect(docs.first.text, contains('Smile'));
    });
    test('finger routing rule', () {
      expect(CommunicationCapabilityProfile.route(finger: true, conf: 0.87), 'fingerspeak');
      expect(CommunicationCapabilityProfile.route(finger: false, conf: 0.9), 'neurosense');
      expect(CommunicationCapabilityProfile.route(finger: true, conf: 0.3), 'neurosense');
    });
  });
}
