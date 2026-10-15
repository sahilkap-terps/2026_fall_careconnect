// MedicalPassportService against a MockClient, the pattern of
// consent_api_service_test.dart: each call's method, path and body, and how
// errors surface.
//
// No Test Plan IDs yet: they are issued by the Testing Lead.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:care_connect_app/features/medical_passport/models/medical_passport.dart';
import 'package:care_connect_app/features/medical_passport/services/medical_passport_service.dart';

const _passport = {
  'name': 'Jordan Miller',
  'age': 41,
  'allergies': [],
  'medications': [],
  'sharing': {'ALLERGIES': true},
  'token': null,
  'ready': false,
};

Future<T> _with<T>(
  Future<T> Function() call,
  Future<http.Response> Function(http.Request) handler,
) =>
    http.runWithClient(call, () => MockClient(handler));

void main() {
  test('fetch GETs /v1/api/passport and parses it', () async {
    late http.Request sent;
    final p = await _with(MedicalPassportService.fetch, (req) async {
      sent = req;
      return http.Response(jsonEncode(_passport), 200);
    });

    expect(sent.method, 'GET');
    expect(sent.url.path, '/v1/api/passport');
    expect(sent.headers['Accept'], 'application/json');
    expect(p.name, 'Jordan Miller');
    expect(p.isShared(PassportField.allergies), isTrue);
  });

  test('setShared PUTs isPublic to the field\'s API name', () async {
    late http.Request sent;
    await _with(() => MedicalPassportService.setShared(PassportField.chronicConditions, false),
        (req) async {
      sent = req;
      return http.Response(jsonEncode(_passport), 200);
    });

    expect(sent.method, 'PUT');
    expect(sent.url.path, '/v1/api/passport/visibility/CHRONIC_CONDITIONS');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {'isPublic': false});
  });

  test('updateProfile PUTs every field', () async {
    late http.Request sent;
    await _with(
        () => MedicalPassportService.updateProfile(const PassportProfileUpdate(
              bloodType: BloodType.abNegative,
              contactName: 'Dana',
            )), (req) async {
      sent = req;
      return http.Response(jsonEncode(_passport), 200);
    });

    expect(sent.method, 'PUT');
    expect(sent.url.path, '/v1/api/passport/profile');
    expect(jsonDecode(sent.body), {
      'bloodType': 'AB_NEGATIVE',
      'chronicConditions': null,
      'emergencyContactName': 'Dana',
      'emergencyContactRelationship': null,
      'emergencyContactPhone': null,
    });
  });

  test('createCode POSTs /token and returns the one-time link', () async {
    late http.Request sent;
    final code = await _with(MedicalPassportService.createCode, (req) async {
      sent = req;
      return http.Response(
          jsonEncode({'token': 't0k', 'url': 'http://x/passport/t0k', 'createdAt': null}), 201);
    });

    expect(sent.method, 'POST');
    expect(sent.url.path, '/v1/api/passport/token');
    expect(code.url, 'http://x/passport/t0k');
  });

  test('revokeCode DELETEs /token and accepts an empty 204', () async {
    late http.Request sent;
    await _with(MedicalPassportService.revokeCode, (req) async {
      sent = req;
      return http.Response('', 204);
    });

    expect(sent.method, 'DELETE');
    expect(sent.url.path, '/v1/api/passport/token');
  });

  group('errors', () {
    test('a 400 carries the backend\'s error text', () async {
      final error = await _with(
        () => MedicalPassportService.updateProfile(const PassportProfileUpdate())
            .then<Object?>((_) => null, onError: (Object e) => e),
        (_) async => http.Response(jsonEncode({'error': 'emergencyContactPhone must be at most 32 characters'}), 400),
      );

      expect(error, isA<MedicalPassportException>());
      final e = error as MedicalPassportException;
      expect(e.statusCode, 400);
      expect(e.message, 'emergencyContactPhone must be at most 32 characters');
      expect(e.toString(), contains('400'));
    });

    test('403 is "not a patient" and 401 is "signed out"; an empty body has no message', () async {
      Future<MedicalPassportException> failWith(int status) => _with(
            () => MedicalPassportService.fetch().then<MedicalPassportException>(
                (_) => fail('expected an error'),
                onError: (Object e) => e as MedicalPassportException),
            (_) async => http.Response('', status),
          );

      final forbidden = await failWith(403);
      expect(forbidden.notAPatient, isTrue);
      expect(forbidden.signedOut, isFalse);
      expect(forbidden.message, isNull);

      final unauthorized = await failWith(401);
      expect(unauthorized.signedOut, isTrue);
      expect(unauthorized.notAPatient, isFalse);
    });

    test('a non-object body is a FormatException', () async {
      await expectLater(
        _with(MedicalPassportService.fetch, (_) async => http.Response('[]', 200)),
        throwsA(isA<FormatException>()),
      );
    });

    test('a revoke that fails throws', () async {
      await expectLater(
        _with(MedicalPassportService.revokeCode, (_) async => http.Response('{"error":"nope"}', 500)),
        throwsA(isA<MedicalPassportException>().having((e) => e.message, 'message', 'nope')),
      );
    });
  });
}
