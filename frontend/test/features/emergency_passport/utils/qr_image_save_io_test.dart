// CC-12 Increment 2: saving the QR picture on a phone (share sheet). Test
// Plan IDs to be assigned by the Testing Lead.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:care_connect_app/features/emergency_passport/utils/qr_image_save_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  const share = MethodChannel('dev.fluttercommunity.plus/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory temp;
  late List<MethodCall> shared;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cc12_qr_');
    shared = [];
    messenger.setMockMethodCallHandler(pathProvider, (call) async {
      if (call.method == 'getTemporaryDirectory') return temp.path;
      return null;
    });
    messenger.setMockMethodCallHandler(share, (call) async {
      shared.add(call);
      return 'dev.fluttercommunity.plus/share/success';
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathProvider, null);
    messenger.setMockMethodCallHandler(share, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('writes the picture and opens the share sheet with it', () async {
    final png = Uint8List.fromList([137, 80, 78, 71]);
    final ok = await saveQrImage(png, 'careconnect-emergency-qr.png');

    expect(ok, isTrue);
    final file = File('${temp.path}/careconnect-emergency-qr.png');
    expect(file.readAsBytesSync(), png);
    expect(shared, hasLength(1));
  });

  test('a share sheet that fails gives false, not a crash', () async {
    messenger.setMockMethodCallHandler(share, (call) async {
      throw PlatformException(code: 'error');
    });
    expect(await saveQrImage(Uint8List(4), 'x.png'), isFalse);
  });
}
