// CC-12 Increment 2: the public scan call and the data it returns.
// Test Plan IDs to be assigned by the Testing Lead.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:care_connect_app/features/emergency_passport/models/public_passport.dart';
import 'package:care_connect_app/features/emergency_passport/services/passport_scan_service.dart';

import 'passport_test_support.dart';


PassportScanService _service(
        Future<http.Response> Function(http.Request) handler) =>
    PassportScanService(client: MockClient(handler));

void main() {
  test('an active code returns every shared section, read without sign-in',
      () async {
    late http.Request sent;
    final result = await _service((req) async {
      sent = req;
      return http.Response(jsonEncode(fullPassport), 200);
    }).scan('abc123');

    expect(sent.method, 'GET');
    expect(sent.url.path, '/v1/api/passport/scan/abc123');
    expect(sent.headers.containsKey('Authorization'), isFalse);

    final p = (result as ScanShown).passport;
    expect(p.name, 'Jordan Miller');
    expect(p.age, 41);
    expect(p.bloodType, 'O_POSITIVE');
    expect(p.allergies!.map((a) => a.allergen), ['Penicillin', 'Peanuts', 'Latex']);
    expect(p.allergies!.first.severity, 'LIFE_THREATENING');
    expect(p.allergies!.last.severity, isNull);
    expect(p.medications!.single.dosage, '10 mg');
    expect(p.chronicConditions, 'Type 2 diabetes');
    expect(p.emergencyContact!.phone, '(415) 555-0184');
    expect(p.lastUpdated, DateTime.utc(2026, 10, 13, 15));
    expect(p.sharesNothing, isFalse);
  });

  test('name and age only means nothing else was shared, and there is no date',
      () async {
    final result = await _service((_) async =>
            http.Response(jsonEncode({'name': 'Jordan Miller', 'age': 41}), 200))
        .scan('abc123');
    final p = (result as ScanShown).passport;
    expect(p.sharesNothing, isTrue);
    expect(p.allergies, isNull);
    expect(p.lastUpdated, isNull);
  });

  for (final c in [
    (404, '{"status":"NOT_ACTIVE"}', ScanNotActive),
    (429, '{"status":"RATE_LIMITED"}', ScanRateLimited),
    (500, '{"error":"x"}', ScanFailed),
    (200, 'not json', ScanFailed),
    (200, '[]', ScanFailed),
  ]) {
    test('HTTP ${c.$1} with body ${c.$2} -> ${c.$3}', () async {
      final result = await _service((_) async => http.Response(c.$2, c.$1))
          .scan('abc123');
      expect(result.runtimeType, c.$3);
    });
  }

  test('no answer from the server -> ScanFailed', () async {
    final result = await _service((_) async => throw http.ClientException('offline'))
        .scan('abc123');
    expect(result, isA<ScanFailed>());
  });

  test('an empty code is not active and makes no call', () async {
    var calls = 0;
    final result = await _service((_) async {
      calls++;
      return http.Response('', 200);
    }).scan('  ');
    expect(result, isA<ScanNotActive>());
    expect(calls, 0);
  });

  test('the code is sent as one path segment', () async {
    late Uri url;
    await _service((req) async {
      url = req.url;
      return http.Response('{"status":"NOT_ACTIVE"}', 404);
    }).scan('a/b?c');
    expect(url.pathSegments.last, 'a/b?c');
    expect(url.query, isEmpty);
  });

  test('labels', () {
    expect(bloodTypeLabel('O_POSITIVE'), 'O+');
    expect(bloodTypeLabel('AB_NEGATIVE'), 'AB−');
    expect(bloodTypeSpoken('AB_NEGATIVE'), 'AB negative');
    expect(severityLabel('LIFE_THREATENING'), 'Life-threatening');
    expect(severityLabel('MILD'), 'Mild');
    expect(severityLabel(null), isNull);
  });
}
