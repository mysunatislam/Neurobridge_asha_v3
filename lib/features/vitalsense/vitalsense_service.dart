import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../core/database/models.dart';
import '../../core/services/event_bus.dart';
import '../../core/database/local_store.dart';

/// VitalSense port (vitalsense/pipeline.py + confidence.py + asha_integration.py).
/// rPPG DSP itself runs natively; this service owns confidence gating,
/// motion gating, baseline calibration, and the transparent Asha rule engine.
class VitalSnapshot {
  final double bpm, resp;
  final double confidence; // 0..100
  final String status; // Reliable | Uncertain | Unreliable
  final String quality; // Excellent | Good | Fair | Poor
  final String motion; // low | moderate | high
  final String stress; // Normal | Mild | Elevated | Unknown
  final String? alert;
  VitalSnapshot({
    required this.bpm, required this.resp, required this.confidence,
    required this.status, required this.quality, required this.motion,
    required this.stress, this.alert,
  });
}

class VitalSenseService extends ChangeNotifier {
  final AshaEventBus bus;
  final EventLogService logs;
  VitalBaseline baseline = VitalBaseline(restingHr: 72, normalLow: 65, normalHigh: 85);
  VitalSnapshot last = VitalSnapshot(
      bpm: 0, resp: 0, confidence: 0, status: 'Unreliable',
      quality: 'Poor', motion: 'low', stress: 'Unknown');
  List<double> waveform = [];
  double? _heldBpm;
  DateTime? _hotSince;
  static const persistSecs = 10;

  VitalSenseService({required this.bus, required this.logs});

  void setBaseline(VitalBaseline b) {
    baseline = b;
    notifyListeners();
  }

  /// Confidence model weights (confidence.py): motion + peak clarity dominate.
  static Map<String, dynamic> confidenceScore({
    required double roiStability,
    required double lighting,
    required double motionStillness,
    required double sqi,
    required double peakClarity,
  }) {
    double c(double v) => v.clamp(0.0, 1.0);
    final vals = {
      'roi_stability': c(roiStability),
      'lighting': c(lighting),
      'motion_stillness': c(motionStillness),
      'sqi': c(sqi),
      'peak_clarity': c(math.min(1.0, peakClarity * 4.0)),
    };
    double score = vals['roi_stability']! * 0.20 +
        vals['lighting']! * 0.15 +
        vals['motion_stillness']! * 0.25 +
        vals['sqi']! * 0.15 +
        vals['peak_clarity']! * 0.25;
    score *= 100;
    if (vals['lighting']! < 0.2) score = math.min(score, 30);
    if (vals['motion_stillness']! < 0.2) score = math.min(score, 35);
    if (vals['roi_stability']! < 0.15) score = math.min(score, 25);
    final status = score >= 75 ? 'Reliable' : (score >= 45 ? 'Uncertain' : 'Unreliable');
    return {'confidence': (score * 10).round() / 10, 'status': status, 'breakdown': vals};
  }

  static String motionGate(double motion) {
    if (motion > 0.7) return 'high';
    if (motion > 0.35) return 'moderate';
    return 'low';
  }

  /// Ingest one DSP reading (native layer provides bpm/resp/sqi/clarity).
  VitalSnapshot ingest({
    required double bpm,
    required double resp,
    required double roiStability,
    required double lighting,
    required double motion,
    required double sqi,
    required double peakClarity,
    double facialTension = 0,
    List<double>? wave,
  }) {
    final conf = confidenceScore(
        roiStability: roiStability, lighting: lighting,
        motionStillness: 1 - motion.clamp(0.0, 1.0), sqi: sqi, peakClarity: peakClarity);
    final gate = motionGate(motion);
    double shown = bpm;
    if (gate == 'high') shown = _heldBpm ?? 0; // hold last, collapse confidence path
    final alert = _ashaUpdate(shown, (conf['confidence'] as double), facialTension);
    final c = conf['confidence'] as double;
    final quality = c >= 85 ? 'Excellent' : (c >= 70 ? 'Good' : (c >= 45 ? 'Fair' : 'Poor'));
    last = VitalSnapshot(
      bpm: (shown * 10).round() / 10,
      resp: (resp * 10).round() / 10,
      confidence: c,
      status: conf['status'] as String,
      quality: quality,
      motion: gate,
      stress: _stress(shown),
      alert: alert,
    );
    if (wave != null) waveform = wave;
    if (gate != 'high' && shown > 0) _heldBpm = shown;
    bus.emit(AshaEvent(AshaEventType.vitalChanged, source: 'vitalsense', payload: {
      'hr': last.bpm, 'resp': last.resp, 'confidence': last.confidence, 'status': last.status,
    }));
    if (alert != null) {
      bus.emit(AshaEvent(AshaEventType.possibleDiscomfort, source: 'vitalsense',
          payload: {'hr': last.bpm, 'baseline_hr': baseline.restingHr, 'confidence': last.confidence / 100}));
    }
    logs.log({'source': 'vitalsense', 'event': 'reading', 'confidence': c, 'action': last.status});
    notifyListeners();
    return last;
  }

  String? _ashaUpdate(double bpm, double confidence, double tension) {
    final now = DateTime.now();
    if (confidence < 45 || bpm <= 0) {
      _hotSince = null;
      return null;
    }
    final hot = bpm > baseline.normalHigh + 7.5 || bpm > baseline.restingHr + 15;
    if (hot || (tension > 0.6)) {
      _hotSince ??= now;
      if (now.difference(_hotSince!).inSeconds >= persistSecs) {
        _hotSince = now; // re-arm while persisting
        final level = bpm > baseline.normalHigh + 25 ? 'urgent' : 'check';
        return 'Asha detected possible patient discomfort (HR ${bpm.toStringAsFixed(0)} vs baseline ${baseline.restingHr.toStringAsFixed(0)}). [$level] Please check patient.';
      }
    } else {
      _hotSince = null;
    }
    return null;
  }

  String _stress(double bpm) {
    if (bpm <= 0) return 'Unknown';
    if (bpm < baseline.normalLow - 10 || bpm > baseline.normalHigh + 15) return 'Elevated';
    if (bpm > baseline.normalHigh) return 'Mild';
    return 'Normal';
  }

  /// Reliability label for UI: never show a confidently-wrong number.
  String displayHr() {
    if (last.status == 'Unreliable') return '—';
    return last.bpm.toStringAsFixed(0);
  }
}
