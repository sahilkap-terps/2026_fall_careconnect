// CC-12 Increment 2: the patient's own passport calls, the QR link fix and
// the device store. Test Plan IDs to be assigned by the Testing Lead.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:care_connect_app/features/emergency_passport/models/passport_view.dart';
import 'package:care_connect_app/features/emergency_passport/services/passport_service.dart';
import 'package:care_connect_app/features/emergency_passport/services/qr_code_store.dart';

const passportJson = {
  'name': 'Mary Johnson',
  'age': 68,
  'bloodType': 'O_POSITIVE',
  'allergies': [
    {'allergen': 'Penicillin', 'severity': 'MODERATE', 'reaction': 'Rash'},
  ],
  'medications': [],
  'sharing': {
    'ALLERGIES': true,
    'MEDICATIONS': false,
    'CHRONIC_CONDITIONS': false,
    'BLOOD_TYPE': true,
    'EMERGENCY_CONTACT': false,
  },
  'token': {
    'active': true,
    'createdAt': '2026-10-15T17:11:34.932728Z',
    'lastScannedAt': null,
  },
  'ready': true,
  'lastUpdated': '2026-10-15T17:11:12Z',
  'lastUpdatedBySection': {},
};

PassportService _service(
  Future<http.Response> Function(http.Request) handler, {
  Future<Object?> Function()? refresh,
}) =>
    PassportService(
      client: MockClient(handler),
      headers: () async => {'Authorization': 'Bearer test'},
      refresh: refresh ?? () async => null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model', () {
    test('reads sharing, counts and the active code', () {
      final v = PassportView.fromJson(passportJson);
      expect(v.name, 'Mary Johnson');
      expect(v.isShared(PassportField.allergies), isTrue);
      expect(v.isShared(PassportField.bloodType), isTrue);
      expect(v.isShared(PassportField.medications), isFalse);
      expect(v.allergyCount, 1);
      expect(v.code!.createdAt, DateTime.parse('2026-10-15T17:11:34.932728Z'));
      expect(v.code!.lastScannedAt, isNull);
      expect(v.ready, isTrue);
    });

    test('no token means no code', () {
      final v = PassportView.fromJson({...passportJson, 'token': null});
      expect(v.code, isNull);
    });

    test('scanLink adds the # the web app needs, once', () {
      expect(scanLink('http://localhost:3000/passport/abc'),
          'http://localhost:3000/#/passport/abc');
      expect(scanLink('https://app.example.org/passport/abc'),
          'https://app.example.org/#/passport/abc');
      expect(scanLink('https://app.example.org/#/passport/abc'),
          'https://app.example.org/#/passport/abc');
    });
  });

  group('service', () {
    test('GET /v1/api/passport with the sign-in header', () async {
      late http.Request sent;
      final v = await _service((req) async {
        sent = req;
        return http.Response(jsonEncode(passportJson), 200);
      }).getPassport();
      expect(sent.method, 'GET');
      expect(sent.url.path, '/v1/api/passport');
      expect(sent.headers['Authorization'], 'Bearer test');
      expect(v.name, 'Mary Johnson');
    });

    test('POST /token returns the code once, with a working # link', () async {
      late http.Request sent;
      final code = await _service((req) async {
        sent = req;
        return http.Response(
            jsonEncode({
              'token': 'abc',
              'url': 'http://localhost:3000/passport/abc',
              'createdAt': '2026-10-15T18:00:00Z',
            }),
            201);
      }).makeNewCode();
      expect(sent.method, 'POST');
      expect(sent.url.path, '/v1/api/passport/token');
      expect(code.url, 'http://localhost:3000/#/passport/abc');
      expect(code.createdAt, DateTime.utc(2026, 10, 15, 18));
    });

    test('a 401 refreshes the sign-in once and retries', () async {
      var calls = 0;
      final v = await _service((req) async {
        calls++;
        return calls == 1
            ? http.Response('', 401)
            : http.Response(jsonEncode(passportJson), 200);
      }, refresh: () async => 'new session').getPassport();
      expect(calls, 2);
      expect(v.name, 'Mary Johnson');
    });

    for (final c in [
      (401, PassportError.signedOut),
      (403, PassportError.notPatient),
      (409, PassportError.server),
      (500, PassportError.server),
    ]) {
      test('HTTP ${c.$1} -> ${c.$2}', () async {
        expect(
          () => _service((_) async => http.Response('{"error":"x"}', c.$1))
              .makeNewCode(),
          throwsA(isA<PassportException>()
              .having((e) => e.error, 'error', c.$2)),
        );
      });
    }

    test('no answer from the server -> network', () async {
      expect(
        () => _service((_) async => throw http.ClientException('offline'))
            .getPassport(),
        throwsA(isA<PassportException>()
            .having((e) => e.error, 'error', PassportError.network)),
      );
    });
  });

  group('store', () {
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final memory = <String, String>{};

    setUp(() {
      memory.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        final args = (call.arguments as Map?) ?? const {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'write':
            memory[key!] = args['value'] as String;
            return null;
          case 'read':
            return memory[key];
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('keeps one code per patient', () async {
      final a = QrCodeStore(patientId: () async => 1);
      final b = QrCodeStore(patientId: () async => 2);
      await a.save(StoredQrCode(
          url: 'http://x/#/passport/a', createdAt: DateTime.utc(2026, 10, 15)));
      final readA = await a.read();
      expect(readA!.url, 'http://x/#/passport/a');
      expect(readA.createdAt, DateTime.utc(2026, 10, 15));
      expect(await b.read(), isNull);
    });

    test('no patient id: nothing is kept or read', () async {
      final s = QrCodeStore(patientId: () async => null);
      await s.save(StoredQrCode(url: 'u', createdAt: DateTime.utc(2026)));
      expect(memory, isEmpty);
      expect(await s.read(), isNull);
    });
  });
}
