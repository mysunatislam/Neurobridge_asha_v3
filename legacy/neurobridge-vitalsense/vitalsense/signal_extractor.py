"""Rolling-buffer skin signal extraction.

Each camera frame contributes one fused (R,G,B) triple (see roi.fuse_roi_means).
The buffer holds 30-60 s at 30 fps and exposes windowed signals for the
signal-processing stage. Green is primary (hemoglobin absorption peak).
"""

from collections import deque
from dataclasses import dataclass


@dataclass
class FrameSample:
    r: float
    g: float
    b: float
    t: float  # seconds, monotonic
    roi_stability: float = 1.0
    lighting: float = 1.0
    motion: float = 0.0  # 0 = still, 1 = strong motion


class VitalBuffer:
    def __init__(self, fs: float = 30.0, window_s: float = 30.0):
        self.fs = fs
        self.window_s = window_s
        self.maxlen = int(fs * window_s)
        self.samples: deque = deque(maxlen=self.maxlen)

    def add(self, r: float, g: float, b: float, t: float,
            roi_stability: float = 1.0, lighting: float = 1.0,
            motion: float = 0.0):
        self.samples.append(FrameSample(r, g, b, t, roi_stability, lighting, motion))

    def __len__(self):
        return len(self.samples)

    def ready(self, min_s: float = 10.0) -> bool:
        return len(self.samples) >= int(self.fs * min_s)

    def window(self, secs: float | None = None):
        """Return dict of lists: r,g,b,t + quality vectors (newest last)."""
        n = len(self.samples) if secs is None else min(len(self.samples), int(self.fs * secs))
        sel = list(self.samples)[-n:]
        return {
            "r": [s.r for s in sel],
            "g": [s.g for s in sel],
            "b": [s.b for s in sel],
            "t": [s.t for s in sel],
            "roi_stability": [s.roi_stability for s in sel],
            "lighting": [s.lighting for s in sel],
            "motion": [s.motion for s in sel],
        }

    def mean_quality(self, secs: float = 10.0):
        w = self.window(secs)
        def _m(k):
            v = w[k]
            return sum(v) / len(v) if v else 0.0
        return {
            "roi_stability": _m("roi_stability"),
            "lighting": _m("lighting"),
            "motion": _m("motion"),
        }
