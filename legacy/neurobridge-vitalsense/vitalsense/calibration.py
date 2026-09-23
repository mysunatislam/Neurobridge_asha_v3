"""Personal calibration + SQLite patient profile store."""

import json
import sqlite3
import time
from dataclasses import dataclass, asdict
from pathlib import Path


@dataclass
class PatientProfile:
    patient_id: str
    baseline_hr: float = 72.0
    normal_low: float = 65.0
    normal_high: float = 85.0
    baseline_resp: float = 16.0
    skin_gain: float = 1.0
    lighting_env: float = 0.8
    movement_pattern: float = 0.2
    calibrated_at: float = 0.0

    def to_dict(self):
        return asdict(self)


def calibrate_from_baseline(patient_id: str, hr_samples: list,
                             resp_samples: list | None = None,
                             lighting: float = 0.8,
                             movement: float = 0.2) -> PatientProfile:
    import numpy as np
    hr = np.asarray([h for h in hr_samples if 40 < h < 220], dtype=float)
    if hr.size == 0:
        raise ValueError("no valid baseline HR samples")
    mean, sd = float(hr.mean()), float(hr.std() or 5.0)
    sd = max(3.0, min(12.0, sd))
    resp = float(np.mean(resp_samples)) if resp_samples else 16.0
    return PatientProfile(
        patient_id=patient_id, baseline_hr=round(mean, 1),
        normal_low=round(max(40, mean - 2 * sd), 1),
        normal_high=round(min(200, mean + 2 * sd), 1),
        baseline_resp=round(resp, 1), lighting_env=lighting,
        movement_pattern=movement, calibrated_at=time.time(),
    )


class ProfileStore:
    """Local SQLite store — no cloud. Default path: vitalsense/asha_vital.db"""

    def __init__(self, path: str | Path = "asha_vital.db"):
        self.path = str(path)
        self._init()

    def _connect(self):
        return sqlite3.connect(self.path)

    def _init(self):
        with self._connect() as c:
            c.execute("""CREATE TABLE IF NOT EXISTS patients(
                patient_id TEXT PRIMARY KEY, profile TEXT, updated REAL)""")
            c.execute("""CREATE TABLE IF NOT EXISTS readings(
                id INTEGER PRIMARY KEY AUTOINCREMENT, patient_id TEXT,
                ts REAL, bpm REAL, resp REAL, confidence REAL, status TEXT)""")

    def save_profile(self, p: PatientProfile):
        with self._connect() as c:
            c.execute("INSERT OR REPLACE INTO patients VALUES(?,?,?)",
                      (p.patient_id, json.dumps(p.to_dict()), time.time()))

    def load_profile(self, patient_id: str) -> PatientProfile | None:
        with self._connect() as c:
            row = c.execute("SELECT profile FROM patients WHERE patient_id=?",
                            (patient_id,)).fetchone()
        return PatientProfile(**json.loads(row[0])) if row else None

    def log_reading(self, patient_id: str, bpm: float, resp: float,
                    confidence: float, status: str):
        with self._connect() as c:
            c.execute("INSERT INTO readings(patient_id,ts,bpm,resp,confidence,status)"
                      " VALUES(?,?,?,?,?,?)",
                      (patient_id, time.time(), bpm, resp, confidence, status))

    def recent(self, patient_id: str, n: int = 20):
        with self._connect() as c:
            return c.execute("SELECT ts,bpm,resp,confidence,status FROM readings"
                             " WHERE patient_id=? ORDER BY id DESC LIMIT ?",
                             (patient_id, n)).fetchall()
