import 'package:flutter/foundation.dart';
import '../../core/database/local_store.dart';

/// Caregiver preferences + quiet hours + interaction style (§55).
class CaregiverSettings extends ChangeNotifier {
  String interaction = 'Normal'; // Minimal | Normal | Companion
  String talkativeness = 'Short';
  String checkinFrequency = 'Occasional'; // Only when needed | Occasional | Regular
  String humor = 'Gentle';
  bool quietHours = false;
  int quietFromHour = 22;
  int quietToHour = 7;
  String patientLanguage = 'en';
  bool cloudReasoning = true;
  bool shareImages = false;

  bool get inQuietHours {
    if (!quietHours) return false;
    final h = DateTime.now().hour;
    if (quietFromHour <= quietToHour) return h >= quietFromHour && h < quietToHour;
    return h >= quietFromHour || h < quietToHour;
  }

  void update({String? interaction, String? talkativeness, String? humor, String? language}) {
    if (interaction != null) this.interaction = interaction;
    if (talkativeness != null) this.talkativeness = talkativeness;
    if (humor != null) this.humor = humor;
    if (language != null) patientLanguage = language;
    notifyListeners();
  }
}
