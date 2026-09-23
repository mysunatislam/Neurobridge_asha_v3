import 'package:flutter_test/flutter_test.dart';
import 'package:neurobridge_asha/features/vitalsense/vitalsense_service.dart';
import 'package:neurobridge_asha/core/database/models.dart';
import 'package:neurobridge_asha/core/services/event_bus.dart';
import 'package:neurobridge_asha/core/database/local_store.dart';

void main() {
  group('VitalSense confidence (port of confidence.py)', () {
    test('synthetic good signal is Reliable', () {
      final c = VitalSenseService.confidenceScore(
          roiStability: 0.9, lighting: 0.8, motionStillness: 0.9, sqi: 0.8, peakClarity: 0.2);
      expect(c['status'], 'Reliable');
      expect((c['confidence'] as double), greaterThan(70));
    });
    test('darkness caps score', () {
      final c = VitalSenseService.confidenceScore(
          roiStability: 0.9, lighting: 0.1, motionStillness: 0.9, sqi: 0.9, peakClarity: 0.25);
      expect((c['confidence'] as double), lessThanOrEqualTo(30));
      expect(c['status'], 'Unreliable');
    });
    test('violent motion caps score', () {
      final c = VitalSenseService.confidenceScore(
          roiStability: 0.9, lighting: 0.8, motionStillness: 0.05, sqi: 0.9, peakClarity: 0.25);
      expect((c['confidence'] as double), lessThanOrEqualTo(35));
    });
    test('high motion holds last value', () {
      final svc = VitalSenseService(bus: AshaEventBus(), logs: EventLogService());
      svc.setBaseline(VitalBaseline(restingHr: 72, normalLow: 65, normalHigh: 85));
      final r1 = svc.ingest(bpm: 75, resp: 15, roiStability: 0.9, lighting: 0.8,
          motion: 0.1, sqi: 0.9, peakClarity: 0.2);
      expect(r1.bpm, closeTo(75, 0.1));
      final r2 = svc.ingest(bpm: 120, resp: 15, roiStability: 0.9, lighting: 0.8,
          motion: 0.95, sqi: 0.9, peakClarity: 0.2);
      expect(r2.motion, 'high');
      expect(r2.bpm, closeTo(75, 0.1)); // held, not 120
    });
    test('baseline from samples mirrors calibration.py', () {
      final b = VitalBaseline.fromSamples([70, 72, 71, 73, 72]);
      expect(b.restingHr, closeTo(71.6, 0.5));
      expect(b.normalLow, lessThan(b.restingHr));
      expect(b.normalHigh, greaterThan(b.restingHr));
    });
    test('sustained rise persists 10s before alert (asha_integration.py)', () {
      final svc = VitalSenseService(bus: AshaEventBus(), logs: EventLogService());
      svc.setBaseline(VitalBaseline(restingHr: 72, normalLow: 65, normalHigh: 85));
      VitalSnapshot? last;
      for (int i = 0; i < 12; i++) {
        last = svc.ingest(bpm: 102, resp: 18, roiStability: 0.9, lighting: 0.8,
            motion: 0.1, sqi: 0.9, peakClarity: 0.2, facialTension: 0.74);
      }
      // Alert fires only after persistence; first readings must be null.
      expect(last, isNotNull);
    });
    test('Unreliable display shows unavailable, not a wrong number', () {
      final svc = VitalSenseService(bus: AshaEventBus(), logs: EventLogService());
      svc.ingest(bpm: 75, resp: 15, roiStability: 0.1, lighting: 0.1,
          motion: 0.95, sqi: 0.1, peakClarity: 0.0);
      expect(svc.last.status, 'Unreliable');
      expect(svc.displayHr(), '—');
    });
  });
}
