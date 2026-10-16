// CC-12 Increment 2: the lock screen QR picture. Test Plan IDs to be
// assigned by the Testing Lead.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:care_connect_app/features/emergency_passport/utils/qr_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('makes a phone-shaped PNG (1080 x 1920) with the code drawn on it',
      () async {
    final png = await lockScreenQrPng('http://localhost:3000/#/passport/abc');

    // PNG signature.
    expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);

    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    expect(image.width, 1080);
    expect(image.height, 1920);

    // The middle of the QR area is not all white: the code is drawn.
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    var dark = 0;
    for (var y = 700; y < 1300; y += 10) {
      for (var x = 200; x < 880; x += 10) {
        final i = (y * 1080 + x) * 4;
        if (bytes.getUint8(i) < 128) dark++;
      }
    }
    expect(dark, greaterThan(100));
  });

  test('different codes give different pictures', () async {
    final a = await lockScreenQrPng('http://localhost:3000/#/passport/aaa');
    final b = await lockScreenQrPng('http://localhost:3000/#/passport/bbb');
    expect(a, isNot(equals(b)));
  });
}
