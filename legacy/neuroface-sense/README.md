# NeuroFace Sense
AI facial motor analysis research prototype. Not a medical device.

The facial dashboard is retained. Its live view uses MediaPipe Face Mesh and landmark heuristics; untrained CNN/LSTM outputs are excluded. FingerSpeak adds a separate hand-gesture communication mode with personalized calibration.

## Run locally

Node.js 20+ is sufficient; no package installation is required to run the app or unit tests.

```powershell
cd "C:\Users\user\OneDrive\Documents\Default Project\neuroface-sense"
npm start
```

Open http://127.0.0.1:4173 in Chrome or Edge. Start Camera, then Calibrate Patient. Choose **FingerSpeak** from the dashboard for hand-gesture communication. Camera access requires a secure origin such as localhost or HTTPS. Use the same origin/port and browser profile to retain the same IndexedDB data. Direct `file://` opening is not a reliable way to load local modules/WASM.

FingerSpeak's MediaPipe runtime, WASM, hand model and TensorFlow.js are bundled in `vendor/` and `models/hand_landmarker.task`, so its tracking and training need no internet. The facial dashboard still loads its Face Mesh script from a CDN; it needs connectivity on first load unless the browser has cached it. Restore missing vendor assets with `npm run setup:offline` while online. Versions and SHA-256 hashes are in `vendor/manifest.json`.

## FingerSpeak hand communication

FingerSpeak is a separate camera mode at `/fingerspeak.html`; navigating between modes releases the previous camera stream. It now tracks up to **two hands** and displays separate live, untrained pose previews for each: open palm, closed fingers, index, two fingers and three fingers extended. These generic labels do **not** speak. For speech, record at least five continuous, well-tracked samples per gesture, including the protected **Rest** class. A one-hand sample can use either hand; record two-hand combinations as their own examples and keep the same number of hands in frame throughout each sample. Use **New session** under changed lighting/position and compare held-out results before enabling speech. Unknown movements are rejected against the *predicted* class's training spread; commands need a stable dwell and a positively recognized Rest return before repeating. Gaps, duplicate frames, hand-count changes and short captures are rejected instead of being stretched into training examples.

Export a profile to retain calibration samples. Older one-hand profile JSON is imported into the new two-hand feature format, but an older saved one-hand neural model cannot be reused and must be retrained. **Save model** stores the new trained GRU in browser IndexedDB and its label/rejection metadata in localStorage; **Load saved model** restores both. Adding/removing gestures or samples disables speak mode until retraining. After loading, the DTW and prototype comparison models are unavailable until retraining from an imported profile. Do not treat a same-session validation percentage as real-world accuracy; test with the intended user and record false activations and misses. FingerSpeak is not a sole emergency communication channel or a validated clinical device.

## Recognition flow

Camera → Face Landmarker (VIDEO, one face, blendshapes + transformation matrix) → shared features → adaptive EMA/outlier checks → quality gate → patient normalization → gesture FSMs → completed events → command sequences → optional voice and numeric storage.

- A blink counts only after confirmed closure and reopening. EAR, blink blendshapes, velocity, duration and quality contribute; a held closure never becomes a stream of counts.
- A head turn counts only after a sustained excursion and stable return to center. Holding left produces no completed turn.
- Smile detection combines each side's smile/cheek signals and normalized corner movement. Jaw opening is not required. Asymmetry is reported separately.
- Nods use a pitch excursion-and-return FSM. A nod and a held smile can combine within one second, in either order.
- Tracking loss invalidates incomplete cycles. Completed command progress remains until its timeout.

| Completed sequence | Output | Default window |
|---|---|---|
| 3 deliberate blinks while roughly facing camera | I need water | 5 seconds |
| 3 left turns, each returning to center | I need food | 8 seconds |
| 3 right turns, each returning to center | I need to go to toilet | 8 seconds |
| Nod + held smile | I am okay, thank you | 1-second fusion tolerance |

