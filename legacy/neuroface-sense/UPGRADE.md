# NeuroFace Sense upgrade handoff
Date: 23 September 2026  
Project: C:\Users\user\OneDrive\Documents\Default Project\neuroface-sense

## Delivered changes

The dashboard's design and module layout are preserved. The live recognition core was replaced with a shared, timestamp-driven pipeline: Face Landmarker → features → filtering/outlier rejection → quality checks → patient-relative normalization → gesture state machines → completed events → command engine → UI, optional speech and IndexedDB.

The old blink trough counter could count shallow signal reversals before reopening. It has been removed. Raw yaw and smile frame values no longer directly fire communication commands. The old random-weight CNN/LSTM outputs are excluded from live scores and labels; their architecture files remain available for later trained-model work.

Offline runtime/model assets are included. Local inference needs no paid API or application backend. A local static server supplies modules/WASM and a secure camera origin.

## Blink and head-turn behavior

Blink states are UNARMED → OPEN → CLOSING → CLOSED → OPENING → OPEN. An open-eye observation first arms the detector. Closure must persist, meet personalized EAR hysteresis and have blendshape support. Reopening must also stabilize. Only then can BLINK_COMPLETED be emitted, with duration, confidence, symmetry and measured closure amplitude. Single-frame closures, extremely long closure, gaps and low-quality input cannot produce repeated counts. A refractory interval prevents duplicates.

Deliberate classification uses duration/amplitude ranges learned during calibration; before calibration it uses explicitly provisional defaults. Three eligible completed events in five seconds can trigger water. Roughly facing the camera is required, but this is not a scientific determination of conscious intent.

Head turns use UNARMED → CENTER → MOVING_LEFT/RIGHT → LEFT/RIGHT_CONFIRMED → RETURNING_CENTER → CENTER. Completion requires both a sustained excursion and stable center return. The detector uses calibrated matrix-derived yaw, separate enter/exit/center thresholds, timeout and refractory timing. Three completed left or right returns in eight seconds trigger food or toilet. Holding a turn does not count. A nod uses the analogous pitch FSM.

Smile states are NEUTRAL → SMILE_STARTING → SMILING → SMILE_HELD → RETURNING → NEUTRAL. Left and right strengths combine normalized smile blendshapes, cheek signals and scale/roll-normalized lip-corner movement. Closed lips are fully allowed. A strong side can establish a smile even if the other side moves little; symmetry is a separate reported feature. A completed nod and held smile combine within one second, including either event order, with a cooldown.

## Calibration and personalization

Thirteen timed stages replace instantaneous and frame-count-only capture. Each frame passes checks for face presence, finite features, pose, framing/size, lighting, frame rate and appropriate motion. Poor input pauses capture and explains why. Enrollment measures comfortable movement ranges and replays valid samples using provisional patient-specific thresholds, allowing reduced movement to be learned.

Stored statistics include mean, median, standard deviation, MAD, minimum, maximum and the 5th, 25th, 75th and 95th percentiles. The resulting twin includes separate eye baselines, blink hysteresis and deliberate timing, separate smile baselines/maxima/thresholds, neutral yaw/pitch/roll, comfortable left/right ranges, turn/center thresholds, nod range/direction and pucker baseline/range.

A five-action validation must pass before saving. Selective gesture retry is available after initial capture or for an existing calibrated profile. Original and adaptive baselines remain separate. Only high-quality, stable neutral frames may slowly adapt eye/pose baselines within bounded limits; these are periodically persisted. A developer control restores the original values.

## Persistence and debugging

Native IndexedDB is used instead of Dexie, avoiding another runtime dependency. The eight stores are:

| Store | Purpose |
|---|---|
| patients | Local patient ID and active calibration pointer |
| calibrations | Versioned original/adaptive twin, validation and capture metadata |
| calibrationGestures | Per-stage robust statistics and completed repetitions |
| sessions | Start/end, profile, configuration and recording status |
| frameFeatures | Selected numeric signals and observed detector states |
| gestureEvents | Completed events, timing, confidence and metadata |
| commandEvents | Outputs with their triggering events |
| modelSettings | Saved developer configuration |

Legacy localStorage calibration is preserved as unvalidated import history. No automatic raw-video storage was added. Numeric recording is explicit, full inference-rate by default, and capped at 54,000 frames. Downsampling is optional and reduces replay fidelity. Sessions can be exported as JSON/CSV, replayed or explicitly deleted.

The developer panel exposes raw/filtered EAR, raw/filtered/relative yaw, FSM states, confidence, command counts/timeouts, current thresholds and recent transitions. Runtime configuration and temporary patient-threshold overrides are editable, validated and resettable. Replay is isolated and cannot speak or issue live commands.

## Verification

