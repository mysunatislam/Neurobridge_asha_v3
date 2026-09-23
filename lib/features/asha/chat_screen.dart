import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';
import '../../core/database/models.dart';

/// Voice-first chat: Asha / patient-gesture / caregiver / system tool rows.
/// No internal chain-of-thought exposed.
class ChatScreen extends StatefulWidget {
  final AppScope scope;
  const ChatScreen({super.key, required this.scope});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ConversationMessage> _msgs = [];
  final TextEditingController _c = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _msgs.add(ConversationMessage('asha', "I'm here with you. Do you need anything?"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asha')),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _msgs.length,
            itemBuilder: (_, i) => _bubble(_msgs[i]),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Type, or answer with your gestures…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64, height: 64,
                child: IconButton.filled(
                  tooltip: 'Send',
                  iconSize: 30,
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(ConversationMessage m) {
    final isAsha = m.role == 'asha';
    final isSys = m.role == 'system';
    return Align(
      alignment: isAsha ? Alignment.centerLeft : (isSys ? Alignment.center : Alignment.centerRight),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: isAsha ? const Color(0xFF0E3A3A) : (isSys ? Colors.white10 : const Color(0xFF1B2B55)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.role == 'asha' ? 'Asha' : (m.role == 'patient' ? 'Patient · ${m.modality}' : 'System'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF93A1BB))),
          const SizedBox(height: 4),
          Text(m.text, style: const TextStyle(fontSize: 17)),
        ]),
      ),
    );
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (text.isEmpty || _busy) return;
    _c.clear();
    setState(() {
      _msgs.add(ConversationMessage('caregiver', text, modality: 'text'));
      _busy = true;
    });
    await widget.scope.tts.speak('Got it.');
    // Retrieve memory + reason (offline-safe).
    final mem = widget.scope.memory.retrieve(text, topK: 3);
    String reply;
    if (!widget.scope.maira.isOnline || !widget.scope.maira.settings.configured) {
      reply = _localReply(text);
    } else {
      final r = await widget.scope.maira.chat(text);
      reply = r.ok && r.answer.isNotEmpty ? r.answer : _localReply(text);
    }
    // Keep short for neurological ease.
    if (reply.length > 220) reply = '${reply.substring(0, 217)}…';
    setState(() {
      _msgs.add(ConversationMessage('asha', reply));
      _busy = false;
    });
    await widget.scope.tts.speak(reply);
    widget.scope.logs.log({'source': 'chat', 'event': 'turn', 'action': reply, 'context': 'mem:${mem.length}'});
  }

  String _localReply(String text) {
    final t = text.toLowerCase();
    if (t.contains('water')) return 'Okay. You need water. Would you like me to call your caregiver?';
    if (t.contains('pain') || t.contains('hurt')) return 'I hear you. Are you uncomfortable? Smile for yes, stay relaxed for no.';
    if (t.contains('joke')) return widget.scope.maira.isOnline ? 'Here is a gentle one: why did the phone go to the doctor? Weak signal.' : 'A cricket ball waits patiently for your smile before it bounces.';
    if (t.contains('call')) return 'You want me to call Rima. Is that right? Smile to confirm.';
    return 'I\'m listening. Would you like water, repositioning, or a call?';
  }
}
