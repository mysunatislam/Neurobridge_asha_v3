# Legacy NeuroBridge modules (vendored originals)

These are the **unmodified original implementations** that Asha's Dart
services were ported from. Kept in-repo so the system is self-contained:
every algorithm in `lib/` can be traced back to its source here.

| Directory | Source | Asha port |
|---|---|---|
| `neuroface-sense/src/engine.js` | Temporal Blink/Excursion/Smile FSMs + CommandEngine | `lib/features/neurosense/face_models.dart` |
| `neuroface-sense/src/calibration.js` | 13-stage calibration + `build()` | `lib/features/assessment/` |
| `neuroface-sense/src/fingerspeak-signal.js` + `fingerspeak.html` | Dwell/Rest/OOD hand policy | `lib/features/fingerspeak/fingerspeak_service.dart` |
| `neuroface-sense/utils/metrics.js` | EAR/MAR/smile/head/gaze geometry | `face_models.dart` |
| `neuroface-sense/utils/maira.js` | Maira `/v1/maira/ask` + `/vision` adapter | `lib/core/services/maira_service.dart` |
| `neuroface-sense/app.js` | Live facial dashboard wiring | `lib/features/neurosense/neurosense_service.dart` |
| `neurobridge-vitalsense/vitalsense/*.py` | rPPG pipeline, confidence, motion gate, Asha rules, calibration | `lib/features/vitalsense/vitalsense_service.dart` |
| `neurobridge-vitalsense/mobile/lib/vitalsense_monitor.dart` | Flutter vital widget | `lib/features/vitalsense/vital_card.dart` |

Excluded from vendoring (regenerable): `node_modules/`, `.git/`,
`test-results/`, Python `__pycache__/`.

Run the originals standalone:
- Face/FingerSpeak: `cd legacy/neuroface-sense && npm start` → http://127.0.0.1:4173
- VitalSense: `cd legacy/neurobridge-vitalsense && pip install -r requirements.txt && python tests/test_pipeline_synthetic.py`

Rule (§68): before modifying any ported algorithm, re-read the original
here, document behavior, and add a regression test.
