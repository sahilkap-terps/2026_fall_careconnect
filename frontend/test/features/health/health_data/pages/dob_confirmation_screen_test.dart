// DOB confirmation (identity reconciliation UI). Backend vocabulary:
// EhrConflictStatus PENDING / ACCEPTED / REJECTED, PENDING only for
// date_of_birth (ck_ehr_identity_conflict_pending_dob).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:care_connect_app/config/theme/app_theme.dart';

import 'package:care_connect_app/features/health/health_data/models/identity_conflict.dart';
import 'package:care_connect_app/features/health/health_data/pages/dob_confirmation_screen.dart';
import 'package:care_connect_app/features/health/health_data/services/identity_conflict_service.dart';

import '../health_data_test_support.dart';

IdentityConflict _dob(int id,
        {String before = '1980-05-14',
        String incoming = '1985-05-14',
        ConflictStatus status = ConflictStatus.pending,
        IdentityCheck? check}) =>
    IdentityConflict(
      id: id,
      fieldName: 'date_of_birth',
      canonicalValueBefore: before,
      incomingValue: incoming,
      canonicalSourceLabel: 'Epic',
      incomingSourceLabel: 'Cerner',
      status: status,
      identityCheck: check,
    );

class _FakeConflicts extends IdentityConflictService {
  _FakeConflicts(this.pending,
      {this.resolveResult = true, this.throwOnResolve, this.throwOnFetch})
      : super(useMock: false);

  final List<IdentityConflict> pending;
  final Object? throwOnFetch;
  final bool resolveResult;
  final Object? throwOnResolve;
  final resolved = <String>[];

  @override
  Future<List<IdentityConflict>> fetchPending() async {
    if (throwOnFetch != null) throw throwOnFetch!;
    return pending;
  }

  @override
  Future<bool> resolve(int conflictId, {required bool accepted}) async {
    resolved.add('$conflictId:${accepted ? 'ACCEPTED' : 'REJECTED'}');
    if (throwOnResolve != null) throw throwOnResolve!;
    return resolveResult;
  }
}

Future<void> _pump(WidgetTester t, IdentityConflictService s) async {
  await t.pumpWidget(MaterialApp(home: DobConfirmationScreen(service: s)));
  await t.pumpAndSettle();
}

/// Scrolls [f] into view first: the question makes the card taller, so its
/// buttons can be below the edge of the 800x600 test screen.
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
}

