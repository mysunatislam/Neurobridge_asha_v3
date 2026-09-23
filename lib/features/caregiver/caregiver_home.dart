import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';
import '../assessment/assessment_screen.dart';
import '../assessment/assessment_service.dart';
import '../simulation/simulation_panel.dart';
import '../simulation/developer_screen.dart';
import '../settings/settings_screen.dart';
import '../patient/patient_home.dart';

/// Caregiver home answers: okay? communicable? sensors reliable? attention?
/// Progressive disclosure tabs: Live | Communication | Insights | Care Plan | Assessment.
class CaregiverHome extends StatefulWidget {
  final AppScope scope;
  const CaregiverHome({super.key, required this.scope});
  @override
  State<CaregiverHome> createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {
  @override
  Widget build(BuildContext context) {
    final s = widget.scope;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Asha · Caregiver'),
          actions: [
            IconButton(
              tooltip: 'Patient view',
              icon: const Icon(Icons.person),
              onPressed: () {
                s.asha.setRole('patient');
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => PatientHome(scope: s)));
              },
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SettingsScreen(scope: s))),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [Tab(text: 'Live'), Tab(text: 'Comms'), Tab(text: 'Insights'), Tab(text: 'Care plan'), Tab(text: 'Assess')],
          ),
        ),
        body: TabBarView(children: [
          _live(s),
          _comms(s),
          _insights(s),
          _careplan(s),
          _assess(s),
        ]),
      ),
    );
  }

  Widget _live(AppScope s) {
    return ListenableBuilder(
      listenable: s.vitals,
      builder: (context, _) {
        final v = s.vitals.last;
        final ok = v.status == 'Reliable';
        return ListView(padding: const EdgeInsets.all(16), children: [
          _statusCard(ok ? 'Comfortable' : (v.status == 'Uncertain' ? 'Checking' : 'Needs attention'),
              ok ? Colors.greenAccent : Colors.amberAccent,
              'Asha monitoring: active · Channel: ${s.asha.patient.capability.preferredChannel} · Vital: ${v.status} (${v.confidence.toStringAsFixed(0)}%)'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _tile('Heart rate', v.status == 'Unreliable' ? 'unavailable' : '${v.bpm.toStringAsFixed(0)} BPM')),
            const SizedBox(width: 10),
            Expanded(child: _tile('Breathing', v.status == 'Unreliable' ? 'unavailable' : '${v.resp.toStringAsFixed(0)}/min')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _tile('Face tracking', '${(s.neurosense.trackingQuality * 100).toStringAsFixed(0)}%')),
            const SizedBox(width: 10),
            Expanded(child: _tile('Camera', s.camera.quality)),
          ]),
          const SizedBox(height: 12),
          if (v.alert != null)
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    border: Border.all(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(v.alert!, style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 12),
          const Text('Recent Asha activity', style: TextStyle(fontWeight: FontWeight.w700)),
          ...s.logs.recent(n: 6).map((e) => ListTile(
                dense: true,
                title: Text('${e['source']}: ${e['event']}'),
                subtitle: Text('${e['timestamp']}'),
              )),
          const SizedBox(height: 12),
          const Text('Why did Asha do this?',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const Text('• Patient transitioned from prolonged rest to awake.\n• Face tracking confidence: High.\n• No interaction during previous 42 minutes.\nNo emergency was detected.',
              style: TextStyle(color: Color(0xFF93A1BB))),
        ]);
      },
    );
  }

  Widget _comms(AppScope s) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Gesture vocabulary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ...s.fingerspeak.vocabulary.entries.map((e) => ListTile(
            title: Text(e.key),
            subtitle: Text(e.value.phrase),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final c = TextEditingController(text: e.value.phrase);
                final res = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                          title: Text('Phrase for ${e.key}'),
                          content: TextField(controller: c),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save')),
                          ],
                        ));
                if (res != null) setState(() => s.fingerspeak.setPhrase(e.key, res));
              },
            ),
          )),
      const Divider(),
      ListTile(
        title: const Text('Patient language'),
        subtitle: Text(s.asha.patient.language == 'bn' ? 'Bangla' : 'English'),
        trailing: Switch(
          value: s.asha.patient.language == 'bn',
          onChanged: (v) => setState(() => s.asha.patient.language = v ? 'bn' : 'en'),
        ),
      ),
      ListTile(
        title: const Text('Test Asha voice'),
        subtitle: Text(s.tts.label()),
        trailing: IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => s.tts.speak("You're awake. Do you need anything?")),
      ),
      const Text('Custom caregiver voice requires consent before storing voice data. Generated speech is always labelled, never presented as a live call.',
          style: TextStyle(color: Color(0xFF93A1BB), fontSize: 13)),
    ]);
  }

  Widget _insights(AppScope s) {
    final q = s.fingerspeak.qualityStats();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _tile('Median activation latency', '${(q['medianLatencyMs'] as double).toStringAsFixed(0)} ms'),
      _tile('False activations', '${(q['falseActivations'] as Map).length} types'),
      _tile('Missed gestures', '${(q['misses'] as Map).length} types'),
      const SizedBox(height: 10),
      const Text('Review uncertain detections', style: TextStyle(fontWeight: FontWeight.w700)),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Correct'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Wrong gesture'))),
      ]),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Missed request'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Recalibrate'))),
      ]),
    ]);
  }

  Widget _careplan(AppScope s) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Emergency contacts', style: TextStyle(fontWeight: FontWeight.w700)),
      ...s.logs.recent(n: 2).map((e) => Text('${e['action'] ?? ''}')),
      const ListTile(title: Text('Rima (primary)'), subtitle: Text('+880100000000')),
      const ListTile(title: Text('Karim (secondary)'), subtitle: Text('+880100000001')),
      SwitchListTile(
          title: const Text('Quiet hours (22:00–07:00)'),
          value: true,
          onChanged: (_) {}),
      const ListTile(title: Text('Interaction style'), subtitle: Text('Normal · Short questions')),
    ]);
  }

  Widget _assess(AppScope s) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Asha Patient Assessment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const Text('Determines communication ability + calibration. Not a diagnosis.',
          style: TextStyle(color: Color(0xFF93A1BB))),
      const SizedBox(height: 12),
      ElevatedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AssessmentScreen(scope: s, service: AssessmentService()))),
          child: const Text('Launch assessment')),
      const SizedBox(height: 12),
      Text('Recommended route: ${s.asha.patient.capability.preferredChannel}',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      OutlinedButton(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SimulationPanel(scope: s))),
          child: const Text('Open simulation panel')),
      const SizedBox(height: 8),
      OutlinedButton(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DeveloperScreen(scope: s))),
          child: const Text('Open developer mode')),
    ]);
  }

  Widget _statusCard(String title, Color c, String sub) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: const Color(0xFF0D1528), borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.withValues(alpha: 0.5))),
        child: Row(children: [
          Icon(Icons.monitor_heart, color: c, size: 40),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(sub, style: const TextStyle(color: Color(0xFF93A1BB))),
          ])),
        ]),
      );

  Widget _tile(String k, String v) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFF0D1528), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: Color(0xFF93A1BB), fontSize: 12)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      );
}

