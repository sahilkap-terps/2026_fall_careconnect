// CC-12 Increment 2: keeping the QR code on the device. Test Plan IDs to be assigned by the Testing Lead.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:care_connect_app/features/emergency_passport/services/qr_code_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('a damaged or incomplete entry reads as nothing kept', () async {
    final s = QrCodeStore(patientId: () async => 3);
    memory['cc12_emergency_qr_3'] = 'not json';
    expect(await s.read(), isNull);
    memory['cc12_emergency_qr_3'] = '{"url":"","createdAt":"2026-10-15T00:00:00Z"}';
    expect(await s.read(), isNull);
    memory['cc12_emergency_qr_3'] = '{"url":"u","createdAt":"not a date"}';
    expect(await s.read(), isNull);
  });

  test('storage that fails to write does not break the screen', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    final s = QrCodeStore(patientId: () async => 4);
    await s.save(StoredQrCode(url: 'u', createdAt: DateTime.utc(2026)));
    expect(await s.read(), isNull);
  });
}
