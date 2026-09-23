import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';

/// FingerSpeak module screen: vocabulary, dwell status, quality stats.
/// Asha Core consumes FingerSpeakService results, never this UI directly.
class FingerSpeakScreen extends StatelessWidget {
  final AppScope scope;
  const FingerSpeakScreen({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: scope.fingerspeak,
      builder: (context, _) {
        final q = scope.fingerspeak.qualityStats();
        return Scaffold(
          appBar: AppBar(title: const Text('FingerSpeak')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Personalized gesture vocabulary. Dwell 600ms + return-to-Rest required. Unknown movements are rejected, never spoken.',
                style: TextStyle(color: Color(0xFF93A1BB))),
            const SizedBox(height: 10),
            Text('Median latency: ${(q['medianLatencyMs'] as double).toStringAsFixed(0)} ms'),
            ...(q['vocabulary'] as List).map((g) => ListTile(
                  title: Text('$g'),
                  subtitle: Text(scope.fingerspeak.vocabulary['$g']?.phrase ?? ''),
                )),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                final r = scope.fingerspeak.classify(
                    predictedId: 'water',
                    summary: List.filled(8, 0.5),
                    modelConfidence: 0.91,
                    handVisible: true);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(r == null
                        ? 'Hold the gesture steady (dwell)…'
                        : 'Confirmed: ${r.phrase}')));
              },
              child: const Text('Simulate water dwell'),
            ),
          ]),
        );
      },
    );
  }
}
