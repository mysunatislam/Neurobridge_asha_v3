import 'package:flutter/foundation.dart';
import '../../core/services/event_bus.dart';
import '../../core/database/local_store.dart';

/// FingerSpeak port: personalized gesture vocabulary, guided calibration,
/// Rest state, intentional dwell/hold, confidence threshold, return-to-Rest
/// before retrigger, OOD rejection, missed/false tracking, latency.
/// Feature math (rotation-normalized + motion) lives in native/ML layer;
/// this service owns the temporal decision policy so Asha Core is stable
/// when a BLE wearable later replaces the camera.
class FingerGestureTemplate {
  final String id; // e.g. 'water'
  final String phrase; // 'I need water.'
  final List<double> centroid;
  final double spread;
  int samples;
  FingerGestureTemplate(this.id, this.phrase, this.centroid, this.spread, {this.samples = 5});
}

class FingerSpeakResult {
  final String gesture;
  final double confidence;
  final bool intentConfirmed;
  final String phrase;
  final DateTime timestamp;
  FingerSpeakResult(this.gesture, this.confidence, this.intentConfirmed, this.phrase)
      : timestamp = DateTime.now();
  Map<String, dynamic> toJson() => {
        'gesture': gesture, 'confidence': confidence,
        'intent_confirmed': intentConfirmed,
        'timestamp': timestamp.toIso8601String(),
        'communication_phrase': phrase,
      };
}

class FingerSpeakService extends ChangeNotifier {
  final AshaEventBus bus;
  final EventLogService logs;
  final Map<String, FingerGestureTemplate> vocabulary = {};
  final Map<String, int> falseActivations = {};
  final Map<String, int> misses = {};
  final List<double> _latenciesMs = [];

  String _dwellCandidate = '';
  DateTime? _dwellSince;
  String _lastFired = '';
  DateTime? lastRestAt;
  bool _inRest = true;
  static const dwellMs = 600;
  static const double confidenceThreshold = 0.72;
  static const double oodMultiplier = 2.2;

  FingerSpeakService({required this.bus, required this.logs}) {
    _installDefaults();
  }

  void _installDefaults() {
    const defaults = {
      'rest': 'Rest.',
      'yes': 'Yes.', 'no': 'No.', 'water': 'I need water.',
      'pain': 'I am in pain.', 'food': 'I need food.',
      'toilet': 'I need to go to toilet.',
      'call_caregiver': 'Please call my caregiver.',
      'reposition': 'Please reposition me.',
      'hot': 'I feel too hot.', 'cold': 'I feel too cold.',
      'emergency': 'Emergency. Please help me now.',
      'stop': 'Stop.', 'thanks': 'Thank you.',
    };
    for (final e in defaults.entries) {
      vocabulary.putIfAbsent(e.key, () => FingerGestureTemplate(e.key, e.value, List.filled(8, 0.5), 0.35));
    }
  }

  void upsertTemplate(FingerGestureTemplate t) {
    vocabulary[t.id] = t;
    notifyListeners();
  }

  void setPhrase(String id, String phrase) {
    final t = vocabulary[id];
    if (t != null) {
      vocabulary[id] = FingerGestureTemplate(id, phrase, t.centroid, t.spread, samples: t.samples);
      notifyListeners();
    }
  }

  /// OOD check: distance to PREDICTED class spread (mirrors inDistribution).
  bool _inDistribution(List<double> summary, FingerGestureTemplate proto) {
    double d2 = 0;
    for (int i = 0; i < summary.length && i < proto.centroid.length; i++) {
      final d = summary[i] - proto.centroid[i];
      d2 += d * d;
    }
    final dist = _sqrt(d2);
    return dist <= proto.spread * oodMultiplier;
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double x = v / 2;
    for (int i = 0; i < 16; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  /// Live classification hook. [summary] = temporal feature summary,
  /// [predictedId] = model argmax, [modelConfidence] = softmax/GRU score.
  /// Returns confirmed result only after dwell + Rest-return gating.
  FingerSpeakResult? classify({
    required String predictedId,
    required List<double> summary,
    required double modelConfidence,
    required bool handVisible,
  }) {
    if (!handVisible) {
      _dwellCandidate = '';
      return null; // hand disappears: invalidate dwell
    }
    final proto = vocabulary[predictedId];
    if (proto == null) {
      _logMiss(predictedId);
      return null;
    }
    if (modelConfidence < confidenceThreshold) return null;
    if (predictedId == 'rest') {
      // Rest is the safe control state: always accept to re-arm.
      _inRest = true;
      lastRestAt = DateTime.now();
      _dwellCandidate = '';
      return null;
    }
    if (!_inDistribution(summary, proto)) {
      _logMiss(predictedId);
      return null; // unknown movement rejected, never spoken
    }
    // Require return-to-Rest before retrigger of same gesture.
    if (predictedId == _lastFired && !_inRest) return null;
    final now = DateTime.now();
    if (_dwellCandidate != predictedId) {
      _dwellCandidate = predictedId;
      _dwellSince = now;
      return null;
    }
    final dwell = now.difference(_dwellSince!).inMilliseconds;
    if (dwell >= dwellMs) {
      _lastFired = predictedId;
      _inRest = false;
      _dwellCandidate = '';
      _latenciesMs.add(dwell.toDouble());
      final res = FingerSpeakResult(predictedId, modelConfidence, true, proto.phrase);
      logs.log({'source': 'fingerspeak', 'event': predictedId, 'confidence': modelConfidence, 'action': proto.phrase});
      bus.emit(AshaEvent(AshaEventType.gestureConfirmed, source: 'fingerspeak', payload: res.toJson()));
      notifyListeners();
      return res;
    }
    return null;
  }

  void _logMiss(String id) {
    misses[id] = (misses[id] ?? 0) + 1;
  }

  void markFalseActivation(String id) {
    falseActivations[id] = (falseActivations[id] ?? 0) + 1;
    notifyListeners();
  }

  double get medianLatencyMs {
    if (_latenciesMs.isEmpty) return 0;
    final s = List.of(_latenciesMs)..sort();
    return s[s.length ~/ 2];
  }

  Map<String, dynamic> qualityStats() => {
        'vocabulary': vocabulary.keys.toList(),
        'falseActivations': Map.of(falseActivations),
        'misses': Map.of(misses),
        'medianLatencyMs': medianLatencyMs,
      };
}
