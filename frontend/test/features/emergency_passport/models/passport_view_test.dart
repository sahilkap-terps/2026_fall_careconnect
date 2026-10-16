// CC-12 Increment 2: the patient's own passport model and the QR link fix. Test Plan IDs to be assigned by the Testing Lead.

import 'package:flutter_test/flutter_test.dart';

import 'package:care_connect_app/features/emergency_passport/models/passport_view.dart';

import '../passport_test_support.dart';

void main() {
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
}
