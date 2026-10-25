import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:care_connect_app/widgets/epic_connect_tile.dart';

void main() {
  testWidgets('buttonOnly shows the compact Epic connect action',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EpicConnectTile(buttonOnly: true),
        ),
      ),
    );

    expect(find.byType(TextButton), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    // The compact version is used when the parent screen already displays
    // the Epic source name and connection status.
    expect(find.byType(Card), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Epic (MyChart)'), findsNothing);
  });
}