// CaregiverMedicareTab (WBS 6.2.58, #322): a caregiver reading a patient's
// Medicare coverage and visits, fed with the backend's fixture bundles
// (see health_data_test_support.dart).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:care_connect_app/config/theme/app_theme.dart';
import 'package:care_connect_app/features/health/caregiver-patient-list/widgets/caregiver_medicare_tab.dart';
import 'package:care_connect_app/features/health/health_data/pages/health_event_details_screen.dart';
import 'package:care_connect_app/services/api_client.dart';

import '../../health_data/health_data_test_support.dart';

const _visits = '/v1/api/medicare/visits';
const _coverage = '/v1/api/medicare/coverage';

/// FR-MCR-17: "not shared" and "not connected" look the same.
const _unavailable = 'Medicare data isn\'t available for this patient yet.';
const _unreachable = 'We couldn\'t reach Medicare right now.';
const _noRecords = 'No Medicare records found.';
const _demo =
    'Demo data: showing synthetic Medicare records, not a live account.';
const _expired = 'This patient\'s Medicare connection has expired. They need '
    'to connect it again before you can see current records.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpClientAdapter original;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = ApiClient.instance.debugHttpClientAdapter;
  });
  tearDown(() => ApiClient.instance.debugSetHttpClientAdapter(original));

  RouteAdapter fixtures({bool synthetic = true, Completer<void>? gate}) =>
      RouteAdapter({
        _visits: envelope(fixtureResources('eob-bundle.json'),
            synthetic: synthetic),
        _coverage: envelope(fixtureResources('coverage-bundle.json'),
            synthetic: synthetic),
      }, gate: gate);

  Future<void> pump(WidgetTester t, RouteAdapter a,
      {ThemeData? theme}) async {
    ApiClient.instance.debugSetHttpClientAdapter(a);
    await t.pumpWidget(MaterialApp(
      theme: theme,
      home: const Scaffold(body: CaregiverMedicareTab(patientId: 3)),
    ));
  }

  /// Dio and the ApiClient interceptors run outside the fake clock: give them
  /// real time until the loading state ends (at most ~2 s), then settle.
  Future<void> settle(WidgetTester t) async {
    for (var i = 0;
        i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pumpAndSettle();
  }

  void expectNoRecords() {
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Coverage'), findsNothing);
    expect(find.text('Visits and claims'), findsNothing);
  }

  testWidgets(
      'TC-MCR-CG-001: reads that patient\'s visits and coverage with '
      '?patientId=', (t) async {
    final a = fixtures();
    await pump(t, a);
    await settle(t);
    expect(a.paths, [_visits, _coverage]);
    expect(a.uris.map((u) => u.queryParameters), [
      {'patientId': '3'},
      {'patientId': '3'},
    ]);
  });

  testWidgets('TC-MCR-CG-002: a labelled loading state shows until Medicare '
      'answers', (t) async {
    final handle = t.ensureSemantics();
    final gate = Completer<void>();
    await pump(t, fixtures(gate: gate));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading Medicare records'), findsOneWidget);
    gate.complete();
    await settle(t);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    handle.dispose();
  });

  testWidgets(
      'TC-MCR-CG-003: coverage and visits show under their own headings, '
      'visits newest first', (t) async {
    await pump(t, fixtures());
    await settle(t);
    expect(find.text('Coverage'), findsOneWidget);
    expect(find.text('Visits and claims'), findsOneWidget);
    expect(find.text('Medicare Part A (Hospital Insurance)'), findsOneWidget);
    expect(find.text('Medicare Part B (Medical Insurance)'), findsOneWidget);
    expect(
        find.text('Medicare Part D (Prescription Drug Coverage)'),
        findsOneWidget);

    final office = find.text(
        'Office or other outpatient visit, established patient');
    final pneumonia = find.text('Simple pneumonia and pleurisy with CC');
    expect(t.getTopLeft(office).dy, lessThan(t.getTopLeft(pneumonia).dy));
    expect(find.text('July 14, 2026 · Paid'), findsOneWidget);
    expect(find.text('April 18, 2026 · Paid'), findsOneWidget);
    // The entered-in-error claim in the bundle is never shown.
    expect(find.byType(ListTile), findsNWidgets(5));
  });

  testWidgets('TC-MCR-CG-004: a 404 shows the one unavailable message and no '
      'records', (t) async {
    await pump(t, RouteAdapter({}, status: {_visits: 404, _coverage: 404}));
    await settle(t);
    expect(find.text(_unavailable), findsOneWidget);
    expectNoRecords();
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
      'TC-MCR-CG-005: a 403 looks exactly like a 404, so not shared and not '
      'connected can\'t be told apart (FR-MCR-17)', (t) async {
    await pump(t, RouteAdapter({}, status: {_visits: 403, _coverage: 403}));
    await settle(t);
    expect(find.text(_unavailable), findsOneWidget);
    expectNoRecords();
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
      'TC-MCR-CG-006: a refusal on one read hides the other read\'s records',
      (t) async {
    await pump(
        t,
        RouteAdapter({
          _coverage: envelope(fixtureResources('coverage-bundle.json')),
        }, status: {
          _visits: 404
        }));
    await settle(t);
    expect(find.text(_unavailable), findsOneWidget);
    expectNoRecords();
  });

  testWidgets(
      'TC-MCR-CG-007: an expired link (409) is explained in caregiver wording',
      (t) async {
    await pump(t, RouteAdapter({}, status: {_visits: 409, _coverage: 409}));
    await settle(t);
    expect(find.text(_expired), findsOneWidget);
    expect(find.text(_unavailable), findsNothing);
    expect(find.text(_noRecords), findsNothing);
  });

  testWidgets('TC-MCR-CG-008: Medicare unreachable offers Retry', (t) async {
    await pump(t, RouteAdapter({}, status: {_visits: 503, _coverage: 503}));
    await settle(t);
    expect(find.text(_unreachable), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
    expect(find.text(_noRecords), findsNothing);
  });

  testWidgets(
      'TC-MCR-CG-009: Retry reads again and shows the records once Medicare '
      'answers', (t) async {
    // A missing route is a connection error.
    await pump(t, RouteAdapter({}));
    await settle(t);
    expect(find.text(_unreachable), findsOneWidget);

    final a = fixtures();
    ApiClient.instance.debugSetHttpClientAdapter(a);
    await t.tap(find.text('Retry'));
    await t.pump();
    await settle(t);
    expect(a.paths, [_visits, _coverage]);
    expect(find.text(_unreachable), findsNothing);
    expect(find.text('Coverage'), findsOneWidget);
  });

  testWidgets('TC-MCR-CG-010: no records shows "No Medicare records found."',
      (t) async {
    await pump(
        t,
        RouteAdapter({
          _visits: envelope(const []),
          _coverage: envelope(const []),
        }));
    await settle(t);
    expect(find.text(_noRecords), findsOneWidget);
    expectNoRecords();
  });

  testWidgets(
      'TC-MCR-CG-011: synthetic data shows the demo banner; live data does '
      'not', (t) async {
    await pump(t, fixtures());
    await settle(t);
    expect(find.text(_demo), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await pump(t, fixtures(synthetic: false));
    await settle(t);
    expect(find.text(_demo), findsNothing);
    expect(find.text('Coverage'), findsOneWidget);
  });

  testWidgets(
      'TC-MCR-CG-012: tapping a record opens the existing record detail '
      'screen for it', (t) async {
    await pump(t, fixtures());
    await settle(t);
    await t.tap(find.text('Simple pneumonia and pleurisy with CC'));
    await t.pumpAndSettle();
    final details = t.widget<HealthEventDetailsScreen>(
        find.byType(HealthEventDetailsScreen));
    expect(details.record.id, 'inpatient--4411138162');
  });

  testWidgets(
      'TC-MCR-CG-013: no state offers a connect, disconnect or sharing action',
      (t) async {
    final states = <RouteAdapter>[
      fixtures(),
      RouteAdapter({}, status: {_visits: 404, _coverage: 404}),
      RouteAdapter({}, status: {_visits: 409, _coverage: 409}),
      RouteAdapter({}, status: {_visits: 503, _coverage: 503}),
      RouteAdapter({_visits: envelope(const []), _coverage: envelope(const [])}),
    ];
    for (final a in states) {
      await t.pumpWidget(const SizedBox());
      await pump(t, a);
      await settle(t);
      expect(find.textContaining(RegExp('connect', caseSensitive: false)),
          findsNWidgets(a.status.containsValue(409) ? 1 : 0),
          reason: 'only the expired notice may mention connecting');
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining(RegExp('share|disconnect|unlink',
          caseSensitive: false)), findsNothing);
    }
  });

  testWidgets(
      'TC-MCR-CG-014: headings are announced as headings, notices are live '
      'regions, and every target is labelled and at least 48 dp '
      '(WCAG 2.1 SC 1.3.1, 4.1.3, 2.5.5)', (t) async {
    final handle = t.ensureSemantics();
    await pump(t, fixtures());
    await settle(t);
    expect(t.getSemantics(find.text('Coverage')),
        isSemantics(label: 'Coverage', isHeader: true));
    expect(t.getSemantics(find.text('Visits and claims')),
        isSemantics(label: 'Visits and claims', isHeader: true));
    expect(
        find.ancestor(
            of: find.text(_demo),
            matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.liveRegion == true)),
        findsOneWidget);
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));

    // The Retry state too.
    await t.pumpWidget(const SizedBox());
    await pump(t, RouteAdapter({}, status: {_visits: 503, _coverage: 503}));
    await settle(t);
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  for (final theme in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    testWidgets(
        'TC-MCR-CG-015: every text on the tab has at least 4.5:1 contrast in '
        'the ${theme.key} theme (WCAG 2.1 SC 1.4.3)', (t) async {
      await pump(t, fixtures(), theme: theme.value);
      await settle(t);
      var low = lowContrastText(t, find.byType(ListView)).toSet();
      expect(low, isEmpty, reason: low.join('\n'));

      await t.pumpWidget(const SizedBox());
      await pump(t, RouteAdapter({}, status: {_visits: 503, _coverage: 503}),
          theme: theme.value);
      await settle(t);
      low = lowContrastText(t, find.byType(ListView)).toSet();
      expect(low, isEmpty, reason: low.join('\n'));
    });
  }
}
