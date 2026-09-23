/// Daily/session summaries for caregiver reports (§62).
/// Experimental measurements are always labelled.
class DailyReport {
  final int successfulComms;
  final Map<String, int> requests;
  final double fingerspeakReliability;
  final int neurosenseFallbacks;
  final int unreliableCameraPeriods;
  final bool emergencyEvents;
  DailyReport({
    required this.successfulComms, required this.requests,
    required this.fingerspeakReliability, required this.neurosenseFallbacks,
    required this.unreliableCameraPeriods, required this.emergencyEvents,
  });

  String render() {
    final sb = StringBuffer()..writeln('Today (experimental measurements)');
    sb.writeln('Successful communication events: $successfulComms');
    sb.writeln('Requests:');
    requests.forEach((k, v) => sb.writeln('  $k  $v'));
    sb.writeln('FingerSpeak ${(fingerspeakReliability * 100).toStringAsFixed(0)}% · NeuroSense backup ×$neurosenseFallbacks');
    sb.writeln(emergencyEvents ? 'Confirmed emergency events: see log' : 'No confirmed emergency events');
    sb.writeln('$unreliableCameraPeriods periods of unreliable camera signal');
    return sb.toString();
  }
}