void main() {
  testWidgets('TC-EHR-REC-032: only pending date-of-birth conflicts are '
      'listed, each with current and new values and their sources',
      (t) async {
    await _pump(
        t,
        _FakeConflicts([
          _dob(1),
          _dob(2, status: ConflictStatus.rejected, incoming: '1990-01-01'),
          const IdentityConflict(
              id: 3,
              fieldName: 'gender',
              canonicalValueBefore: 'female',
              incomingValue: 'unknown'),
        ]));
    expect(find.text('1 item needs your confirmation'), findsOneWidget);
    expect(find.text('Which date of birth is correct?'), findsOneWidget);
    expect(find.text('1980-05-14'), findsOneWidget);
    expect(find.text('1985-05-14'), findsOneWidget);
    expect(find.text('From Epic'), findsOneWidget);
    expect(find.text('From Cerner'), findsOneWidget);
    expect(find.text('1990-01-01'), findsNothing);
    expect(find.text('unknown'), findsNothing);
  });

  testWidgets('TC-EHR-REC-033: Keep current rejects the incoming value, '
      'removes the card and confirms', (t) async {
    final s = _FakeConflicts([_dob(7)]);
    await _pump(t, s);
    await t.tap(find.text('Keep current'));
    await t.pumpAndSettle();
    expect(s.resolved, ['7:REJECTED']);
    expect(find.text('Which date of birth is correct?'), findsNothing);
    expect(find.text('Kept your current date of birth.'), findsOneWidget);
  });

  testWidgets('TC-EHR-REC-034: Use new date accepts the incoming value, '
      'removes the card and confirms', (t) async {
    final s = _FakeConflicts([_dob(8)]);
    await _pump(t, s);
    await t.tap(find.text('Use new date'));
    await t.pumpAndSettle();
    expect(s.resolved, ['8:ACCEPTED']);
    expect(find.text('Which date of birth is correct?'), findsNothing);
    expect(find.text('Date of birth updated.'), findsOneWidget);
  });

  testWidgets('TC-EHR-REC-035: when the choice is not saved the card stays '
      'and the patient is told', (t) async {
    final s = _FakeConflicts([_dob(9)], resolveResult: false);
    await _pump(t, s);
    await t.tap(find.text('Use new date'));
    await t.pumpAndSettle();
    expect(s.resolved, ['9:ACCEPTED']);
    expect(find.text('Which date of birth is correct?'), findsOneWidget);
    expect(find.text('Date of birth updated.'), findsNothing);
    expect(find.textContaining(RegExp('couldn.t save')), findsOneWidget);
  });

  testWidgets('TC-EHR-REC-036: when saving fails with an error the buttons '
      'come back and the patient is told', (t) async {
    final s = _FakeConflicts([_dob(10)], throwOnResolve: Exception('offline'));
    await _pump(t, s);
    await t.tap(find.text('Keep current'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Keep current'), findsOneWidget);
    expect(find.textContaining(RegExp('couldn.t save')), findsOneWidget);
  });

  testWidgets('TC-EHR-REC-037: with nothing pending the screen says the '
      'patient is all caught up', (t) async {
    await _pump(t, _FakeConflicts(const []));
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(find.text('Which date of birth is correct?'), findsNothing);
  });

  test('TC-EHR-REC-038: IdentityConflict.fromJson reads camelCase and '
      'snake_case and the backend status vocabulary', () {
    final camel = IdentityConflict.fromJson({
      'id': 4,
      'fieldName': 'date_of_birth',
      'canonicalValueBefore': '1980-05-14',
      'incomingValue': '1985-05-14',
      'status': 'ACCEPTED',
      'detectedAt': '2026-09-26T10:00:00Z',
    });
    expect(camel.id, 4);
    expect(camel.isDob, isTrue);
    expect(camel.status, ConflictStatus.accepted);
    expect(camel.detectedAt, DateTime.utc(2026, 9, 26, 10));
    final snake = IdentityConflict.fromJson({
      'id': 5,
      'field_name': 'date_of_birth',
      'canonical_value_before': '1980-05-14',
      'incoming_value': '1985-05-14',
      'status': 'REJECTED',
    });
    expect(snake.canonicalValueBefore, '1980-05-14');
    expect(snake.incomingValue, '1985-05-14');
    expect(snake.status, ConflictStatus.rejected);
    expect(IdentityConflict.fromJson({'status': 'PENDING'}).isPending, isTrue);
  });

  for (final theme in {
    'default': null,
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    testWidgets('TC-EHR-REC-039: every text on the screen has at least 4.5:1 '
        'contrast against what is behind it, in the ${theme.key} theme '
        '(WCAG 2.1 SC 1.4.3)', (t) async {
      await t.pumpWidget(MaterialApp(
          theme: theme.value,
          home: DobConfirmationScreen(service: _FakeConflicts([_dob(1)]))));
      await t.pumpAndSettle();
      final low = lowContrastText(t, find.byType(ListView));
      expect(low, isEmpty, reason: low.join('\n'));
    });
  }

  testWidgets('TC-EHR-REC-045: DOB load failure says so instead of "all caught up", and '
      'offers Try again (#263 review)', (t) async {
    await _pump(t, _FakeConflicts([_dob(1)], throwOnFetch: Exception('down')));
    expect(find.text('We couldn\u2019t check your information'), findsOneWidget);
    expect(find.textContaining('all caught up'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  test('TC-EHR-REC-046: with the mock off, resolve never reports a save that did not happen '
      '(#263 review)', () async {
    expect(await IdentityConflictService(useMock: false).resolve(1, accepted: true),
        isFalse);
  });

  // M3 feedback: name and date of birth can match two people, so before the
  // date choice the patient confirms one more detail from the new record:
  // phone (last 4 digits), else email (name part hidden), else ZIP code.

  final phone = IdentityCheck.of(IdentityCheckType.phone, '4821');
  final email = IdentityCheck.of(IdentityCheckType.email, 'jane.doe@gmail.com');
  final zip = IdentityCheck.of(IdentityCheckType.zip, '21201');

  testWidgets('TC-EHR-REC-070: with a phone number on the new record, the '
      'patient is asked about it first (old numbers count) and the date '
      'buttons wait', (t) async {
    await _pump(t, _FakeConflicts([_dob(1, check: phone)]));
    expect(find.text('Is this a phone number you use now or used before?'),
        findsOneWidget);
    expect(
        find.text('The new record from Cerner has a phone number ending in 4821.'),
        findsOneWidget);
    expect(find.textContaining('Choose Yes if it’s an old number of yours.'),
        findsOneWidget);
    expect(find.text('Not mine'), findsOneWidget);
    expect(find.text('Yes, it’s mine'), findsOneWidget);
    expect(find.text('Use new date'), findsNothing);
    expect(find.text('Keep current'), findsNothing);
  });

  testWidgets('TC-EHR-REC-071: "Yes, it\'s mine" shows the date choice, '
      'and nothing is saved until the patient picks', (t) async {
    final s = _FakeConflicts([_dob(2, check: phone)]);
    await _pump(t, s);
    await _tap(t, find.text('Yes, it’s mine'));
    await t.pumpAndSettle();
    expect(s.resolved, isEmpty);
    expect(find.textContaining('phone number you use'), findsNothing);
    expect(find.textContaining('double-check'), findsNothing);
    await _tap(t, find.text('Use new date'));
    await t.pumpAndSettle();
    expect(s.resolved, ['2:ACCEPTED']);
    expect(find.text('Date of birth updated.'), findsOneWidget);
  });

  testWidgets('TC-EHR-REC-072: "Not mine" keeps the current date, removes '
      'the card and says the record may not be theirs', (t) async {
    final s = _FakeConflicts([_dob(3, check: phone)]);
    await _pump(t, s);
    await _tap(t, find.text('Not mine'));
    await t.pumpAndSettle();
    expect(s.resolved, ['3:REJECTED']);
    expect(find.text('Which date of birth is correct?'), findsNothing);
    expect(find.text('Nothing was changed. This record may not be yours.'),
        findsOneWidget);
  });

  testWidgets('TC-EHR-REC-073: when "Not mine" is not saved, the card and '
      'the question stay and the patient is told', (t) async {
    final s = _FakeConflicts([_dob(4, check: phone)], resolveResult: false);
    await _pump(t, s);
    await _tap(t, find.text('Not mine'));
    await t.pumpAndSettle();
    expect(s.resolved, ['4:REJECTED']);
    expect(find.textContaining('phone number you use'), findsOneWidget);
    expect(find.textContaining('may not be yours'), findsNothing);
    expect(find.textContaining(RegExp('couldn.t save')), findsOneWidget);
  });

  testWidgets('TC-EHR-REC-074: with no phone, email or ZIP code on the new '
      'record, the date choice shows with a warning', (t) async {
    await _pump(t, _FakeConflicts([_dob(5)]));
    expect(find.text('Not mine'), findsNothing);
    expect(
        find.text('We couldn’t double-check that this record is yours. '
            'Only choose Use new date if you’re sure.'),
        findsOneWidget);
    expect(find.text('Use new date'), findsOneWidget);
    expect(find.text('Keep current'), findsOneWidget);
  });

  testWidgets('TC-EHR-REC-075: each card asks about its own detail',
      (t) async {
    await _pump(
        t,
        _FakeConflicts([
          _dob(6, check: IdentityCheck.of(IdentityCheckType.phone, '1111')),
          _dob(7,
              check: IdentityCheck.of(IdentityCheckType.phone, '2222'),
              incoming: '1990-02-02'),
        ]));
    await _tap(t, find.text('Yes, it’s mine').first);
    await t.pumpAndSettle();
    expect(find.text('Not mine'), findsOneWidget);
    expect(find.textContaining('ending in 2222'), findsOneWidget);
    expect(find.textContaining('ending in 1111'), findsNothing);
  });

  testWidgets('TC-EHR-REC-081: with no phone, the email is asked about, '
      'with its name part hidden', (t) async {
    final s = _FakeConflicts([_dob(8, check: email)]);
    await _pump(t, s);
    expect(find.text('Is this an email you use now or used before?'),
        findsOneWidget);
    expect(find.text('The new record from Cerner has the email j•••@gmail.com.'),
        findsOneWidget);
    expect(find.textContaining('jane.doe'), findsNothing);
    expect(find.text('Use new date'), findsNothing);
    await _tap(t, find.text('Yes, it’s mine'));
    await t.pumpAndSettle();
    expect(find.text('Use new date'), findsOneWidget);
  });

  testWidgets('TC-EHR-REC-082: with no phone or email, the ZIP code is '
      'asked about, and "Not mine" changes nothing', (t) async {
    final s = _FakeConflicts([_dob(9, check: zip)]);
    await _pump(t, s);
    expect(find.text('Do you live, or did you live, in this ZIP code?'),
        findsOneWidget);
    expect(find.text('The new record from Cerner has the ZIP code 21201.'),
        findsOneWidget);
    await _tap(t, find.text('Not mine'));
    await t.pumpAndSettle();
    expect(s.resolved, ['9:REJECTED']);
    expect(find.text('Nothing was changed. This record may not be yours.'),
        findsOneWidget);
  });

  testWidgets('TC-EHR-REC-083: without a source name the question still '
      'reads well', (t) async {
    await _pump(
        t,
        _FakeConflicts([
          IdentityConflict(
              id: 10,
              fieldName: 'date_of_birth',
              canonicalValueBefore: '1980-05-14',
              incomingValue: '1985-05-14',
              identityCheck: phone),
        ]));
    expect(find.text('The new record has a phone number ending in 4821.'),
        findsOneWidget);
  });

  for (final theme in {
    'default': null,
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    for (final c in {
      'phone question': phone,
      'email question': email,
      'ZIP question': zip,
      'no-check warning': null,
    }.entries) {
      testWidgets('TC-EHR-REC-076: the ${c.key} has at least 4.5:1 contrast '
          'in the ${theme.key} theme (WCAG 2.1 SC 1.4.3)', (t) async {
        await t.pumpWidget(MaterialApp(
            theme: theme.value,
            home: DobConfirmationScreen(
                service: _FakeConflicts([_dob(1, check: c.value)]))));
        await t.pumpAndSettle();
        final low = lowContrastText(t, find.byType(ListView));
        expect(low, isEmpty, reason: low.join('\n'));
      });
    }
  }
}
