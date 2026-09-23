"""Asha AI integration: distress reasoning + caregiver alerts.

Rule engine is deliberately transparent (no black box) so clinicians can
audit why Asha spoke. Thresholds adapt to the patient's calibrated baseline.
"""

from dataclasses import dataclass
import time


@dataclass
class AshaAlert:
    level: str  # info | check | urgent
    message: str
    bpm: float
    ts: float


class AshaReasoning:
    def __init__(self, baseline_hr: float = 72.0, normal_low: float = 65.0,
                 normal_high: float = 85.0, rise_bpm: float = 15.0,
                 persist_s: float = 10.0):
        self.baseline_hr = baseline_hr
        self.normal_low = normal_low
        self.normal_high = normal_high
        self.rise_bpm = rise_bpm
        self.persist_s = persist_s
        self._hot_since: float | None = None

    def update(self, bpm: float, confidence: float, facial_tension: float = 0.0,
               movement_drop: bool = False, now: float | None = None) -> AshaAlert | None:
        """Return an alert when evidence of discomfort persists, else None."""
        now = time.time() if now is None else now
        if confidence < 45 or bpm <= 0:
            self._hot_since = None
            return None
        hot = (bpm > self.normal_high + self.rise_bpm * 0.5) or \
              (bpm > self.baseline_hr + self.rise_bpm)
        tension = facial_tension > 0.6
        if hot or (tension and movement_drop):
            if self._hot_since is None:
                self._hot_since = now
            if now - self._hot_since >= self.persist_s:
                level = "urgent" if bpm > self.normal_high + 25 else "check"
                self._hot_since = now  # re-arm so alerts repeat while persisting
                return AshaAlert(
                    level=level,
                    message=("Asha detected possible patient discomfort "
                             f"(HR {bpm:.0f} BPM vs baseline {self.baseline_hr:.0f}). "
                             "Please check patient."),
                    bpm=bpm, ts=now)
        else:
            self._hot_since = None
        return None

    def comfort_prompt(self, bpm: float, tension: float) -> str:
        if tension > 0.6 or bpm > self.normal_high:
            return ("Are you feeling uncomfortable? "
                    "Would you like me to call your caregiver?")
        return ""

    def stress_indicator(self, bpm: float) -> str:
        if bpm <= 0:
            return "Unknown"
        if bpm < self.normal_low - 10 or bpm > self.normal_high + 15:
            return "Elevated"
        if bpm > self.normal_high:
            return "Mild"
        return "Normal"
