import 'dart:math' as math;

/// Port of neuroface-sense/src/engine.js temporal FSMs + calibration build.
/// Frame-by-frame thresholds are NEVER used alone: blink = OPEN→CLOSED→OPEN
/// with hysteresis + refractory; head = excursion + stable return.

class FaceCalibrationProfile {
  double neutralEarLeft, neutralEarRight;
  double blinkClosedRatio, blinkOpenRatio;
  double closedSmileThresholdLeft, closedSmileThresholdRight;
  double maxSmileLeft, maxSmileRight;
  double neutralSmileLeft, neutralSmileRight;
  double leftTurnEnter, leftTurnExit, rightTurnEnter, rightTurnExit, centerYawTol;
  double nodRange, centerPitchTol;
  int nodDirection; // 1 | -1
  bool calibrated;
  FaceCalibrationProfile({
    this.neutralEarLeft = 0.27, this.neutralEarRight = 0.27,
    this.blinkClosedRatio = 0.60, this.blinkOpenRatio = 0.80,
    this.closedSmileThresholdLeft = 0.22, this.closedSmileThresholdRight = 0.22,
    this.maxSmileLeft = 0.7, this.maxSmileRight = 0.7,
    this.neutralSmileLeft = 0.02, this.neutralSmileRight = 0.02,
    this.leftTurnEnter = 13, this.leftTurnExit = 7,
    this.rightTurnEnter = 13, this.rightTurnExit = 7,
    this.centerYawTol = 5, this.nodRange = 12, this.centerPitchTol = 4,
    this.nodDirection = 1, this.calibrated = false,
  });

  Map<String, dynamic> toJson() => {
        'neutralEarLeft': neutralEarLeft, 'neutralEarRight': neutralEarRight,
        'blinkClosedRatio': blinkClosedRatio, 'blinkOpenRatio': blinkOpenRatio,
        'closedSmileL': closedSmileThresholdLeft, 'closedSmileR': closedSmileThresholdRight,
        'leftEnter': leftTurnEnter, 'leftExit': leftTurnExit,
        'rightEnter': rightTurnEnter, 'rightExit': rightTurnExit,
        'nodRange': nodRange, 'calibrated': calibrated,
      };
}

class FaceFrame {
  final int timestampMs;
  final double earLeft, earRight, blendLeft, blendRight;
  final double smileLeft, smileRight, jawOpen;
  final double yaw, pitch;
  final double faceQuality;
  final bool facing;
  FaceFrame({
    required this.timestampMs, required this.earLeft, required this.earRight,
    this.blendLeft = 0, this.blendRight = 0,
    this.smileLeft = 0, this.smileRight = 0, this.jawOpen = 0,
    this.yaw = 0, this.pitch = 0, this.faceQuality = 1, this.facing = true,
  });
}

class FaceGestureEvent {
  final String type; // BLINK_COMPLETED | LEFT_TURN_COMPLETED | ...
  final int timestampMs;
  final double confidence, durationMs, amplitude;
  final bool deliberate;
  FaceGestureEvent(this.type, this.timestampMs,
      {this.confidence = 0.8, this.durationMs = 300, this.amplitude = 0.6, this.deliberate = true});
  Map<String, dynamic> toJson() => {'type': type, 'confidence': confidence, 'durationMs': durationMs};
}

/// Blink OPEN → CLOSING → CLOSED → OPENING → OPEN (engine.js BlinkFSM).
class BlinkDetector {
  String state = 'UNARMED';
  int _start = 0, _opening = 0, _openAt = 0, _cooldown = -100000;
  double _peak = 0, _amp = 0, _minQ = 1;
  bool _facing = true;
  final FaceCalibrationProfile cal;
  double refLeft, refRight;
  BlinkDetector(this.cal)
      : refLeft = cal.neutralEarLeft,
        refRight = cal.neutralEarRight;

