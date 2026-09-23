import 'package:flutter_test/flutter_test.dart';
import 'package:neurobridge_asha/main.dart';
import 'package:neurobridge_asha/core/services/app_scope.dart';
import 'package:neurobridge_asha/core/services/tts_service.dart';

void main() {
  testWidgets('Welcome shows calm choices, patient home is minimal', (tester) async {
    TtsService.testMode = true; // skip native voice engine (fake-async deadlock)
    final scope = AppScope();
    await scope.init();
    await tester.pumpWidget(NeuroBridgeAshaApp(scope: scope));
    expect(find.text('NeuroBridge Asha'), findsOneWidget);
    expect(find.text('PATIENT'), findsOneWidget);
    expect(find.text('CAREGIVER'), findsOneWidget);

    await tester.tap(find.text('PATIENT'));
    await tester.pump(); // orb breathes forever; never settle
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("I'm here with you."), findsOneWidget);
    expect(find.text('COMMUNICATE'), findsOneWidget);
    expect(find.text('ASHA'), findsWidgets);
    expect(find.text('MY STATUS'), findsOneWidget);
    expect(find.text('EMERGENCY'), findsOneWidget);
    // No ICU-style metric dump on patient home
    expect(find.textContaining('EAR'), findsNothing);
    expect(find.textContaining('yaw'), findsNothing);
  });
}
