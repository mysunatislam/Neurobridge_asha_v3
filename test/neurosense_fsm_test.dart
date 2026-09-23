import 'package:flutter_test/flutter_test.dart';
import 'package:neurobridge_asha/features/neurosense/face_models.dart';

FaceFrame open(int t) => FaceFrame(timestampMs: t, earLeft: 0.27, earRight: 0.27, faceQuality: 0.95);
FaceFrame closed(int t) => FaceFrame(timestampMs: t, earLeft: 0.08, earRight: 0.08,
    blendLeft: 0.9, blendRight: 0.9, faceQuality: 0.95);

void main() {
  group('BlinkDetector OPEN→CLOSED→OPEN', () {
    test('single deliberate blink completes once', () {
      final d = BlinkDetector(FaceCalibrationProfile());
      int t = 0;
      expect(d.update(open(t)), isEmpty);
      t += 50; expect(d.update(open(t)), isEmpty);
      t += 50; expect(d.update(closed(t)), isEmpty); // CLOSING
      t += 60; expect(d.update(closed(t)), isEmpty); // CLOSED
      t += 320; // held then reopen → OPENING
      expect(d.update(open(t)), isEmpty);
      t += 40; // stable reopen → COMPLETED
      final ev = d.update(open(t));
      expect(ev.length, 1);
      expect(ev.first.type, 'BLINK_COMPLETED');
      expect(ev.first.deliberate, isTrue);
    });

    test('held closure never becomes a stream of counts', () {
      final d = BlinkDetector(FaceCalibrationProfile());
      int t = 0;
      d.update(open(t));
      t += 50; d.update(closed(t));
      t += 60; d.update(closed(t));
      t += 320;
      expect(d.update(open(t)), isEmpty); // OPENING
      t += 40;
      expect(d.update(open(t)).length, 1); // single completion
      // Still open: no further events
      t += 100; expect(d.update(open(t)), isEmpty);
      t += 100; expect(d.update(open(t)), isEmpty);
    });

    test('three frames below threshold without reopen is not 3 blinks', () {
      final d = BlinkDetector(FaceCalibrationProfile());
      int t = 0;
      d.update(open(t));
      t += 50; d.update(closed(t));
      t += 40; d.update(closed(t)); // still closed, no OPEN yet
      t += 40;
      // One reopen yields at most one blink (needs two stable opens)
      expect(d.update(open(t + 400)), isEmpty); // OPENING only
      final ev = d.update(open(t + 440));
      expect(ev.length, lessThanOrEqualTo(1));
    });

    test('tracking loss invalidates cycle (caller resets)', () {
      final d = BlinkDetector(FaceCalibrationProfile());
      d.update(open(0));
      d.update(closed(50));
      d.reset();
      expect(d.state, 'UNARMED');
    });
  });

  group('HeadTurn excursion + return', () {
    test('LEFT RETURN completes only after stable return', () {
      final c = FaceCalibrationProfile();
      final h = HeadTurnDetector(c);
      int t = 0;
      // center to arm
      for (int i = 0; i < 6; i++) { t += 50; h.update(0, t, 0.9); }
      expect(h.state, 'CENTER');
      t += 50; h.update(-16, t, 0.9);
      t += 150; h.update(-17, t, 0.9); // CONFIRMED
      t += 50;
      // holding left produces no completion
      expect(h.update(-17, t, 0.9), isEmpty);
      // return to center
      t += 50; h.update(0, t, 0.9);
      t += 160;
      final ev = h.update(0, t, 0.9);
      expect(ev.length, 1);
      expect(ev.first.type, 'LEFT_TURN_COMPLETED');
    });

    test('3 left-returns → food via command engine', () {
      final eng = NeuroSenseCommandEngine();
      int t = 1000;
      final evs = <FaceGestureEvent>[];
      for (int i = 0; i < 3; i++) {
        evs.add(FaceGestureEvent('LEFT_TURN_COMPLETED', t, confidence: 0.9));
        t += 1500;
      }
      final out = eng.ingest(evs, t);
      expect(out.length, 1);
      expect(out.first['command'], 'food');
    });

    test('3 blinks → water; cooldown blocks immediate re-fire', () {
      final eng = NeuroSenseCommandEngine();
      int t = 5000;
      final blinks = List.generate(3, (i) => FaceGestureEvent('BLINK_COMPLETED', t + i * 1000, confidence: 0.9, deliberate: true));
      final out1 = eng.ingest(blinks, t + 3000);
      expect(out1.length, 1);
      final out2 = eng.ingest(blinks, t + 3100);
      expect(out2, isEmpty);
    });
  });

  group('Smile hysteresis', () {
    test('SMILE_HELD then COMPLETED, not flicker', () {
      final s = SmileDetector();
      int t = 0;
      expect(s.update(0.5, true, t, 0.9), isEmpty); // STARTING
      t += 150;
      expect(s.update(0.5, true, t, 0.9).first.type, 'SMILE_STARTED');
      t += 500;
      final held = s.update(0.5, true, t, 0.9);
      expect(held.any((e) => e.type == 'SMILE_HELD'), isTrue);
      t += 50;
      s.update(0.05, false, t, 0.9); // RETURNING
      t += 200;
      final done = s.update(0.05, false, t, 0.9);
      expect(done.any((e) => e.type == 'SMILE_COMPLETED'), isTrue);
    });
  });
}