Each command has a 3-second cooldown. Defaults, durations, smoothing and developer overrides are centralized in `src/engine.js`. Progress and a remaining-time countdown appear in the original communication cards.

## Calibration and Digital Twin

The 13 stages cover camera quality, neutral, open eyes, three deliberate blinks, three closed-lip smiles, three comfortable smiles, three puckers, three left returns, three right returns, pitch movement, three nods, relaxed neutral, and validation.

Use **Capture step** at each stage and follow the instruction until it completes. Capture pauses on inadequate quality; there is no timer that silently accepts missing data. Stage statistics include mean, median, standard deviation, MAD, min/max and 5/25/75/95 percentiles. Enrollment estimates comfortable movement ranges and replays the stage against those ranges, so weak movements need not cross the initial population defaults.

The final validation must recognize a blink, closed smile, left return, right return and nod before the twin is saved. Retry a single gesture after initial capture or from a previously calibrated profile. Closing calibration discards draft thresholds from live use. Original and slowly adapted baselines remain separate; adaptation is bounded and restricted to stable neutral observations.

## Storage, recording and replay

Native IndexedDB avoids an additional database-library dependency. Stores: `patients`, `calibrations`, `calibrationGestures`, `sessions`, `frameFeatures`, `gestureEvents`, `commandEvents`, `modelSettings`.

A legacy `neuroface_twin_v1` localStorage twin is imported as unvalidated history, not trusted as a new validated profile. The current UI uses one local patient alias; the database schema supports patient IDs.

Expand **Developer diagnostics / numeric session replay** to inspect raw/filtered EAR and pose, states, confidence, thresholds, rejection reasons and command buffers. Record selected numeric features, stop, choose a session, then export JSON/CSV or replay. Default recording retains every processed frame, capped at 54,000 frames. No video or image is automatically recorded. Starting a recording resets the temporal engine and freezes adaptation to make replay reproducible. Stop before closing the tab to flush pending data.

Replay is isolated from the camera and never speaks commands. Imported JSON can be either an exported session or an array of timestamped feature objects. If you enable numeric downsampling, short blinks may not survive replay.

## Tests

```powershell
npm test
```

The deterministic tests cover the requested A–M cases plus different frame rates, weak movement enrollment, baseline offsets, validation gates, matrix decomposition, replay and adaptation.

For the browser smoke test (keep `npm start` running in another terminal):

```powershell
npm install
npm run test:browser
```

The browser tests use Playwright and installed Chrome on Windows (or Playwright Chromium). They run in isolated browser profiles, not your real camera or stored data. They check the facial dashboard with synthetic landmarks and the FingerSpeak page with a synthetic camera, including local hand-model loading, two-hand pose preview and navigation. They do not establish live-user recognition accuracy.

## Existing modules and optional cloud features

Camera overlay, eye analysis, muscle indicators, smile/symmetry, lip control, micro-movement, head movement, graphs, activity log, calibration, snapshots, JSON export, communication and optional voice are retained. Region flow now compares each ROI against its own previous sample.

Maira remains optional and user-triggered. Session analysis sends a numeric digest to the configured service. Vision analysis uploads one JPEG only after a confirmation naming that endpoint. Maira credentials retain their existing browser-local storage behavior; camera inference does not require them. Availability, billing and accuracy of that external service are not verified by this upgrade.

## Limits

These are engineering movement features, not diagnoses, clinically validated motor scores or proof of deliberate intent. Confidence values are heuristic quality indicators. The JavaScript Face Landmarker result does not expose a tracking probability, so the UI explicitly labels a quality proxy. Occlusion and blur are not comprehensively classified. Inference currently runs synchronously, with secondary work throttled; target FPS depends on the device. Subtle or brief movement can be missed at low frame rates, and real patient validation is still required.

See [UPGRADE.md](UPGRADE.md) for the complete implementation handoff, file inventory and manual gesture tests.
