# NeuroBridge Asha — Adaptive AI Communication, Monitoring & Companion

Research prototype. **Not a medical device. No diagnosis. No emergency sole-channel.**

> Asha perceives the patient, understands available communication ability,
> reasons about context, communicates naturally, executes appropriate tools,
> and verifies that its interpretation was correct.

**Observe carefully. Assume cautiously. Ask simply. Verify intention. Act safely. Confirm the result.**

## Run

```powershell
cd "C:\Users\user\OneDrive\Documents\Default Project\neurobridge-asha"
flutter pub get
flutter analyze
flutter test
flutter run
```

Prototype PIN for caregiver mode: `1234`.

## What was built

- **Patient Mode** (ultra-minimal): Asha orb + `COMMUNICATE` / `ASHA` / `MY STATUS` progressive panels + press-and-hold `EMERGENCY`. No EAR/yaw/FFT on the dashboard.
- **Caregiver Mode**: Live / Comms / Insights / Care plan / Assess tabs, phrase customization, voice test, human-in-the-loop review buttons, escalation reason display.
- **Asha Core**: `AshaEventBus`, `PerceptionAggregator`, `CommunicationStateMachine` (IDLE→…→IDLE), `AgentOrchestrator` (PERCEIVE→…→RESPOND), `AshaToolRegistry` with LOW/MEDIUM/HIGH tiers, `SafetyEngine`, `VerificationEngine`, local-first `MemoryStore` RAG, `MairaService`.
- **Perception**: `FingerSpeakService` (dwell + Rest-return + OOD + latency/false/miss stats), `NeuroSenseService` (temporal Blink/Head/Smile FSMs + command engine), `VitalSenseService` (confidence weights + motion gate + 10s persist rule + baseline), `SleepWakeService` (awake/resting/probable_sleep/transition), `CameraCoordinator` (single stream, power modes).
- **Maira**: verified endpoints `POST /v1/maira/ask`, `POST /v1/maira/vision`; headers `project-key`/`api-key`/`Authorization: Bearer`. Secrets only in local settings, never hardcoded. Offline → deterministic fallback + banner.
- **Assessment**: 13-stage guided flow → recommended primary/backup + reliable gestures + measured guidance. Not a diagnosis.
- **Simulation + Developer**: awake/blink/smile/water/HR/camera/Maira/call/emergency triggers; landmark/confidence/tool-trace view (no secrets).
- **Tests**: 35 passing — blink/held-closure, head excursion+return, command cooldowns, FingerSpeak dwell/Rest/OOD, vitals confidence/gating/baseline, safety/verification/tool policy, state machine, RAG, routing, widget smoke.

## Migration map (existing modules → Asha)

| Existing | Asha location | What was preserved |
|---|---|---|
| `neuroface-sense/src/engine.js` Blink/Excursion/Smile FSMs, `CommandEngine`, quality gates | `lib/features/neurosense/face_models.dart` | OPEN→CLOSED→OPEN hysteresis + refractory; excursion+return; 3-blink→water / 3-left→food / 3-right→toilet / nod+smile→okay; cooldowns; min-confidence |
| `src/calibration.js` 13 stages + `build()` | `lib/features/assessment/*` | Stage list, quality reasons, personalized thresholds, validation gate, guidance strings |
| `src/fingerspeak-signal.js` + `fingerspeak.html` | `lib/features/fingerspeak/fingerspeak_service.dart` | Dwell/hold, Rest return, OOD vs predicted spread, confidence threshold, miss/false/latency tracking; 13-phrase defaults |
| `utils/metrics.js` EAR/MAR/smile/head/gaze | `face_models.dart` + `neurosense_service.dart` | Temporal use only; raw values hidden from patient UI |
| `utils/maira.js` | `lib/core/services/maira_service.dart` | `/v1/maira/ask` + `/v1/maira/vision`, envelope parsing, timeout, fail-soft |
| `vitalsense/pipeline.py`, `confidence.py`, `motion_compensation.py`, `asha_integration.py`, `calibration.py` | `lib/features/vitalsense/vitalsense_service.dart` | Weights (motion+clarity dominate), hard gates, low/mod/high gate with hold-last, 10s persist alert, mean±2sd baseline |
| `mobile/lib/vitalsense_monitor.dart` | `lib/features/vitalsense/vital_card.dart` | Status-first card, Unreliable → "temporarily unavailable" |

## Safety rules (deterministic, outside LLM)

- No diagnosis, no dosage, no "You are in pain" unless patient confirmed.
- High-risk tools (`call_caregiver`, `open_emergency_flow`, `transmit_image`…) need confirmation + policy check.
- Single noisy frame never triggers emergency; alerts need persistence.
- Images leave device only with explicit authorization.
- Every tool: planned → permission → executed → return checked → communicated. Never claim "I called" before the action initiates.

## Offline mode

Maira offline/unconfigured → banner "Asha intelligence limited · Essential communication remains available." Gestures, yes/no, water/food/toilet/pain/call/emergency, local TTS, monitoring, logs all keep working.

## Next hardware steps

- Plug `camera` + MediaPipe Tasks (Face Landmarker + Hand Landmarker) into `CameraCoordinator` → existing `processFrame`/`classify`/`ingest` hooks.
- Plug `flutter_tts` into `TtsService`, `url_launcher`/`telecom` into `EmergencyService`, `sqflite` behind `LocalStore` interface.
- BLE FingerSpeak wearable implements the same `FingerSpeakResult` contract — Asha Core unchanged.
