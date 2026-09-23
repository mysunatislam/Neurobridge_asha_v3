import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';

/// Patient MY STATUS expanded content + caregiver vital card.
/// Never shows confidently-wrong numbers: Unreliable → 'temporarily unavailable'.
class VitalCard extends StatelessWidget {
  final AppScope scope;
  const VitalCard({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: scope.vitals,
      builder: (context, _) {
        final v = scope.vitals.last;
        final reliable = v.status == 'Reliable';
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: const Color(0xFF0D1528), borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.monitor_heart, color: Color(0xFF2DD4BF), size: 32),
              const SizedBox(width: 10),
              Text(v.status == 'Unreliable' ? 'Vital reading temporarily unavailable.' : '${v.bpm.toStringAsFixed(0)} BPM · ${v.status}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text('Breathing ${v.status == 'Unreliable' ? 'temporarily unavailable' : '${v.resp.toStringAsFixed(0)}/min · ${v.status}'} · Stress ${v.stress}'),
            Text('Confidence ${v.confidence.toStringAsFixed(0)}% · Signal ${v.quality} · Movement ${v.motion}',
                style: const TextStyle(color: Color(0xFF93A1BB))),
            if (!reliable)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Low confidence: Asha will ask, not conclude.',
                    style: TextStyle(color: Color(0xFFFFC44D))),
              ),
          ]),
        );
      },
    );
  }
}
