import 'package:flutter/material.dart';
import 'shared/theme/asha_theme.dart';
import 'core/services/app_scope.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/patient/patient_home.dart';
import 'features/caregiver/caregiver_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scope = AppScope();
  await scope.init();
  runApp(NeuroBridgeAshaApp(scope: scope));
}

class NeuroBridgeAshaApp extends StatelessWidget {
  final AppScope scope;
  const NeuroBridgeAshaApp({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: scope,
      builder: (context, _) => MaterialApp(
        title: 'NeuroBridge Asha',
        theme: AshaTheme.dark(),
        darkTheme: AshaTheme.dark(),
        themeMode: ThemeMode.dark,
        home: scope.asha.role.isEmpty
            ? WelcomeScreen(scope: scope)
            : (scope.asha.role == 'patient'
                ? PatientHome(scope: scope)
                : CaregiverHome(scope: scope)),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
