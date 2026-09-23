# NeuroBridge Asha — Architecture

```
Camera/Sensors → CameraCoordinator (ONE stream, power modes)
  ├─ Face landmarks → NeuroSense Face (temporal FSMs + twin)
  ├─ Facial ROI     → VitalSense (confidence + motion gate + baseline)
  └─ Hand landmarks → FingerSpeak (dwell + Rest + OOD)
        ↓
PerceptionAggregator (normalized snapshot, no raw video to cloud)
        ↓
AshaEventBus (PatientAwake, GestureConfirmed, VitalChanged, …)
        ↓
Deterministic rules + RAG MemoryStore (local-first collections)
        ↓
Maira API (/v1/maira/ask, JSON contract, validated, offline fallback)
        ↓
AgentOrchestrator (PERCEIVE→…→RESPOND) → SafetyEngine → VerificationEngine
        ↓
AshaToolRegistry (LOW/MEDIUM/HIGH, confirmation-gated)
        ↓
Speak / Call+Alert / UI+Logging → Result verification → Patient
```

## Module map

```
lib/
  core/
    asha_core/ asha_state.dart, communication_state_machine.dart,
               perception_aggregator.dart, proactive_policy.dart
    orchestration/ agent_orchestrator.dart, tool_registry.dart
    safety/ safety_engine.dart
    verification/ verification_engine.dart
    rag/ memory_store.dart
    database/ models.dart, local_store.dart
    services/ app_scope.dart, event_bus.dart, maira_service.dart,
              tts_service.dart, camera_coordinator.dart
  features/
    onboarding/ welcome_screen.dart
    patient/ patient_home.dart, asha_orb.dart
    caregiver/ caregiver_home.dart
    asha/ chat_screen.dart, companion_service.dart
    fingerspeak/ fingerspeak_service.dart, fingerspeak_screen.dart
    neurosense/ face_models.dart, neurosense_service.dart, neurosense_screen.dart
    vitalsense/ vitalsense_service.dart, sleep_wake_service.dart, vital_card.dart
    assessment/ assessment_service.dart, assessment_screen.dart
    emergency/ emergency_service.dart, emergency_button.dart
    reports/ reports_service.dart
    settings/ settings_store.dart, settings_screen.dart
    simulation/ simulation_panel.dart, developer_screen.dart
  shared/theme/ asha_theme.dart
test/
  neurosense_fsm_test.dart, vitalsense_test.dart, agent_safety_test.dart,
  fingerspeak_test.dart, widget_test.dart
```

## Key contracts

- `FingerSpeakResult {gesture, confidence, intent_confirmed, timestamp, communication_phrase}`
- `FaceGestureEvent {BLINK_COMPLETED, LEFT/RIGHT_TURN_COMPLETED, NOD_COMPLETED, SMILE_*}`
- `VitalSnapshot {bpm, resp, confidence 0-100, status Reliable/Uncertain/Unreliable, motion, stress, alert?}`
- `SleepWakeState {awake|resting|probable_sleep|transition, confidence}`
- Maira reasoning JSON: `{assessment, confidence, response, next_action {tool, response_options[]}}`
- Tool proposal: `{intent, reason, tool, arguments, requires_confirmation}`

## Timing / power

- LOW_POWER (resting): 5 fps · ACTIVE: 15 fps · COMMUNICATION/ASSESSMENT: 30 fps.
- DSP batch 1 Hz on 30 s window; FFT peak ×60 = BPM; respiration 0.1–0.5 Hz.
- Blink 65–1400 ms, deliberate ≥260 ms, refractory 150 ms; head hold 130 ms + center 140 ms; smile enter 0.34/exit 0.20, held 450 ms; commands: blink window 5 s, turn window 8 s, cooldown 3 s, fusion 1 s.
