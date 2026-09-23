"""NeuroBridge Asha VitalSense AI — contactless rPPG monitoring prototype.

Offline-first, edge-compatible core. Camera/MediaPipe are optional adapters;
the signal pipeline works on pre-extracted ROI RGB means so it is testable
without hardware.
"""

from .pipeline import VitalSenseEngine, VitalReading
from .signal_processing import estimate_heart_rate, bandpass, detrend, normalize_signal
from .confidence import confidence_score, ConfidenceInputs
from .calibration import PatientProfile, calibrate_from_baseline
from .asha_integration import AshaReasoning, AshaAlert

__all__ = [
    "VitalSenseEngine",
    "VitalReading",
    "estimate_heart_rate",
    "bandpass",
    "detrend",
    "normalize_signal",
    "confidence_score",
    "ConfidenceInputs",
    "PatientProfile",
    "calibrate_from_baseline",
    "AshaReasoning",
    "AshaAlert",
]

__version__ = "0.1.0"
