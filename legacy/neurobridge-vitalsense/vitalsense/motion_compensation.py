"""Motion compensation via MediaPipe face pose (rotation + translation).

Head rotation/translation deltas -> motion score 0..1.
  <0.30 low (measure), 0.30-0.70 moderate (measure, lower confidence),
  >0.70 high (gate: hold last value, confidence collapses).

Pure-python; pose supplied as dict so tests need no camera.
"""

from dataclasses import dataclass
import math


@dataclass
class HeadPose:
    pitch: float = 0.0  # deg
    yaw: float = 0.0
    roll: float = 0.0
    tx: float = 0.0  # normalized translation (-1..1)
    ty: float = 0.0
    tz: float = 0.0


def motion_score(prev: HeadPose | dict | None, cur: HeadPose | dict | None) -> float:
    def _v(p, k):
        if p is None:
            return 0.0
        v = p[k] if isinstance(p, dict) else getattr(p, k)
        return float(v)
    if prev is None or cur is None:
        return 0.0
    drot = sum(abs(_v(cur, k) - _v(prev, k)) for k in ("pitch", "yaw", "roll"))
    dtra = sum(abs(_v(cur, k) - _v(prev, k)) for k in ("tx", "ty", "tz"))
    # 2 deg rotation ~ 0.1; 0.05 translation ~ 0.25
    score = drot / 20.0 + dtra / 0.2
    return max(0.0, min(1.0, score))


def motion_gate(score: float) -> str:
    if score < 0.30:
        return "low"
    if score <= 0.70:
        return "moderate"
    return "high"


def wheelchair_vibration_penalty(accel_rms: float) -> float:
    """0..1 penalty from IMU RMS (g). >0.15g starts penalizing."""
    return max(0.0, min(1.0, (accel_rms - 0.15) / 0.35))


def compensate(signal_mean: float, score: float) -> tuple:
    """Return (corrected_mean, confidence_multiplier)."""
    gate = motion_gate(score)
    if gate == "low":
        return signal_mean, 1.0
    if gate == "moderate":
        return signal_mean, 0.7
    return signal_mean, 0.25
