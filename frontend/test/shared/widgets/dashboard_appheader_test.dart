// Tests for DashboardAppHeader widget
// (lib/shared/widgets/dashboard_appheader_widget.dart).
//
// DashboardAppHeader is a PreferredSizeWidget that renders a custom AppBar.
// Provider.of<UserProvider> is only accessed in onPressed callbacks, never
// in build(), so a plain MaterialApp wrapper suffices for render tests.

import 'package:care_connect_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:care_connect_app/shared/widgets/dashboard_appheader_widget.dart';

Widget _wrap(DashboardAppHeader header) =>
    MaterialApp(locale: const Locale('en'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: Scaffold(appBar: header));

/// Puts the header in a GoRouter app with a stand-in /medical-passport page.
Widget _routed(DashboardAppHeader header) => MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => Scaffold(appBar: header)),
        GoRoute(path: '/medical-passport', builder: (_, __) => const Text('passport page')),
      ]),
    );

void main() {
  group('DashboardAppHeader', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_wrap(const DashboardAppHeader(
        userName: 'Alice',
        role: 'CAREGIVER',
      )));
      expect(find.byType(DashboardAppHeader), findsOneWidget);
    });

    testWidgets('shows CARECONNECT logo text', (tester) async {
      await tester.pumpWidget(_wrap(const DashboardAppHeader(
        userName: 'Alice',
        role: 'CAREGIVER',
      )));
      expect(find.text('CARECONNECT'), findsOneWidget);
    });

    testWidgets('shows welcome message with userName', (tester) async {
      await tester.pumpWidget(_wrap(const DashboardAppHeader(
        userName: 'John',
        role: 'CAREGIVER',
      )));
      expect(find.textContaining('Welcome back John'), findsOneWidget);
    });

    testWidgets('shows caregiver summary text for CAREGIVER role', (tester) async {
      await tester.pumpWidget(_wrap(const DashboardAppHeader(
        userName: 'Alice',
        role: 'CAREGIVER',
      )));
      expect(find.textContaining("patients' health summary"), findsOneWidget);
    });

    testWidgets('shows patient greeting for PATIENT role', (tester) async {
      await tester.pumpWidget(_wrap(const DashboardAppHeader(
        userName: 'Bob',
        role: 'PATIENT',
      )));
      expect(find.textContaining('How are you feeling today?'), findsOneWidget);
    });

    testWidgets('shows settings icon', (tester) async {
      await tester.pumpWidget(_wrap(const DashboardAppHeader(
        userName: 'Alice',
        role: 'CAREGIVER',
      )));
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows local_hospital icon (emergency QR)', (tester) async {
      await tester.pumpWidget(_wrap(const DashboardAppHeader(
        userName: 'Alice',
        role: 'CAREGIVER',
      )));
      expect(find.byIcon(Icons.local_hospital), findsAtLeastNWidgets(1));
    });

    testWidgets("CC-12: the emergency icon opens the patient's passport", (tester) async {
      await tester.pumpWidget(_routed(const DashboardAppHeader(userName: 'Bob', role: 'PATIENT')));
      await tester.tap(find.widgetWithIcon(IconButton, Icons.local_hospital));
      await tester.pumpAndSettle();
      expect(find.text('passport page'), findsOneWidget);
    });

    testWidgets('CC-12: the emergency icon stays put for a non-patient and says why', (tester) async {
      await tester.pumpWidget(_routed(const DashboardAppHeader(userName: 'Alice', role: 'CAREGIVER')));
      await tester.tap(find.widgetWithIcon(IconButton, Icons.local_hospital));
      await tester.pumpAndSettle();
      expect(find.text('passport page'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows person icon when profileImageUrl is empty', (tester) async {
      await tester.pumpWidget(_wrap(const DashboardAppHeader(
        userName: 'Alice',
        role: 'CAREGIVER',
        profileImageUrl: '',
      )));
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('preferredSize height is 210', (tester) async {
      const header = DashboardAppHeader(userName: 'Alice', role: 'CAREGIVER');
      expect(header.preferredSize.height, 210);
    });

    testWidgets('renders AppBar widget', (tester) async {
      await tester.pumpWidget(_wrap(const DashboardAppHeader(
        userName: 'Alice',
        role: 'CAREGIVER',
      )));
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
