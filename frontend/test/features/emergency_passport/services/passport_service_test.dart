// CC-12 Increment 2: the patient's own passport calls. Test Plan IDs to be assigned by the Testing Lead.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:care_connect_app/features/emergency_passport/services/passport_service.dart';

import '../passport_test_support.dart';

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
}