- 40 deterministic automated tests cover blink closure/reopening, held eyes, noisy thresholds, three-event commands and timeout, closed/asymmetric smiles, head excursion/return, center jitter, lost tracking, poor-quality calibration, weak movement enrollment, selective-validation safeguards, nod-smile fusion, 15/24/30/60 FPS, relative pose, adaptive-baseline restrictions, full-rate replay, matrix layout and configuration validation.
- Browser checks cover the retained dashboard, synthetic demo, isolated blink test, calibration's real-camera guard, IndexedDB persistence across reload, numeric export/replay, actual bundled Face Landmarker inference on a blank image, and camera lifecycle using a fake feed.
- Controlled accepted-frame integration produces one water command from three completed blinks and one food command from three completed left returns. Recorded replay reproduces those two commands.
- Browser testing uses an isolated profile and synthetic inputs. It does not establish live-person detection accuracy or clinical validity.

Run `npm test` for the deterministic suite. With `npm start` running and dev dependencies installed, run `npm run test:browser`. The browser test blocks external network requests to verify use of bundled runtime assets.

## Manual webcam validation

Start `npm start` from the project, open http://127.0.0.1:4173, start the camera and complete calibration. Keep voice off for initial testing, enable commands and expand diagnostics if a gesture is missed.

| Test | Expected behavior |
|---|---|
| One blink | Counter increases once after reopening |
| Hold eyes closed | No repeated counts; closure beyond the allowed duration is rejected |
| Triple deliberate blink | Progress 1/3, 2/3, then water once within five seconds |
| Closed-lip smile | Smile detected with low jaw opening; held event after consistent activation |
| Asymmetric smile | Smile remains detected; left/right intensities differ and symmetry decreases |
| Three left turns | Return to center every time; exactly three completed events and food once |
| Three right turns | Symmetric behavior, producing toilet once |
| Nod + smile | Hold a smile while nodding, or smile within the fusion window; okay once |
| Leave camera view mid-gesture | Incomplete gesture is invalidated; no false completion |
| Wait beyond sequence timeout | Existing 1/3 or 2/3 progress returns to zero |

If a gesture fails validation, retry that gesture. Confirm that the displayed left/right sign matches the patient's anatomical movement on the mirrored preview. Repeat validation after changing camera position, lighting or patient seating.

## Files changed or added

Existing files updated:

- `app.js` — live pipeline integration, event-driven UI, calibrated workflow, storage wiring, ROI fix and honest model/status wording.
- `index.html` — preserve cards; update calibration controls, labels and scripts.
- `style.css` — calibration overflow and optional diagnostics styling.
- `README.md` — current setup, operation, architecture and limitations.

New source, tests and tooling:

- `src/engine.js`
- `src/vision.js`
- `src/calibration.js`
- `src/storage.js`
- `src/diagnostics.js`
- `tests/engine.test.cjs`
- `tests/vision.test.cjs`
- `tests/browser-smoke.cjs`
- `scripts/serve.cjs`
- `scripts/download-assets.cjs`
- `package.json`
- `package-lock.json`
- `.gitignore`
- `UPGRADE.md`

Bundled assets:

- `models/face_landmarker.task`
- `vendor/vision_bundle.mjs`
- `vendor/wasm/vision_wasm_internal.js`
- `vendor/wasm/vision_wasm_internal.wasm`
- `vendor/wasm/vision_wasm_nosimd_internal.js`
- `vendor/wasm/vision_wasm_nosimd_internal.wasm`
- `vendor/MEDIAPIPE-LICENSE.txt`
- `vendor/manifest.json`

The existing geometry, landmark, Maira and TF architecture files and their model configuration JSON files were retained.

The browser test also generates `test-results/dashboard.png`, an ignored screenshot containing synthetic demo data.

## Remaining limitations and future model work

Real webcam/patient trials are still required. Confidence is an engineering heuristic, not a calibrated probability of correctness. MediaPipe's JavaScript results expose landmarks, blendshapes and matrices, but not per-frame tracking probability; the UI therefore labels a quality proxy. Blur/occlusion checks are limited, and there is no clinically validated scoring, affect inference or diagnostic output.

Inference remains synchronous on the main thread. The implementation avoids duplicate video frames, throttles image-quality/secondary work and caps memory, but does not guarantee 25–30 FPS on every device. A worker is the next step if profiling shows sustained UI blocking. Very short blinks can fall between samples at low FPS. A conservative tracking reset favors avoiding false commands and may miss gestures interrupted by brief dropouts.

The UI currently operates one local patient profile, although data records have patient/session IDs. Storage is browser/origin-specific and may be evicted; export important research sessions. Stop recording before closing the tab: the final pending batch cannot be guaranteed during sudden browser shutdown. Maira availability and outputs were not tested with credentials.

For future patient-specific ML, `FEATURE_VECTOR` and `featureVector()` define a validated, fixed-order 18-value feature representation. Add a separately evaluated classifier over timestamped windows while retaining FSMs as the communication authority. For DISFA/BP4D integration, build licensed-data adapters that retain subject/session identity, AU labels, time alignment and missingness; split evaluation by subject to avoid leakage. An expression dataset such as AffectNet should be a separate robustness experiment, not a substitute for motor-event labels. No datasets were downloaded or bundled, and no new model was trained.

Implementation references: [MediaPipe Face Landmarker web guide](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker/web_js) and [MediaPipe matrix representation](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/framework/formats/matrix_data.proto).
