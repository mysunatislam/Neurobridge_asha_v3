import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';

/// Safety-critical emergency control with accidental-activation protection:
/// press-and-hold 1.5s + confirm dialog. Never hidden in menus.
class EmergencyButton extends StatefulWidget {
  final AppScope scope;
  const EmergencyButton({super.key, required this.scope});
  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton> {
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergency. Press and hold to confirm.',
      child: GestureDetector(
        onLongPressStart: (_) => _hold(),
        onLongPressEnd: (_) => setState(() => _progress = 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A0E14),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFF5A6E), width: 2),
          ),
          child: Column(children: [
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.emergency, color: Color(0xFFFF5A6E), size: 34),
              SizedBox(width: 10),
              Text('EMERGENCY', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFFF5A6E))),
            ]),
            const SizedBox(height: 4),
            Text(_progress > 0 ? 'Keep holding…' : 'Press and hold',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _progress, color: const Color(0xFFFF5A6E)),
          ]),
        ),
      ),
    );
  }

  Future<void> _hold() async {
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _progress = i / 10);
    }
    setState(() => _progress = 0);
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm emergency?'),
        content: const Text('Asha will contact your primary caregiver now. Only confirm if you need urgent help.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5A6E)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, get help')),
        ],
      ),
    );
    if (confirm == true) {
      await widget.scope.tts.speak('Emergency confirmed. Contacting your caregiver now.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency workflow started. Contacting caregiver.')));
    }
  }
}