  List<FaceGestureEvent> update(FaceFrame f) {
    const minMs = 65, maxMs = 1400, confirmMs = 30, reopenMs = 25, refractoryMs = 150;
    if (!cal.calibrated && (state == 'UNARMED' || state == 'OPEN') && f.blendLeft < 0.2 && f.blendRight < 0.2) {
      refLeft = math.max(refLeft, f.earLeft);
      refRight = math.max(refRight, f.earRight);
    }
    final leftRatio = f.earLeft / refLeft;
    final rightRatio = f.earRight / refRight;
    final ratio = (leftRatio + rightRatio) / 2;
    final closure = ((1 - ratio) / math.max(0.15, 1 - cal.blinkClosedRatio)).clamp(0.0, 1.0);
    final blend = (f.blendLeft + f.blendRight) / 2;
    final conf = (0.4 * closure + 0.4 * blend + 0.2 * 0.5) * f.faceQuality;
    final shallow = ratio < 0.93 && ratio > 0.72;
    final closed = (ratio < cal.blinkClosedRatio && blend > 0.30) || shallow;
    final open = ratio > cal.blinkOpenRatio && blend < 0.48;
    final t = f.timestampMs;
    if (state == 'UNARMED') {
      if (open) { state = 'OPEN'; _openAt = t; }
      return [];
    }
    if (state == 'OPEN') {
      if (closed && t >= _cooldown && t - _openAt >= reopenMs) {
        _start = t; _peak = conf; _amp = (1 - ratio).clamp(0.0, 1.0);
        _minQ = f.faceQuality; _facing = f.facing;
        state = 'CLOSING';
      }
      return [];
    }
    _peak = math.max(_peak, conf);
    _amp = math.max(_amp, (1 - ratio).clamp(0.0, 1.0));
    _minQ = math.min(_minQ, f.faceQuality);
    _facing = _facing && f.facing;
    if (t - _start > maxMs) { state = 'UNARMED'; return []; }
    if (state == 'CLOSING') {
      if (open) {
        state = 'OPEN';
        _openAt = t;
      } else if (closed && t - _start >= confirmMs) {
        state = 'CLOSED';
      }
    } else if (state == 'CLOSED' && open) {
      _opening = t;
      state = 'OPENING';
    } else if (state == 'OPENING') {
      if (closed) {
        state = 'CLOSED';
      } else if (open && t - _opening >= reopenMs) {
        final duration = (_opening - _start).toDouble();
        state = 'OPEN'; _openAt = t; _cooldown = t + refractoryMs;
        final confidence = (0.8 * _peak + 0.2 * _minQ).clamp(0.0, 1.0);
        if (duration < minMs || confidence < 0.58) return [];
        final deliberate = duration >= 260 && duration <= maxMs;
        return [FaceGestureEvent('BLINK_COMPLETED', t,
            confidence: confidence, durationMs: duration, amplitude: _amp, deliberate: deliberate)];
      }
    }
    return [];
  }

  void reset() => state = 'UNARMED';
}

/// Head excursion + stable return (engine.js ExcursionFSM).
class HeadTurnDetector {
  String state = 'UNARMED';
  String? side;
  int _start = 0, _centerAt = 0, _cooldown = -100000;
  double _peak = 0, _conf = 1;
  final FaceCalibrationProfile cal;
  final bool isNod; // false = yaw turns, true = pitch nod
  HeadTurnDetector(this.cal, {this.isNod = false});

  List<FaceGestureEvent> update(double value, int t, double quality) {
    const holdMs = 130, centerMs = 140, maxMs = 7000;
    final neg = isNod ? cal.nodRange : cal.leftTurnEnter;
    final pos = isNod ? cal.nodRange : cal.rightTurnEnter;
    final exitNeg = isNod ? cal.centerPitchTol * 1.5 : cal.leftTurnExit;
    final exitPos = isNod ? cal.centerPitchTol * 1.5 : cal.rightTurnExit;
    final center = isNod ? cal.centerPitchTol : cal.centerYawTol;
    final centered = value.abs() <= center;
    if (state == 'UNARMED') {
      if (centered) {
        if (_centerAt == 0) _centerAt = t;
        if (t - _centerAt >= centerMs) state = 'CENTER';
      } else {
        _centerAt = 0;
      }
      return [];
    }
    final s = value <= -neg ? 'LEFT' : (value >= pos ? 'RIGHT' : null);
    if (state == 'CENTER') {
      if (s != null && t >= _cooldown) {
        side = isNod ? 'NOD' : s;
        _start = t; _peak = value.abs(); _conf = quality;
        state = 'MOVING';
      }
      return [];
    }
    _peak = math.max(_peak, value.abs());
    _conf = math.min(_conf, quality);
    if (t - _start > maxMs) { state = 'UNARMED'; _centerAt = 0; return []; }
    if (state == 'MOVING') {
      final beyond = side == 'LEFT' ? value <= -neg : (side == 'RIGHT' ? value >= pos : value.abs() >= neg);
      if (!beyond) { state = 'UNARMED'; _centerAt = 0; return []; }
      if (t - _start >= holdMs) state = 'CONFIRMED';
    } else if (state == 'CONFIRMED') {
      final exited = side == 'LEFT' ? value > -exitNeg : (side == 'RIGHT' ? value < exitPos : value.abs() < (isNod ? cal.centerPitchTol * 1.5 : 7));
      if (exited) { state = 'RETURNING'; _centerAt = centered ? t : 0; }
    } else if (state == 'RETURNING') {
      if (!centered) { _centerAt = 0; return []; }
      if (_centerAt == 0) _centerAt = t;
      if (t - _centerAt >= centerMs) {
        final type = isNod ? 'NOD_COMPLETED' : '${side}_TURN_COMPLETED';
        state = 'CENTER'; _cooldown = t + 200; _centerAt = 0;
        return [FaceGestureEvent(type, t, confidence: _conf, durationMs: (t - _start).toDouble(), amplitude: _peak)];
      }
    }
    return [];
  }

