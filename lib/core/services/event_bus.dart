import 'dart:async';

/// Typed application event bus. Modules never touch each other's UI;
/// they emit events, Asha Core subscribes.
enum AshaEventType {
  patientAwake,
  probableSleep,
  resting,
  gestureCandidate,
  gestureConfirmed,
  faceGestureConfirmed,
  vitalChanged,
  possibleDiscomfort,
  communicationUnavailable,
  patientRequest,
  caregiverCallRequested,
  caregiverCallStarted,
  caregiverCallFailed,
  emergencyRequested,
  cameraQualityLow,
  calibrationNeeded,
  modeChanged,
  mairaStatusChanged,
}

class AshaEvent {
  final AshaEventType type;
  final String source;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  AshaEvent(this.type, {this.source = 'system', Map<String, dynamic>? payload})
      : payload = payload ?? {},
        timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'event': type.name,
        ...payload,
      };
}

class AshaEventBus {
  final _controller = StreamController<AshaEvent>.broadcast();
  final List<AshaEvent> _history = [];

  Stream<AshaEvent> get stream => _controller.stream;
  List<AshaEvent> get history => List.unmodifiable(_history);

  void emit(AshaEvent event) {
    _history.add(event);
    if (_history.length > 500) _history.removeAt(0);
    _controller.add(event);
  }

  Stream<AshaEvent> on(AshaEventType type) =>
      _controller.stream.where((e) => e.type == type);

  void dispose() => _controller.close();
}
