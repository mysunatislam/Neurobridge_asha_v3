"""FastAPI router — mount into any host app (offline, no cloud calls).

    from vitalsense.api import router, engine
    app.include_router(router)
"""

import time

from fastapi import APIRouter
from pydantic import BaseModel

from .pipeline import VitalSenseEngine
from .calibration import ProfileStore

engine = VitalSenseEngine()
store = ProfileStore("asha_vital.db")

router = APIRouter(prefix="/api/vital", tags=["vitalsense"])


class FrameIn(BaseModel):
    r: float
    g: float
    b: float
    t: float | None = None
    roi_stability: float = 0.9
    lighting: float = 0.8
    motion: float = 0.1
    patient_id: str = "demo"
    facial_tension: float = 0.0
    movement_drop: bool = False


@router.post("/frame")
def ingest(f: FrameIn):
    engine.patient_id = f.patient_id
    engine.add_frame(f.r, f.g, f.b, f.t, f.roi_stability, f.lighting, f.motion)
    rd = engine.reading(f.facial_tension, f.movement_drop)
    store.log_reading(f.patient_id, rd.bpm, rd.resp_per_min, rd.confidence, rd.status)
    return {
        "bpm": rd.bpm, "resp_per_min": rd.resp_per_min,
        "confidence": rd.confidence, "status": rd.status,
        "signal_quality": rd.signal_quality, "motion": rd.motion,
        "stress": rd.stress,
        "alert": {"level": rd.alert.level, "message": rd.alert.message}
        if rd.alert else None,
    }


@router.get("/reading")
def reading():
    rd = engine.reading()
    return {"bpm": rd.bpm, "resp_per_min": rd.resp_per_min,
            "confidence": rd.confidence, "status": rd.status,
            "signal_quality": rd.signal_quality, "motion": rd.motion,
            "stress": rd.stress, "waveform": engine.waveform()}


@router.get("/waveform")
def waveform(secs: float = 6.0):
    return {"fs": engine.fs, "values": engine.waveform(secs)}
