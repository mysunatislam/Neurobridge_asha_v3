import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';
import 'asha_orb.dart';
import '../asha/chat_screen.dart';
import '../caregiver/caregiver_home.dart';
import '../emergency/emergency_button.dart';
import '../simulation/simulation_panel.dart';
import '../simulation/developer_screen.dart';
import '../settings/settings_screen.dart';
import '../assessment/assessment_screen.dart';
import '../assessment/assessment_service.dart';
import '../fingerspeak/fingerspeak_screen.dart';
import '../neurosense/neurosense_screen.dart';

/// Ultra-minimal patient home (§5-6, §50): orb + 3 progressive panels + emergency.
/// One primary action per region, 48px+ targets, immediate feedback.
class PatientHome extends StatefulWidget {
  final AppScope scope;
  const PatientHome({super.key, required this.scope});
  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  int _open = -1; // 0 communicate, 1 asha, 2 status

  @override
  Widget build(BuildContext context) {
    final s = widget.scope;
    return ListenableBuilder(
      listenable: s.asha,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('NeuroBridge'),
          actions: [
            IconButton(
              tooltip: 'Switch to caregiver',
              iconSize: 32,
              onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => _SwitchHint(scope: s))),
              icon: const Icon(Icons.switch_account),
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(padding: EdgeInsets.zero, children: [
            const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF0D1528)),
                child: Text('NeuroBridge Asha\nModules & tools',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            _drawerItem(context, 'Talk with Asha', Icons.chat, ChatScreen(scope: s)),
            _drawerItem(context, 'FingerSpeak module', Icons.gesture, FingerSpeakScreen(scope: s)),
            _drawerItem(context, 'NeuroSense module', Icons.face, NeuroSenseScreen(scope: s)),
            _drawerItem(context, 'Assessment', Icons.assignment, AssessmentScreen(scope: s, service: AssessmentService())),
            _drawerItem(context, 'Settings & Maira', Icons.settings, SettingsScreen(scope: s)),
            _drawerItem(context, 'Simulation', Icons.science, SimulationPanel(scope: s)),
            _drawerItem(context, 'Developer mode', Icons.code, DeveloperScreen(scope: s)),
          ]),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                const SizedBox(height: 8),
                AshaOrb(state: s.asha.degraded ? 'offline' : 'monitoring'),
                const SizedBox(height: 10),
                const Text('ASHA', style: TextStyle(letterSpacing: 6, fontSize: 16, color: Color(0xFF93A1BB))),
                const SizedBox(height: 6),
                const Text("I'm here with you.", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Semantics(
                  liveRegion: true,
                  child: Text(s.asha.statusLine,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF93A1BB))),
                ),
                if (s.asha.degraded)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Asha intelligence limited · Essential communication remains available.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFFFC44D))),
                  ),
                const SizedBox(height: 18),
                _bigPanel(context, 0, Icons.gesture, 'COMMUNICATE',
                    'Your ${_channelLabel(s)} is ready.', _communicateBody()),
                const SizedBox(height: 14),
                _bigPanel(context, 1, Icons.chat_bubble_outline, 'ASHA',
                    'Talk, joke, or ask for help.', _ashaBody()),
                const SizedBox(height: 14),
                _bigPanel(context, 2, Icons.favorite_outline, 'MY STATUS',
                    'Vitals and requests, only when you ask.', _statusBody()),
                const SizedBox(height: 18),
                EmergencyButton(scope: s),
                const SizedBox(height: 14),
                _voiceBar(s),
                const SizedBox(height: 12),
                const Text('Camera processing: on-device · Images shared: No',
                    style: TextStyle(fontSize: 12, color: Color(0xFF93A1BB))),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _channelLabel(AppScope s) {
    final ch = s.asha.patient.capability.preferredChannel;
    return ch == 'fingerspeak' ? 'FingerSpeak' : 'facial';
  }

  /// Real-voice continuous talk control. Browsers require a user tap
  /// before audio, so this bar is the explicit gesture that unlocks it.
  Widget _voiceBar(AppScope s) {
    return ListenableBuilder(
      listenable: s.tts,
      builder: (context, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1528),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.record_voice_over, color: Color(0xFF2DD4BF), size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.tts.continuousTalk ? 'Asha is talking with you' : 'Asha voice ready',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(s.tts.label(), style: const TextStyle(fontSize: 13, color: Color(0xFF93A1BB))),
              ]),
            ),
            Switch(
              value: s.tts.continuousTalk,
              onChanged: (v) async {
                if (v) {
                  await s.tts.init();
                  s.tts.startContinuous();
                } else {
                  s.tts.stopContinuous();
                }
              },
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await s.tts.init();
                if (s.tts.continuousTalk) {
                  s.tts.stopContinuous();
                } else {
                  // User gesture unlocks web audio, then continuous feminine talk.
                  s.tts.startContinuous();
                }
              },
              icon: Icon(s.tts.continuousTalk ? Icons.stop : Icons.play_arrow, size: 28),
              label: Text(s.tts.continuousTalk ? 'Pause Asha voice' : 'Tap to enable Asha voice',
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bigPanel(BuildContext context, int index, IconData icon, String title, String sub, Widget body) {
    final open = _open == index;
    return Semantics(
      button: true,
      expanded: open,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1528),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: open ? const Color(0xFF2DD4BF) : Colors.white10, width: open ? 2 : 1),
        ),
        child: Column(children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _open = open ? -1 : index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(children: [
                Icon(icon, size: 40, color: const Color(0xFF2DD4BF)),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(sub, style: const TextStyle(fontSize: 14, color: Color(0xFF93A1BB))),
                ])),
                Icon(open ? Icons.expand_less : Icons.expand_more, size: 36),
              ]),
            ),
          ),
          if (open) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 18), child: body),
        ]),
      ),
    );
  }

  Widget _communicateBody() {
    final s = widget.scope;
    final ch = s.asha.patient.capability.preferredChannel;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Active channel: ${ch == 'fingerspeak' ? 'FingerSpeak hand gestures' : 'NeuroSense face'}. '
          'Asha announces every mapping aloud before listening.',
          style: const TextStyle(color: Color(0xFF93A1BB))),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: () async {
          await s.tts.speak("You're awake. Do you need anything? Blink three times for yes. Smile for no.");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Asha is listening: triple-blink = yes, smile = no')));
          }
        },
        child: const Text('Start check-in'),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('FingerSpeak ready: ${s.fingerspeak.vocabulary.length} phrases'))),
        style: OutlinedButton.styleFrom(minimumSize: const Size(200, 56)),
        child: const Text('Test my gestures', style: TextStyle(fontSize: 18)),
      ),
    ]);
  }

  Widget _ashaBody() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Asha stays with you, tells jokes, reads family messages, and calls your caregiver when you ask.',
          style: TextStyle(color: Color(0xFF93A1BB))),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatScreen(scope: widget.scope))),
        child: const Text('Talk with Asha'),
      ),
    ]);
  }

  Widget _statusBody() {
    final v = widget.scope.vitals.last;
    String hr = v.status == 'Unreliable' ? 'temporarily unavailable' : '${v.bpm.toStringAsFixed(0)} BPM · ${v.status}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _row('Heart-rate estimate', hr),
      _row('Breathing', v.status == 'Unreliable' ? 'temporarily unavailable' : '${v.resp.toStringAsFixed(0)}/min · ${v.status}'),
      _row('Communication',
          widget.scope.asha.patient.capability.preferredChannel == 'fingerspeak' ? 'FingerSpeak ready' : 'NeuroSense ready'),
      _row('Face', widget.scope.neurosense.tracking ? 'Visible' : 'Not visible'),
      const SizedBox(height: 8),
      const Text('Advanced metrics live in caregiver + developer views.',
          style: TextStyle(color: Color(0xFF93A1BB), fontSize: 13)),
    ]);
  }

  Widget _row(String k, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(color: Color(0xFF93A1BB)))),
          Expanded(child: Text(val, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
        ]),
      );

  ListTile _drawerItem(BuildContext context, String label, IconData icon, Widget page) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label, style: const TextStyle(fontSize: 17)),
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
        },
      );
}

class _SwitchHint extends StatelessWidget {
  final AppScope scope;
  const _SwitchHint({required this.scope});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Switch role')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(
              onPressed: () {
                scope.asha.setRole('patient');
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => PatientHome(scope: scope)));
              },
              child: const Text('Patient')),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: () async {
                final ok = await _askPin(context);
                if (ok && context.mounted) {
                  scope.asha.setRole('caregiver');
                  Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => _CaregiverGate(scope: scope)));
                }
              },
              child: const Text('Caregiver (PIN)')),
        ]),
      ),
    );
  }

  Future<bool> _askPin(BuildContext context) async {
    final c = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Caregiver PIN'),
        content: TextField(controller: c, obscureText: true, keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Prototype PIN: 1234')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text == '1234'), child: const Text('Unlock')),
        ],
      ),
    );
    return res == true;
  }
}

class _CaregiverGate extends StatelessWidget {
  final AppScope scope;
  const _CaregiverGate({required this.scope});
  @override
  Widget build(BuildContext context) => CaregiverHome(scope: scope);
}
