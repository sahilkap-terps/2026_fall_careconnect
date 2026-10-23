import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:care_connect_app/pages/oracle_health_launch_page.dart';

void main() {
  group('OracleHealthLaunchPage', () {
    testWidgets(
      'displays the provided Oracle Health launch error',
      (tester) async {
        const errorMessage = 'Invalid Oracle Health launch request.';

        await tester.pumpWidget(
          const MaterialApp(
            home: OracleHealthLaunchPage(
              errorMessage: errorMessage,
            ),
          ),
        );

        expect(find.text('Oracle Health Connection'), findsOneWidget);
        expect(find.text(errorMessage), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text('Preparing Oracle Health connection...'),
          findsNothing,
        );
      },
    );
  });
}
