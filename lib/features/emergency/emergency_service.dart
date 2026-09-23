import 'package:flutter/foundation.dart';
import '../../core/database/models.dart';
import '../../core/services/event_bus.dart';
import '../../core/database/local_store.dart';

/// Escalation ladder L0..L6 (§26) + guarded call flow (§25, §59).
class EscalationPolicy {
  int level = 0;
  String reason = '';
  void raise(int l, String r) {
    if (l > level) {
      level = l;
      reason = r;
    }
  }

  void reset() {
    level = 0;
    reason = '';
  }

  String describe() => switch (level) {
        0 => 'Observation only',
        1 => 'Asha asks patient',
        2 => 'Patient confirms assistance required',
        3 => 'Notify caregiver',
        4 => 'Call primary caregiver',
        5 => 'Try backup caregiver',
        _ => 'Emergency workflow under configured policy',
      };
}

class EmergencyService extends ChangeNotifier {
  final AshaEventBus bus;
  final EventLogService logs;
  List<CareContact> contacts = [
    CareContact(id: 'primary', name: 'Rima', phone: '+880100000000', role: 'primary'),
    CareContact(id: 'secondary', name: 'Karim', phone: '+880100000001', role: 'secondary'),
  ];
  final EscalationPolicy escalation = EscalationPolicy();
  bool emergencyArmed = false; // accidental-activation protection: press-and-hold
  String lastAction = '';

  EmergencyService({required this.bus, required this.logs});

  void arm(bool v) {
    emergencyArmed = v;
    notifyListeners();
  }

  CareContact contact(String id) =>
      contacts.firstWhere((c) => c.id == id, orElse: () => contacts.first);

  /// Guarded call: intent → verify → dial → confirm on screen + voice.
  Future<Map<String, dynamic>> requestCall({required String contactId, required bool patientConfirmed, required double confidence}) async {
    if (!patientConfirmed) return {'ok': false, 'error': 'confirmation required'};
    if (confidence < 0.5) return {'ok': false, 'error': 'low confidence'};
    final c = contact(contactId);
    escalation.raise(4, 'patient confirmed call to ${c.name}');
    bus.emit(AshaEvent(AshaEventType.caregiverCallRequested, source: 'emergency', payload: {'contact_id': c.id}));
    // Production: url_launcher / telecom intent. Prototype records intent.
    lastAction = 'Calling ${c.name} (${c.phone}) now.';
    bus.emit(AshaEvent(AshaEventType.caregiverCallStarted, source: 'emergency', payload: {'contact_id': c.id}));
    logs.log({'source': 'emergency', 'event': 'call', 'action': lastAction});
    notifyListeners();
    return {'ok': true, 'dialing': c.phone};
  }

  Future<void> emergency({required bool confirmed}) async {
    if (!confirmed) return;
    escalation.raise(6, 'confirmed emergency flow');
    bus.emit(AshaEvent(AshaEventType.emergencyRequested, source: 'patient', payload: {}));
    lastAction = 'Emergency workflow started. Contacting ${contacts.first.name}.';
    logs.log({'source': 'emergency', 'event': 'emergency', 'action': lastAction});
    notifyListeners();
  }
}
