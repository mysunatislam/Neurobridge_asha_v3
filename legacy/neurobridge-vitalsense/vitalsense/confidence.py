"""VitalSignal Confidence Model 0-100%.

Inputs (all 0..1): roi_stability, lighting, motion_stillness (=1-motion),
signal quality index (sqi), FFT peak clarity.
Weights tuned for paralysis/stroke/ALS use: motion + peak clarity dominate
because wheelchair vibration and weak facial tone are the top failure modes.
"""

from dataclasses import dataclass

WEIGHTS = {
    "roi_stability": 0.20,
    "lighting": 0.15,
    "motion_stillness": 0.25,
    "sqi": 0.15,
    "peak_clarity": 0.25,
}


@dataclass
class ConfidenceInputs:
    roi_stability: float = 0.5
    lighting: float = 0.5
    motion_stillness: float = 0.5
    sqi: float = 0.5
    peak_clarity: float = 0.0


def _clip01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


def confidence_score(inp: ConfidenceInputs) -> dict:
    vals = {
        "roi_stability": _clip01(inp.roi_stability),
        "lighting": _clip01(inp.lighting),
        "motion_stillness": _clip01(inp.motion_stillness),
        "sqi": _clip01(inp.sqi),
        "peak_clarity": _clip01(min(1.0, inp.peak_clarity * 4.0)),  # clarity is peaky; rescale
    }
    score = sum(vals[k] * WEIGHTS[k] for k in WEIGHTS) * 100.0
    # Hard gates: darkness or violent motion cap the score regardless of FFT.
    if vals["lighting"] < 0.2:
        score = min(score, 30.0)
    if vals["motion_stillness"] < 0.2:
        score = min(score, 35.0)
    if vals["roi_stability"] < 0.15:
        score = min(score, 25.0)
    status = "Reliable" if score >= 75 else ("Uncertain" if score >= 45 else "Unreliable")
    return {"confidence": round(score, 1), "status": status, "breakdown": vals}
