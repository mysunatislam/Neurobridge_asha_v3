"""Synthetic verification: 75 BPM + 72 BPM + motion-gating + calibration."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from vitalsense.pipeline import VitalSenseEngine
from vitalsense.calibration import calibrate_from_baseline


def synth_bpm(target_bpm, secs=30, fs=30.0, noise=1.2, motion_at=None):
    eng = VitalSenseEngine(fs=fs)
    f = target_bpm / 60.0
    n = int(secs * fs)
    for i in range(n):
        t = i / fs
        pulse = 8.0 * math.sin(2 * math.pi * f * t) + 2.0 * math.sin(4 * math.pi * f * t)
        g = 128 + pulse + noise * math.sin(2 * math.pi * 0.23 * t + 1)
        r = 150 + 0.4 * pulse
        b = 110 + 0.3 * pulse
        motion = 0.6 if motion_at and motion_at[0] <= t <= motion_at[1] else 0.08
        eng.add_frame(r, g, b, t, roi_stability=0.92, lighting=0.85, motion=motion)
    return eng.reading()


r75 = synth_bpm(75)
print(f"target 75 -> {r75.bpm} BPM conf {r75.confidence}% {r75.status} motion={r75.motion}")
assert abs(r75.bpm - 75) < 3, r75
assert r75.confidence > 60, r75

r72 = synth_bpm(72)
print(f"target 72 -> {r72.bpm} BPM conf {r72.confidence}%")
assert abs(r72.bpm - 72) < 3, r72

prof = calibrate_from_baseline("rahim", [71, 72, 73, 72, 74, 71, 73])
print(f"profile: baseline {prof.baseline_hr} range {prof.normal_low}-{prof.normal_high}")
assert prof.normal_low <= 72 <= prof.normal_high

# High-motion window must gate to 'high'
eng = VitalSenseEngine()
for i in range(30 * 30):
    t = i / 30.0
    eng.add_frame(150, 128 + 8 * math.sin(2 * math.pi * 1.25 * t), 110, t,
                  motion=0.9, roi_stability=0.4, lighting=0.8)
rh = eng.reading()
print(f"high motion -> gate={rh.motion} conf={rh.confidence}")
assert rh.motion == "high" and rh.confidence < 45, rh

print("ALL SYNTHETIC CHECKS PASSED")
