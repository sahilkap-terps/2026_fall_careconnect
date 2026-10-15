// The patient's passport screen (CC-12 screen 1) against a fake backend that
// behaves like /v1/api/passport: it keeps sharing, the profile and the QR
// code between calls, and works out `ready` the way the backend does.
//
// No Test Plan IDs yet: they are issued by the Testing Lead.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:care_connect_app/features/medical_passport/models/medical_passport.dart';
import 'package:care_connect_app/features/medical_passport/pages/medical_passport_page.dart';

const _base = '/v1/api/passport';

class _Backend {
  _Backend({bool empty = false}) {
    if (empty) {
      passport = {
        'name': 'Sam New',
        'age': null,
        'bloodType': null,
        'chronicConditions': null,
        'emergencyContact': null,
        'allergies': [],
        'medications': [],
        'sharing': {for (final f in PassportField.values) f.apiName: false},
        'token': null,
        'ready': false,
        'lastUpdated': null,
        'lastUpdatedBySection': {},
      };
    }
  }

  Map<String, dynamic> passport = {
    'name': 'Jordan Miller',
    'age': 41,
    'bloodType': 'O_POSITIVE',
    'chronicConditions': 'Type 2 diabetes',
    'emergencyContact': {
      'name': 'Taylor Miller',
      'relationship': 'Spouse',
      'phone': '(415) 555-0184',
    },
    'allergies': [
      {'allergen': 'Penicillin', 'severity': 'SEVERE', 'reaction': 'Anaphylaxis'},
      {'allergen': 'Peanuts', 'severity': 'MODERATE', 'reaction': 'Hives'},
    ],
    'medications': [
      {'name': 'Lisinopril', 'dosage': '10 mg', 'frequency': 'Once daily'},
      {'name': 'Metformin', 'dosage': '500 mg', 'frequency': 'Twice daily'},
    ],
    'sharing': {
      'ALLERGIES': true,
      'MEDICATIONS': true,
      'CHRONIC_CONDITIONS': false,
      'BLOOD_TYPE': true,
      'EMERGENCY_CONTACT': false,
    },
    'token': {'active': true, 'createdAt': '2026-10-01T12:00:00Z', 'lastScannedAt': null},
    'ready': true,
    'lastUpdated': '2026-07-01T09:00:00Z',
    'lastUpdatedBySection': {'MEDICATIONS': '2026-07-01T09:00:00Z'},
  };

  final List<http.Request> requests = [];

  /// One-shot answers by "METHOD path", e.g. "PUT /v1/api/passport/profile".
  final Map<String, http.Response> failures = {};

  List<String> get calls => [for (final r in requests) '${r.method} ${r.url.path}'];

  Future<http.Response> handle(http.Request req) async {
    requests.add(req);
    final key = '${req.method} ${req.url.path}';
    final failure = failures.remove(key);
    if (failure != null) return failure;

    final path = req.url.path;
    if (req.method == 'GET' && path == _base) return _ok();
    if (req.method == 'PUT' && path.startsWith('$_base/visibility/')) {
      final field = path.split('/').last;
      (passport['sharing'] as Map)[field] = (jsonDecode(req.body) as Map)['isPublic'];
      return _ok();
    }
    if (req.method == 'PUT' && path == '$_base/profile') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      passport['bloodType'] = body['bloodType'];
      passport['chronicConditions'] = body['chronicConditions'];
      final name = body['emergencyContactName'];
      final phone = body['emergencyContactPhone'];
      passport['emergencyContact'] = name == null && phone == null
          ? null
          : {'name': name, 'relationship': body['emergencyContactRelationship'], 'phone': phone};
      return _ok();
    }
    if (req.method == 'POST' && path == '$_base/token') {
      passport['token'] = {'active': true, 'createdAt': '2026-10-14T12:00:00Z', 'lastScannedAt': null};
      return http.Response(
          jsonEncode({
            'token': 'new-token',
            'url': 'http://localhost:3000/passport/new-token',
            'createdAt': '2026-10-14T12:00:00Z',
          }),
          201);
    }
    if (req.method == 'DELETE' && path == '$_base/token') {
      passport['token'] = null;
      return http.Response('', 204);
    }
    return http.Response('{"error":"not in fake"}', 404);
  }

  http.Response _ok() {
    final shared = (passport['sharing'] as Map).values.any((v) => v == true);
    passport['ready'] = passport['token'] != null && shared;
    return http.Response(jsonEncode(passport), 200);
  }
}

