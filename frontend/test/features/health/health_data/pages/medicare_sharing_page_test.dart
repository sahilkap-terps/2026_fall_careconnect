// The patient's Medicare sharing screen (WBS 6.2.59, #323): one switch per
// linked caregiver, saved straight away, put back with an error on failure.
// Test IDs TC-MCR-SHR-* are proposed; the Testing Lead assigns the final ones.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:care_connect_app/config/theme/app_theme.dart';
import 'package:care_connect_app/features/health/health_data/pages/medicare_connect_page.dart';
import 'package:care_connect_app/features/health/health_data/pages/medicare_sharing_page.dart';
import 'package:care_connect_app/features/health/health_data/services/medicare_connect_service.dart';
import 'package:care_connect_app/features/health/health_data/services/medicare_sharing_service.dart';

import '../health_data_test_support.dart';

class _FakeSharing extends MedicareSharingService {
  _FakeSharing(
      {this.caregivers = const [], this.loadError, this.saveOk = true});

  List<SharingCaregiver> caregivers;
  MedicareSharingError? loadError;
  bool saveOk;
  Completer<void>? saveGate;
  int loads = 0;
  final List<(int, bool)> saves = [];

  @override
  Future<List<SharingCaregiver>> load() async {
    loads++;
    if (loadError != null) throw MedicareSharingException(loadError!);
    return caregivers;
  }

  @override
  Future<bool> setShared(int caregiverUserId, bool shared) async {
    saves.add((caregiverUserId, shared));
    if (saveGate != null) await saveGate!.future;
    return saveOk;
  }
}

class _FakeConnect extends MedicareConnectService {
  @override
  Future<MedicareStatus?> status() async =>
      const MedicareStatus(connected: true);
}

const _ann = SharingCaregiver(
    userId: 22, name: 'Ann Lee', email: 'ann@example.test', shared: true);
const _zoe = SharingCaregiver(userId: 21, name: 'Zoe Park', shared: false);

Future<_FakeSharing> _pump(WidgetTester t, _FakeSharing fake,
    {ThemeData? theme}) async {
  final previous = MedicareSharingService.instance;
  MedicareSharingService.instance = fake;
  addTearDown(() => MedicareSharingService.instance = previous);
  await t
      .pumpWidget(MaterialApp(theme: theme, home: const MedicareSharingPage()));
  await t.pumpAndSettle();
  return fake;
}

Finder _switchFor(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(SwitchListTile));

bool _value(WidgetTester t, String name) =>
    t.widget<SwitchListTile>(_switchFor(name)).value;

