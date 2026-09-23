import 'package:flutter_test/flutter_test.dart';
import 'package:neurobridge_asha/features/fingerspeak/fingerspeak_service.dart';
import 'package:neurobridge_asha/core/services/event_bus.dart';
import 'package:neurobridge_asha/core/database/local_store.dart';

void main() {
  FingerSpeakService svc() => FingerSpeakService(bus: AshaEventBus(), logs: EventLogService());

  group('FingerSpeak dwell + Rest + OOD', () {
    test('needs dwell: first sighting returns null', () {
      final s = svc();
      final r = s.classify(predictedId: 'water', summary: List.filled(8, 0.5), modelConfidence: 0.91, handVisible: true);
      expect(r, isNull);
    });
    test('repeated same gesture without Rest does not retrigger', () async {
      final s = svc();
      // First dwell cycle
      s.classify(predictedId: 'water', summary: List.filled(8, 0.5), modelConfidence: 0.95, handVisible: true);
      await Future.delayed(const Duration(milliseconds: 650));
      final first = s.classify(predictedId: 'water', summary: List.filled(8, 0.5), modelConfidence: 0.95, handVisible: true);
      expect(first, isNotNull);
      // Immediate repeat without Rest → null
      final second = s.classify(predictedId: 'water', summary: List.filled(8, 0.5), modelConfidence: 0.95, handVisible: true);
      expect(second, isNull);
      // Return to Rest re-arms
      s.classify(predictedId: 'rest', summary: List.filled(8, 0.0), modelConfidence: 0.99, handVisible: true);
      s.classify(predictedId: 'water', summary: List.filled(8, 0.5), modelConfidence: 0.95, handVisible: true);
      await Future.delayed(const Duration(milliseconds: 650));
      final third = s.classify(predictedId: 'water', summary: List.filled(8, 0.5), modelConfidence: 0.95, handVisible: true);
      expect(third, isNotNull);
    });
    test('OOD rejected and logged as miss', () {
      final s = svc();
      final r = s.classify(predictedId: 'water', summary: List.filled(8, 9.9), modelConfidence: 0.99, handVisible: true);
      expect(r, isNull);
      expect(s.misses['water'], 1);
    });
    test('low confidence ignored', () {
      final s = svc();
      expect(s.classify(predictedId: 'water', summary: List.filled(8, 0.5), modelConfidence: 0.4, handVisible: true), isNull);
    });
    test('hand disappears invalidates dwell', () {
      final s = svc();
      s.classify(predictedId: 'water', summary: List.filled(8, 0.5), modelConfidence: 0.95, handVisible: true);
      expect(s.classify(predictedId: 'water', summary: List.filled(8, 0.5), modelConfidence: 0.95, handVisible: false), isNull);
    });
  });
}