void _platformChannels() {
  SharedPreferences.setMockInitialValues({});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
}

/// Runs [body] with every HTTP call answered by [backend].
Future<void> _withBackend(_Backend backend, Future<void> Function() body) =>
    http.runWithClient(body, () => MockClient(backend.handle));

Future<void> _open(WidgetTester t, {Size size = const Size(1400, 1400)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(
    initialLocation: '/medical-passport',
    routes: [
      GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('Dashboard'))),
      GoRoute(path: '/medical-passport', builder: (_, __) => const MedicalPassportPage()),
    ],
  );
  await t.pumpWidget(MaterialApp.router(routerConfig: router));
  await t.pumpAndSettle();
}

Finder _switchFor(PassportField field) =>
    find.descendant(of: find.byKey(shareSwitchKey(field)), matching: find.byType(Switch));

void main() {
  setUp(_platformChannels);

  testWidgets('shows everything on file, what is shared, and that the passport is ready',
      (t) async {
    final backend = _Backend();
    await _withBackend(backend, () async {
      await _open(t);

      expect(find.text('Medical passport'), findsWidgets);
      expect(find.text('Jordan Miller'), findsOneWidget);
      expect(find.text('Age 41  ·  Blood type O+'), findsOneWidget);
      expect(find.text('Ready to share'), findsOneWidget);
      expect(find.textContaining('Last updated Jul 1, 2026'), findsOneWidget);
      expect(find.text('Lisinopril 10 mg'), findsOneWidget);
      expect(find.text('Twice daily'), findsOneWidget);
      expect(find.text('Updated Jul 1, 2026'), findsOneWidget);
      expect(find.text('SEVERE'), findsOneWidget);
      expect(find.text('MODERATE'), findsOneWidget);
      expect(find.text('Reaction: Anaphylaxis'), findsOneWidget);
      expect(find.text('Type 2 diabetes'), findsOneWidget);
      expect(find.text('Taylor Miller'), findsOneWidget);
      expect(find.text('Spouse'), findsOneWidget);
      expect(find.text('(415) 555-0184'), findsOneWidget);
      expect(find.text('Show emergency QR'), findsOneWidget);
      expect(find.text('Code active. Not scanned yet.'), findsOneWidget);

      expect(t.widget<Switch>(_switchFor(PassportField.medications)).value, isTrue);
      expect(t.widget<Switch>(_switchFor(PassportField.chronicConditions)).value, isFalse);
      expect(t.widget<Switch>(_switchFor(PassportField.emergencyContact)).value, isFalse);
      expect(backend.calls, ['GET $_base']);
    });
  });

  testWidgets('at phone width the cards stack into one column without overflowing', (t) async {
    await _withBackend(_Backend(), () async {
      await _open(t, size: const Size(390, 3000));

      expect(t.takeException(), isNull);
      final meds = t.getTopLeft(find.text('Medications'));
      final contact = t.getTopLeft(find.text('Emergency contact'));
      expect(contact.dx, closeTo(meds.dx, 1), reason: 'same column');
      expect(contact.dy, greaterThan(meds.dy));
    });
  });

  testWidgets('turning a switch off hides that section and saves it', (t) async {
    final backend = _Backend();
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(_switchFor(PassportField.medications));
      await t.pumpAndSettle();

      expect(backend.calls.last, 'PUT $_base/visibility/MEDICATIONS');
      expect(jsonDecode(backend.requests.last.body), {'isPublic': false});
      expect(t.widget<Switch>(_switchFor(PassportField.medications)).value, isFalse);
    });
  });

  testWidgets('a failed switch change leaves the switch as it was and says so', (t) async {
    final backend = _Backend()
      ..failures['PUT $_base/visibility/EMERGENCY_CONTACT'] = http.Response('', 500);
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(_switchFor(PassportField.emergencyContact));
      await t.pumpAndSettle();

      expect(find.text('Couldn\'t change what\'s shared. Try again.'), findsOneWidget);
      expect(t.widget<Switch>(_switchFor(PassportField.emergencyContact)).value, isFalse);
    });
  });

  testWidgets('a new patient sees empty sections with their switches off and how to get ready',
      (t) async {
    await _withBackend(_Backend(empty: true), () async {
      await _open(t);

      expect(find.text('Not ready'), findsOneWidget);
      expect(find.text('Create your QR code'), findsOneWidget);
      expect(find.text('Nothing added yet'), findsOneWidget);
      expect(find.text('Age 41  ·  Blood type O+'), findsNothing);
      expect(find.text('Blood type not set'), findsOneWidget);
      expect(find.textContaining('No active medications on file'), findsOneWidget);
      expect(find.textContaining('No active allergies on file'), findsOneWidget);
      expect(find.text('No emergency contact added.'), findsOneWidget);
      expect(find.text('Create emergency QR'), findsOneWidget);
      for (final field in PassportField.values) {
        expect(t.widget<Switch>(_switchFor(field)).onChanged, isNull, reason: field.name);
      }
    });
  });

  testWidgets('with a code but nothing shared, it says to share a section', (t) async {
    final backend = _Backend();
    (backend.passport['sharing'] as Map).updateAll((_, __) => false);
    await _withBackend(backend, () async {
      await _open(t);

      expect(find.text('Not ready'), findsOneWidget);
      expect(find.text('Share at least one section'), findsOneWidget);
      expect(find.text('Get ready for an emergency'), findsOneWidget);
    });
  });

  testWidgets('creating the first code shows its QR once, then the passport reloads', (t) async {
    final backend = _Backend(empty: true);
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(find.text('Create emergency QR'));
      await t.pumpAndSettle();

      expect(backend.calls, ['GET $_base', 'POST $_base/token', 'GET $_base']);
      expect(find.text('Your emergency QR code'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('can\'t be shown again'), findsOneWidget);

      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(find.text('Your emergency QR code'), findsNothing);
      expect(find.text('Show emergency QR'), findsOneWidget);
    });
  });

  testWidgets('with a code already active, a new one is only made after the patient agrees',
      (t) async {
    final backend = _Backend();
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(find.text('Show emergency QR'));
      await t.pumpAndSettle();
      expect(find.text('Make a new QR code?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(backend.calls, isNot(contains('POST $_base/token')));

      await t.tap(find.text('Make a new QR code'));
      await t.pumpAndSettle();
      await t.tap(find.text('Make new code'));
      await t.pumpAndSettle();
      expect(backend.calls, contains('POST $_base/token'));
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });

  testWidgets('a failed code shows an error and no QR', (t) async {
    final backend = _Backend(empty: true)
      ..failures['POST $_base/token'] = http.Response('', 500);
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(find.text('Create emergency QR'));
      await t.pumpAndSettle();

      expect(find.text('Couldn\'t make a QR code. Try again.'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });
  });

  testWidgets('turning the code off asks first, then revokes it', (t) async {
    final backend = _Backend();
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(find.text('Turn off QR code'));
      await t.pumpAndSettle();
      await t.tap(find.text('Turn off'));
      await t.pumpAndSettle();

      expect(backend.calls, contains('DELETE $_base/token'));
      expect(find.text('QR code turned off.'), findsOneWidget);
      expect(find.text('Create emergency QR'), findsOneWidget);
      expect(find.text('Not ready'), findsOneWidget);
    });
  });

  testWidgets('a failed turn-off says so', (t) async {
    final backend = _Backend()..failures['DELETE $_base/token'] = http.Response('', 500);
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(find.text('Turn off QR code'));
      await t.pumpAndSettle();
      await t.tap(find.text('Turn off'));
      await t.pumpAndSettle();

      expect(find.text('Couldn\'t turn off the QR code. Try again.'), findsOneWidget);
    });
  });

  testWidgets('editing details starts from what is saved and sends every field', (t) async {
    final backend = _Backend();
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(find.text('Edit details'));
      await t.pumpAndSettle();
      expect(find.text('Edit passport details'), findsOneWidget);
      final phone = find.widgetWithText(TextField, 'Phone');
      expect(t.widget<TextField>(phone).controller!.text, '(415) 555-0184');

      await t.enterText(find.widgetWithText(TextField, 'Name'), '  Dana Miller ');
      await t.enterText(phone, '');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();

      expect(backend.calls.last, 'PUT $_base/profile');
      expect(jsonDecode(backend.requests.last.body), {
        'bloodType': 'O_POSITIVE',
        'chronicConditions': 'Type 2 diabetes',
        'emergencyContactName': 'Dana Miller',
        'emergencyContactRelationship': 'Spouse',
        'emergencyContactPhone': null,
      });
      expect(find.text('Passport details saved.'), findsOneWidget);
      expect(find.text('Dana Miller'), findsOneWidget);
    });
  });

  testWidgets('the blood type can be cleared from the edit dialog', (t) async {
    final backend = _Backend();
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(find.text('Edit details'));
      await t.pumpAndSettle();
      await t.tap(find.text('O+').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Not set').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();

      expect((jsonDecode(backend.requests.last.body) as Map)['bloodType'], isNull);
      expect(find.text('Age 41  ·  Blood type not set'), findsOneWidget);
    });
  });

  testWidgets('cancelling the edit dialog sends nothing', (t) async {
    final backend = _Backend();
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(find.text('Edit').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();

      expect(backend.calls, ['GET $_base']);
    });
  });

  testWidgets('a rejected edit shows the backend\'s reason', (t) async {
    final backend = _Backend()
      ..failures['PUT $_base/profile'] = http.Response(
          jsonEncode({'error': 'emergencyContactPhone must be at most 32 characters'}), 400);
    await _withBackend(backend, () async {
      await _open(t);

      await t.tap(find.text('Edit details'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();

      expect(find.text('emergencyContactPhone must be at most 32 characters'), findsOneWidget);
    });
  });

  testWidgets('a load failure offers a retry that recovers', (t) async {
    final backend = _Backend()..failures['GET $_base'] = http.Response('', 503);
    await _withBackend(backend, () async {
      await _open(t);
      expect(find.text('Couldn\'t load your passport.'), findsOneWidget);

      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();

      expect(find.text('Jordan Miller'), findsOneWidget);
    });
  });

  testWidgets('a non-patient account is told passports are for patients, with no retry',
      (t) async {
    final backend = _Backend()..failures['GET $_base'] = http.Response('', 403);
    await _withBackend(backend, () async {
      await _open(t);

      expect(find.text('Only patients have a medical passport.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });

  testWidgets('an expired session asks the patient to sign in again', (t) async {
    final backend = _Backend()..failures['GET $_base'] = http.Response('', 401);
    await _withBackend(backend, () async {
      await _open(t);

      expect(find.textContaining('Sign in again'), findsOneWidget);
    });
  });

  testWidgets('back goes to the dashboard when there is nothing to pop', (t) async {
    await _withBackend(_Backend(), () async {
      await _open(t);

      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
    });
  });

  testWidgets('switches and status are labelled for screen readers', (t) async {
    final handle = t.ensureSemantics();
    await _withBackend(_Backend(), () async {
      await _open(t);

      expect(find.bySemanticsLabel('Show medications on QR code'), findsOneWidget);
      expect(find.bySemanticsLabel('Passport status: ready to share'), findsOneWidget);
      expect(find.bySemanticsLabel('Call (415) 555-0184'), findsOneWidget);
    });
    handle.dispose();
  });

  test('severity labels read naturally', () {
    expect(severityLabel('LIFE_THREATENING'), 'Life-threatening');
    expect(severityLabel('MILD'), 'Mild');
    expect(severityLabel(null), isNull);
    expect(severityLabel('UNKNOWN'), isNull);
  });
}
