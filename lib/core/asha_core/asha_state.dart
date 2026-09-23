import 'package:flutter/foundation.dart';
import '../database/models.dart';
import 'communication_state_machine.dart';

/// Global Asha presence + monitoring state (§49).
enum AshaPresence { idle, listening, thinking, speaking, monitoring, needsAttention, offline }

class AshaState extends ChangeNotifier {
  AshaPresence presence = AshaPresence.idle;
  String role = ''; // '' | 'patient' | 'caregiver'
  bool monitoringActive = true;
  bool commReady = true;
  bool degraded = false; // Maira offline
  PatientProfile patient = PatientProfile(id: 'patient-1');
  final CommunicationStateMachine dialogue = CommunicationStateMachine();
  String statusLine = 'Monitoring active · Communication ready';

  void setRole(String r) {
    role = r;
    notifyListeners();
  }

  void setPresence(AshaPresence p) {
    presence = p;
    notifyListeners();
  }

  void setDegraded(bool v) {
    degraded = v;
    statusLine = v
        ? 'Asha intelligence limited · Essential communication remains available.'
        : 'Monitoring active · Communication ready';
    notifyListeners();
  }

  void routeCommunication() {
    patient.capability.autoRoute();
    notifyListeners();
  }
}
