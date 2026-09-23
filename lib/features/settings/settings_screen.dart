import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';

/// Caregiver settings: Maira creds (never hardcoded), voice, privacy.
class SettingsScreen extends StatefulWidget {
  final AppScope scope;
  const SettingsScreen({super.key, required this.scope});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _user, _project, _api, _bearer, _profile;
  @override
  void initState() {
    super.initState();
    final m = widget.scope.maira.settings;
    _user = TextEditingController(text: m.userId);
    _project = TextEditingController(text: m.projectKey);
    _api = TextEditingController(text: m.apiKey);
    _bearer = TextEditingController(text: m.bearer);
    _profile = TextEditingController(text: m.gptProfileId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Maira reasoning (optional, user-triggered)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        TextField(controller: _user, decoration: const InputDecoration(labelText: 'User ID')),
        TextField(controller: _project, decoration: const InputDecoration(labelText: 'Project key')),
        TextField(controller: _api, decoration: const InputDecoration(labelText: 'API key')),
        TextField(controller: _bearer, obscureText: true, decoration: const InputDecoration(labelText: 'Bearer token')),
        TextField(controller: _profile, decoration: const InputDecoration(labelText: 'GPT profile ID (optional)')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: ElevatedButton(
                  onPressed: _save, child: const Text('Save Maira settings'))),
          const SizedBox(width: 10),
          Expanded(
              child: OutlinedButton(
                  onPressed: _test, child: const Text('Test connection'))),
        ]),
        const SizedBox(height: 8),
        const Text('Credentials stay on this device only. Camera inference never requires them.',
            style: TextStyle(color: Color(0xFF93A1BB), fontSize: 13)),
        const Divider(height: 32),
        const Text('Privacy', style: TextStyle(fontWeight: FontWeight.w700)),
        const Text('Camera processing: on-device · Microphone: off unless speaking · Cloud reasoning: optional · Images shared: only with explicit authorization.',
            style: TextStyle(color: Color(0xFF93A1BB))),
        SwitchListTile(
            title: const Text('Cloud reasoning'),
            value: true,
            onChanged: (_) {}),
        const ListTile(
            title: Text('Delete my data'),
            subtitle: Text('Clears local events, calibration drafts and memory.')),
      ]),
    );
  }

  Future<void> _save() async {
    final m = widget.scope.maira.settings;
    m.userId = _user.text.trim();
    m.projectKey = _project.text.trim();
    m.apiKey = _api.text.trim();
    m.bearer = _bearer.text.trim();
    m.gptProfileId = _profile.text.trim();
    await widget.scope.store.set('maira', m.toJson());
    if (mounted) {
      widget.scope.asha.setDegraded(!m.configured);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(m.configured ? 'Maira saved.' : 'Saved. Asha runs in essential mode until configured.')));
    }
  }

  Future<void> _test() async {
    final r = await widget.scope.maira.testConnection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.ok ? 'Maira link OK: ${r.answer}' : 'Maira: ${r.error}')));
  }
}
