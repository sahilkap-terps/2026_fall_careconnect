import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:care_connect_app/l10n/app_localizations.dart';
import 'package:care_connect_app/shared/widgets/disclaimer_banner.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'Team Alpha: disclaimer at ${scale * 100}% text scale '
        'in ${brightness.name} theme',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;

          addTearDown(tester.view.reset);
          addTearDown(
            tester.platformDispatcher.clearTextScaleFactorTestValue,
          );

          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              supportedLocales:
                  AppLocalizations.supportedLocales,
              theme: ThemeData(brightness: brightness),
              home: const Scaffold(
                body: DisclaimerBanner.ai(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byType(DisclaimerBanner), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
