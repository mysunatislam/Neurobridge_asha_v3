"""VitalSenseEngine — orchestrator: frames in, readings out.

Usage:
    eng = VitalSenseEngine(fs=30.0)
    for frame in camera: eng.add_frame(r, g, b, t, ...)
    reading = eng.reading()  # VitalReading with bpm/confidence/status/alert
"""

import time
from dataclasses import dataclass

from .signal_extractor import VitalBuffer
from .signal_processing import estimate_heart_rate, estimate_respiration
from .confidence import ConfidenceInputs, confidence_score
from .motion_compensation import motion_gate
from .asha_integration import AshaReasoning, AshaAlert


@dataclass
class VitalReading:
    bpm: float
    resp_per_min: float
    confidence: float
    status: str
    signal_quality: str
    motion: str
    stress: str
    alert: AshaAlert | None
    age_s: float


class VitalSenseEngine:
    def __init__(self, fs: float = 30.0, window_s: float = 30.0,
                 baseline_hr: float = 72.0, normal_low: float = 65.0,
                 normal_high: float = 85.0, patient_id: str = "demo"):
        self.buf = VitalBuffer(fs=fs, window_s=window_s)
        self.fs = fs
        self.patient_id = patient_id
        self.reason = AshaReasoning(baseline_hr, normal_low, normal_high)
        self._last: VitalReading | None = None
        self._last_t: float = 0.0

    def set_baseline(self, baseline_hr: float, low: float, high: float):
        self.reason.baseline_hr = baseline_hr
        self.reason.normal_low = low
        self.reason.normal_high = high

    def add_frame(self, r: float, g: float, b: float, t: float | None = None,
                  roi_stability: float = 0.9, lighting: float = 0.8,
                  motion: float = 0.1):
        self.buf.add(r, g, b, time.time() if t is None else t,
                     roi_stability, lighting, motion)

    def reading(self, facial_tension: float = 0.0,
                movement_drop: bool = False) -> VitalReading:
        if not self.buf.ready(10.0):
            return VitalReading(0, 0, 0, "Calibrating…", "—",
                                "low", "Unknown", None, 0)
        w = self.buf.window()
        q = self.buf.mean_quality(10.0)
        hr = estimate_heart_rate(w["g"], self.fs, w["r"], w["b"])
        resp = estimate_respiration(w["g"], self.fs)
        still = 1.0 - max(0.0, min(1.0, q["motion"]))
        conf = confidence_score(ConfidenceInputs(
            roi_stability=q["roi_stability"], lighting=q["lighting"],
            motion_stillness=still, sqi=hr.get("sqi", 0),
            peak_clarity=hr.get("peak_clarity", 0)))
        gate = motion_gate(q["motion"])
        bpm = hr["bpm"] if hr["reliable"] else (self._last.bpm if self._last else 0.0)
        if gate == "high":  # hold last value, collapse confidence display path
            bpm = self._last.bpm if self._last else 0.0
        alert = self.reason.update(bpm, conf["confidence"], facial_tension, movement_drop)
        quality = ("Excellent" if conf["confidence"] >= 85 else
                   "Good" if conf["confidence"] >= 70 else
                   "Fair" if conf["confidence"] >= 45 else "Poor")
        rd = VitalReading(
            bpm=round(float(bpm), 1),
            resp_per_min=round(float(resp.get("breaths_per_min", 0)), 1),
            confidence=conf["confidence"], status=conf["status"],
            signal_quality=quality, motion=gate,
            stress=self.reason.stress_indicator(bpm),
            alert=alert, age_s=0.0)
        self._last, self._last_t = rd, time.time()
        return rd

    def waveform(self, secs: float = 6.0):
        """Recent filtered pulse waveform points for ECG-style rendering."""
        import numpy as np
        from .signal_processing import bandpass, detrend, normalize_signal
        w = self.buf.window(secs)
        g = np.asarray(w["g"], dtype=float)
        if g.size < 10:
            return []
        sig = normalize_signal(detrend(g))
        filt = bandpass(sig, self.fs, 0.7, 4.0)
        return [round(float(v), 4) for v in filt]
