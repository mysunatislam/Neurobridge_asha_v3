import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';
import 'assessment_service.dart';

/// Guided 13-stage assessment (mirrors calibration.js STEPS):
/// quality → neutral → eyes → blink → closedSmile → smile → pucker →
/// left → right → pitch → nod → neutralEnd → validation.
class AssessmentScreen extends StatefulWidget {
  final AppScope scope;
  final AssessmentService service;
  const AssessmentScreen({super.key, required this.scope, required this.service});
  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  static const steps = [
    'Camera / face quality', 'Neutral', 'Eyes open', 'Blink ×3',
    'Closed-lip smile ×3', 'Comfortable smile ×3', 'Pucker ×3',
    'Head left-return ×3', 'Head right-return ×3', 'Pitch movement',
    'Nod ×3', 'Relaxed neutral', 'Validation',
  ];

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Patient assessment')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          LinearProgressIndicator(value: (svc.step + 1) / steps.length),
          const SizedBox(height: 10),
          Text('Step ${svc.step + 1} of ${steps.length}: ${steps[svc.step]}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Follow the instruction until Capture completes. Capture pauses on inadequate quality.',
              style: TextStyle(color: Color(0xFF93A1BB))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Prototype: mark current stage passed with good quality.
              svc.mark(_keyFor(svc.step), q: 0.9);
              if (svc.step < steps.length - 1) {
                setState(() => svc.step++);
              } else {
                _finish();
              }
            },
            child: const Text('Capture step'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: svc.step > 0 ? () => setState(() => svc.step--) : null,
            style: OutlinedButton.styleFrom(minimumSize: const Size(200, 56)),
            child: const Text('Back'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: svc.checks.entries.map((e) => Chip(label: Text('${e.key} ✓'))).toList(),
          ),
        ]),
      ),
    );
  }

  String _keyFor(int step) => switch (step) {
        0 => 'quality', 1 => 'neutral', 2 => 'eyes', 3 => 'blink',
        4 => 'closedSmile', 5 => 'smile', 6 => 'pucker',
        7 => 'head_left', 8 => 'head_right', 9 => 'pitch',
        10 => 'nod', 11 => 'neutralEnd', _ => 'validation',
      };

  void _finish() {
    final r = widget.service.complete();
    widget.scope.asha.patient.capability = r.capability;
    widget.scope.asha.routeCommunication();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recommended setup'),
        content: SingleChildScrollView(
          child: Text(
              'Primary: ${r.recommendedPrimary}\nBackup: ${r.recommendedBackup}\nReliable: ${r.reliableGestures.join(', ')}\nVitalSense: ${r.vitalQuality}\n\n${r.guidance.join('\n\n')}'),
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
  }
}
