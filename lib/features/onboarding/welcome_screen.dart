import 'package:flutter/material.dart';
import '../../core/services/app_scope.dart';
import '../patient/patient_home.dart';
import '../caregiver/caregiver_home.dart';

/// Calm first-launch: two huge choices, remembered but switchable.
class WelcomeScreen extends StatelessWidget {
  final AppScope scope;
  const WelcomeScreen({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _OrbMini(),
                const SizedBox(height: 20),
                const Text('NeuroBridge Asha',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text('Communication when words are difficult.\nSupport when no one is nearby.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Color(0xFF93A1BB), height: 1.5)),
                const SizedBox(height: 36),
                Semantics(
                  button: true,
                  label: 'Continue as patient',
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _go(context, 'patient'),
                      icon: const Icon(Icons.person, size: 32),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('PATIENT', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  button: true,
                  label: 'Continue as caregiver',
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _go(context, 'caregiver'),
                      icon: const Icon(Icons.volunteer_activism, size: 32),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('CAREGIVER', style: TextStyle(fontSize: 24)),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(220, 72),
                        side: const BorderSide(color: Color(0xFF2DD4BF), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Research prototype. Not a medical device.',
                    style: TextStyle(color: Color(0xFF93A1BB))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, String role) {
    scope.asha.setRole(role);
    scope.store.set('role', role);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => role == 'patient'
            ? PatientHome(scope: scope)
            : CaregiverHome(scope: scope)));
  }
}

class _OrbMini extends StatefulWidget {
  const _OrbMini();
  @override
  State<_OrbMini> createState() => _OrbMiniState();
}

class _OrbMiniState extends State<_OrbMini> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      return Container(width: 110, height: 110,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0E3A3A)));
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: 110 + _c.value * 10,
        height: 110 + _c.value * 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFF2DD4BF), Color(0xFF0E3A3A)]),
          boxShadow: [BoxShadow(color: const Color(0xFF2DD4BF).withValues(alpha: 0.35), blurRadius: 30 + _c.value * 20)],
        ),
        child: const Center(child: Text('◉', style: TextStyle(fontSize: 40, color: Colors.white))),
      ),
    );
  }
}
