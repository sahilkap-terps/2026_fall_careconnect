// CC-12 Increment 2: saving the QR picture in a browser (a download).
// Test Plan §3.27: TC-EMG-304 (Testing Lead).
//
// The file under test uses dart:js_interop and package:web, so it runs only
// in a browser: `flutter test --platform chrome <this file>`. On the VM (CI's
// `flutter test`) the runner skips this file, so it gives CI's test mapping
// its test without breaking the run, but CI's coverage gate still scores
// qr_image_save_web.dart at 0% (Test Plan §3.27, §11).
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// package:web comes with Flutter's web support, as in qr_image_save_web.dart.
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

import 'package:care_connect_app/features/emergency_passport/utils/qr_image_save_web.dart';

void main() {
  test(
      'TC-EMG-304: in a browser the picture is downloaded once, as '
      'careconnect-emergency-qr.png from a PNG blob, and no link is left on '
      'the page', () async {
    final clicks = <web.HTMLAnchorElement>[];
    final listener = ((web.Event e) {
      final target = e.target;
      if (target != null && target.isA<web.HTMLAnchorElement>()) {
        clicks.add(target as web.HTMLAnchorElement);
        e.preventDefault(); // record the download without saving a file
      }
    }).toJS;
    web.document.addEventListener('click', listener, true.toJS);
    addTearDown(
        () => web.document.removeEventListener('click', listener, true.toJS));

    final anchorsBefore = web.document.querySelectorAll('a').length;
    final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
    final ok = await saveQrImage(png, 'careconnect-emergency-qr.png');

    expect(ok, isTrue);
    expect(clicks, hasLength(1));
    expect(clicks.single.download, 'careconnect-emergency-qr.png');
    expect(clicks.single.href, startsWith('blob:'));
    expect(web.document.querySelectorAll('a').length, anchorsBefore);
  });
}
