# NeuroBridge Asha VitalSense AI

Real-time **contactless physiological monitoring** for NeuroBridge Asha —
heart rate, respiration, stress and confidence from **only the device camera**.
No wearables. Works **offline** on phone / tablet / Raspberry Pi wheelchair computer.

Verified prototype: synthetic 75 BPM → **75.0 BPM, 76.4% Reliable**; high-motion
gating collapses confidence and holds last value (`tests/test_pipeline_synthetic.py`).

## Quick start (prototype)

```bash
cd neurobridge-vitalsense
pip install -r requirements.txt
python tests/test_pipeline_synthetic.py   # synthetic 75/72 BPM + gating + calibration
```

## Live measurement (real camera, recommended)

Open `demo/vitalsense-real.html` (served, e.g. `python -m http.server 8085` in
`demo/`) — real webcam rPPG built from the PulseSight prototype with accuracy
fixes: mean-displacement motion gate, corrected breathing tracker, per-ROI
quality gating, 1 s MA detrending + brickwall bandpass, parabolic interpolation
(~0.2 BPM resolution), octave-jump guard, HRV on filtered waveform, plus the
Asha strip (30 s calibration, stress, 0–100% confidence, 10 s-persisted alert).
Verified: `python tests/dsp_extract_test.py` runs the shipped file's DSP in
node — 75→75.06, 60→60.03, 100→100.13 BPM on drift+noise synthetics.

## Dashboards preview (simulated, no camera)

Open `demo/vitalsense-demo.html` in a browser — futuristic patient + caregiver
dashboards, ECG-style waveform, ROI overlay, distress simulation, confidence table.

## Production mobile UI

`mobile/lib/vitalsense_monitor.dart` — Flutter widget (heart card, neon waveform,
respiration/stress/signal/movement tiles, alert banner) fed by
`MethodChannel('neurobridge/vital')`.

## Python engine

```python
from vitalsense.pipeline import VitalSenseEngine
eng = VitalSenseEngine()                       # 30 fps, 30 s window
eng.set_baseline(72.0, 65.0, 85.0)             # from 30 s calibration
eng.add_frame(r, g, b, t, roi_stability=0.9, lighting=0.8, motion=0.1)
rd = eng.reading()                             # bpm, resp, confidence, status, alert
print(rd.bpm, rd.confidence, rd.status)        # 75.0 76.4 Reliable
wave = eng.waveform()                          # 6 s filtered pulse for canvas
```

Optional HTTP mount: `from vitalsense.api import router` →
`POST /api/vital/frame`, `GET /api/vital/reading`, `GET /api/vital/waveform`.

## Pipeline (rPPG)

1. **ROI** (`roi.py`): forehead / L-R cheek / nose bridge from 468 landmarks;
   eyes, lips, beard, hair excluded; weighted fusion survives occlusion.
2. **Extraction** (`signal_extractor.py`): per-frame RGB means, green primary,
   30–60 s rolling buffer @ 30 FPS.
3. **DSP** (`signal_processing.py`): detrend → normalize → Butterworth 0.7–4 Hz
   → chrominance motion suppression → Hann + 4× FFT → peak × 60 = BPM.
   Respiration separately at 0.1–0.5 Hz.
4. **Motion** (`motion_compensation.py`): head rotation/translation → 0–1 score;
   low measure / moderate derate / high hold-last.
5. **Confidence** (`confidence.py`): ROI + light + stillness + SQI + peak clarity
   → 0–100% + Reliable/Uncertain/Unreliable.
6. **Asha** (`asha_integration.py`): sustained rise above calibrated baseline +
   tension → *"Are you feeling uncomfortable? Would you like me to call your
   caregiver?"* + caregiver alert *"Asha detected possible patient discomfort."*

## Docs

- `ARCHITECTURE.md` — system diagram, module map, timing budget.
- `EDGE_DEPLOYMENT.md` — TFLite/MediaPipe/ONNX mobile + Pi targets, calibration.
- `demo/vitalsense-demo.html` — dashboards + waveform visualization.
- `mobile/lib/vitalsense_monitor.dart` — Flutter production UI.