void main() {
  testWidgets(
      'TC-MCR-SHR-010: each linked caregiver has a switch, and the words '
      '"Sharing" / "Not sharing" show its state', (t) async {
    await _pump(t, _FakeSharing(caregivers: [_ann, _zoe]));

    expect(find.byType(SwitchListTile), findsNWidgets(2));
    expect(_value(t, 'Ann Lee'), isTrue);
    expect(_value(t, 'Zoe Park'), isFalse);
    expect(find.text('Sharing · ann@example.test'), findsOneWidget);
    expect(find.text('Not sharing'), findsOneWidget);
    expect(find.textContaining('coverage and visits'), findsOneWidget);
    expect(find.textContaining('turn sharing off at any time'), findsOneWidget);
  });

  testWidgets(
      'TC-MCR-SHR-011: turning a switch on saves it straight away and '
      'confirms who can now see the information', (t) async {
    final fake = await _pump(t, _FakeSharing(caregivers: [_ann, _zoe]));

    await t.tap(_switchFor('Zoe Park'));
    await t.pumpAndSettle();

    expect(fake.saves, [(21, true)]);
    expect(_value(t, 'Zoe Park'), isTrue);
    expect(find.text('Zoe Park can now see your Medicare coverage and visits.'),
        findsOneWidget);
  });

  testWidgets(
      'TC-MCR-SHR-012: turning a switch off saves it and confirms access ended',
      (t) async {
    final fake = await _pump(t, _FakeSharing(caregivers: [_ann]));

    await t.tap(_switchFor('Ann Lee'));
    await t.pumpAndSettle();

    expect(fake.saves, [(22, false)]);
    expect(_value(t, 'Ann Lee'), isFalse);
    expect(find.text('Ann Lee can no longer see your Medicare information.'),
        findsOneWidget);
  });

  testWidgets(
      'TC-MCR-SHR-013: when a save fails the switch goes back and an error '
      'says nothing changed', (t) async {
    await _pump(t, _FakeSharing(caregivers: [_zoe], saveOk: false));

    await t.tap(_switchFor('Zoe Park'));
    await t.pumpAndSettle();

    expect(_value(t, 'Zoe Park'), isFalse);
    expect(
        find.text('Couldn\'t start sharing with Zoe Park. Nothing changed. '
            'Please try again.'),
        findsOneWidget);
  });

  testWidgets(
      'TC-MCR-SHR-014: a failed stop says the caregiver can still see it',
      (t) async {
    await _pump(t, _FakeSharing(caregivers: [_ann], saveOk: false));

    await t.tap(_switchFor('Ann Lee'));
    await t.pumpAndSettle();

    expect(_value(t, 'Ann Lee'), isTrue);
    expect(find.textContaining('They can still see it.'), findsOneWidget);
  });

  testWidgets(
      'TC-MCR-SHR-015: while a change saves, that switch is disabled and says '
      '"Saving…", so it can\'t be sent twice', (t) async {
    final fake = _FakeSharing(caregivers: [_zoe])..saveGate = Completer<void>();
    await _pump(t, fake);

    await t.tap(_switchFor('Zoe Park'));
    await t.pump();
    expect(t.widget<SwitchListTile>(_switchFor('Zoe Park')).onChanged, isNull);
    expect(find.text('Saving…'), findsOneWidget);

    await t.tap(_switchFor('Zoe Park'));
    await t.pump();
    expect(fake.saves, hasLength(1));

    fake.saveGate!.complete();
    await t.pumpAndSettle();
    expect(
        t.widget<SwitchListTile>(_switchFor('Zoe Park')).onChanged, isNotNull);
  });

  testWidgets(
      'TC-MCR-SHR-016: with no linked caregivers it explains what will '
      'appear here', (t) async {
    await _pump(t, _FakeSharing());
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.textContaining('You don\'t have any linked caregivers yet.'),
        findsOneWidget);
  });

  testWidgets(
      'TC-MCR-SHR-017: a load failure shows an error with Try again, '
      'which reloads', (t) async {
    final fake =
        await _pump(t, _FakeSharing(loadError: MedicareSharingError.network));
    expect(find.textContaining('Couldn\'t reach CareConnect.'), findsOneWidget);

    fake
      ..loadError = null
      ..caregivers = [_zoe];
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();

    expect(fake.loads, 2);
    expect(find.text('Zoe Park'), findsOneWidget);
  });

  testWidgets('TC-MCR-SHR-018: a non-patient sees why and gets no retry',
      (t) async {
    await _pump(t, _FakeSharing(loadError: MedicareSharingError.notPatient));
    expect(
        find.text('Only the patient can choose who sees their Medicare '
            'information.'),
        findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets(
      'TC-MCR-SHR-019: each switch is one focus stop that reads the '
      'caregiver\'s name and its on/off state, with a 48 dp target '
      '(WCAG 2.1 SC 4.1.2, 2.5.5)', (t) async {
    final handle = t.ensureSemantics();
    await _pump(t, _FakeSharing(caregivers: [_ann, _zoe]));

    expect(
      t.getSemantics(_switchFor('Ann Lee')),
      isSemantics(
        label: 'Ann Lee\nSharing · ann@example.test',
        hasToggledState: true,
        isToggled: true,
      ),
    );

    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('TC-MCR-SHR-020: a successful change is announced (live region)',
      (t) async {
    final handle = t.ensureSemantics();
    await _pump(t, _FakeSharing(caregivers: [_zoe]));
    await t.tap(_switchFor('Zoe Park'));
    await t.pumpAndSettle();

    final banner = find.ancestor(
        of: find.textContaining('can now see'),
        matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true));
    expect(banner, findsOneWidget);
    handle.dispose();
  });

  for (final theme in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    testWidgets(
        'TC-MCR-SHR-021: every text on the sharing screen has at least '
        '4.5:1 contrast in the ${theme.key} theme (WCAG 2.1 SC 1.4.3)',
        (t) async {
      await _pump(t, _FakeSharing(caregivers: [_ann, _zoe]),
          theme: theme.value);
      // Include a banner so its colours are checked too.
      await t.tap(_switchFor('Zoe Park'));
      await t.pumpAndSettle();
      final low = lowContrastText(t, find.byType(Scaffold)).toSet();
      expect(low, isEmpty, reason: low.join('\n'));
    });
  }

  testWidgets(
      'TC-MCR-SHR-022: Connect Medicare has a "Share with caregivers" button '
      'that opens the sharing screen', (t) async {
    final previousConnect = MedicareConnectService.instance;
    final previousSharing = MedicareSharingService.instance;
    MedicareConnectService.instance = _FakeConnect();
    MedicareSharingService.instance = _FakeSharing(caregivers: [_zoe]);
    addTearDown(() {
      MedicareConnectService.instance = previousConnect;
      MedicareSharingService.instance = previousSharing;
    });
    final router = GoRouter(initialLocation: '/medicare-connect', routes: [
      GoRoute(
          path: '/medicare-connect',
          builder: (_, __) => const MedicareConnectPage()),
      GoRoute(
          path: '/medicare-sharing',
          builder: (_, __) => const MedicareSharingPage()),
    ]);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();

    await t.tap(find.text('Share with caregivers'));
    await t.pumpAndSettle();

    expect(find.text('Share Medicare'), findsOneWidget);
    expect(find.text('Zoe Park'), findsOneWidget);
  });
}