  void reset() { state = 'UNARMED'; _centerAt = 0; }
}

/// Smile with enter/exit hysteresis + hold (engine.js SmileFSM).
class SmileDetector {
  String state = 'NEUTRAL';
  int _start = 0, _since = 0;
  bool hasHeld = false;
  List<FaceGestureEvent> update(double intensity, bool evidence, int t, double quality) {
    const enter = 0.34, exit = 0.20, startMs = 140, heldMs = 450, returnMs = 150;
    final active = evidence && intensity >= enter;
    final low = intensity < exit;
    if (state == 'NEUTRAL' && active) {
      _start = t; hasHeld = false; state = 'STARTING';
    } else if (state == 'STARTING') {
      if (!active) {
        state = 'NEUTRAL';
      } else if (t - _start >= startMs) {
        state = 'SMILING';
        return [FaceGestureEvent('SMILE_STARTED', t, confidence: quality)];
      }
    } else if (state == 'SMILING' || state == 'HELD') {
      if (low) { state = 'RETURNING'; _since = t; }
      else if (state == 'SMILING' && t - _start >= heldMs) {
        hasHeld = true; state = 'HELD';
        return [FaceGestureEvent('SMILE_HELD', t, confidence: quality)];
      }
    } else if (state == 'RETURNING') {
      if (!low) {
        state = hasHeld ? 'HELD' : 'SMILING';
      } else if (t - _since >= returnMs) {
        state = 'NEUTRAL';
        return [FaceGestureEvent('SMILE_COMPLETED', t, confidence: quality, durationMs: (t - _start).toDouble())];
      }
    }
    return [];
  }

  void reset() => state = 'NEUTRAL';
}

/// Command sequences: 3 blinks → water, 3 left → food, 3 right → toilet,
/// nod+smile within 1s → okay. Each with cooldown (README mapping).
class NeuroSenseCommandEngine {
  final List<FaceGestureEvent> _blinks = [];
  final List<FaceGestureEvent> _left = [];
  final List<FaceGestureEvent> _right = [];
  final Map<String, int> _cooldowns = {};
  static const blinkWindow = 5000, turnWindow = 8000, cooldown = 3000;

  List<Map<String, dynamic>> ingest(List<FaceGestureEvent> events, int t) {
    final out = <Map<String, dynamic>>[];
    _blinks.removeWhere((e) => t - e.timestampMs > blinkWindow);
    _left.removeWhere((e) => t - e.timestampMs > turnWindow);
    _right.removeWhere((e) => t - e.timestampMs > turnWindow);
    bool cooled(String k) => t >= (_cooldowns[k] ?? 0);
    for (final e in events) {
      if (e.confidence < 0.58) continue;
      if (e.type == 'BLINK_COMPLETED' && e.deliberate) {
        _blinks.add(e);
        if (_blinks.length >= 3 && cooled('water')) {
          _cooldowns['water'] = t + cooldown;
          out.add({'command': 'water', 'phrase': 'I need water.', 'events': _blinks.take(3).toList()});
          _blinks.clear();
        }
      } else if (e.type == 'LEFT_TURN_COMPLETED') {
        _left.add(e);
        if (_left.length >= 3 && cooled('food')) {
          _cooldowns['food'] = t + cooldown;
          out.add({'command': 'food', 'phrase': 'I need food.', 'events': _left.take(3).toList()});
          _left.clear();
        }
      } else if (e.type == 'RIGHT_TURN_COMPLETED') {
        _right.add(e);
        if (_right.length >= 3 && cooled('toilet')) {
          _cooldowns['toilet'] = t + cooldown;
          out.add({'command': 'toilet', 'phrase': 'I need to go to toilet.', 'events': _right.take(3).toList()});
          _right.clear();
        }
      }
    }
    return out;
  }
}
