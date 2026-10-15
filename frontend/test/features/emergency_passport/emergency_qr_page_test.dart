// CC-12 Increment 2: the patient's emergency QR screen (design screen 2).
// Test Plan IDs to be assigned by the Testing Lead.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:care_connect_app/features/emergency_passport/models/passport_view.dart';
import 'package:care_connect_app/features/emergency_passport/pages/emergency_qr_page.dart';
import 'package:care_connect_app/features/emergency_passport/services/passport_service.dart';
import 'package:care_connect_app/features/emergency_passport/services/qr_code_store.dart';

final _created = DateTime.utc(2026, 10, 15, 17);

PassportView _view({bool withCode = true, DateTime? lastScanned}) => PassportView(
      name: 'Mary Johnson',
      sharing: const {
        PassportField.bloodType: true,
        PassportField.allergies: true,
        PassportField.medications: false,
        PassportField.emergencyContact: true,
        PassportField.chronicConditions: false,
      },
      code: withCode
          ? QrCodeStatus(createdAt: _created, lastScannedAt: lastScanned)
          : null,
      ready: withCode,
    );

class _FakeService extends PassportService {
  _FakeService({required this.view, this.loadError, this.makeError})
      : super(headers: () async => {}, refresh: () async => null);

  final PassportView view;
  final PassportError? loadError;
  final PassportError? makeError;
  int loads = 0;
  int made = 0;

  @override
  Future<PassportView> getPassport() async {
    loads++;
    if (loadError != null && loads == 1) throw PassportException(loadError!);
    return view;
  }

  @override
  Future<NewQrCode> makeNewCode() async {
    if (makeError != null) throw PassportException(makeError!);
    made++;
    return NewQrCode(
      token: 'new$made',
      url: 'http://localhost:3000/#/passport/new$made',
      createdAt: DateTime.utc(2026, 10, 16, 9),
    );
  }
}

class _MemoryStore extends QrCodeStore {
  _MemoryStore([this.code]) : super(patientId: () async => 1);
  StoredQrCode? code;

  @override
  Future<StoredQrCode?> read() async => code;

  @override
  Future<void> save(StoredQrCode c) async => code = c;
}

class _Saver {
  final calls = <(String, String)>[];
  bool result = true;

  Future<Uint8List> make(String data) async {
    calls.add((data, ''));
    return Uint8List.fromList([1, 2, 3]);
  }

  Future<bool> save(Uint8List png, String fileName) async {
    calls.add(('', fileName));
    return result;
  }
}

Future<void> _open(WidgetTester t, _FakeService service, _MemoryStore store,
    {_Saver? saver}) async {
  await t.binding.setSurfaceSize(const Size(420, 2000));
  addTearDown(() => t.binding.setSurfaceSize(null));
  final s = saver ?? _Saver();
  await t.pumpWidget(MaterialApp(
    home: EmergencyQrPage(
      service: service,
      store: store,
      makeImage: s.make,
      saveImage: s.save,
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('no code yet: Create my emergency QR makes one, shows and keeps it',
      (t) async {
    final service = _FakeService(view: _view(withCode: false));
    final store = _MemoryStore();
    await _open(t, service, store);

    expect(find.text('You don\'t have an emergency QR yet'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    await t.tap(find.text('Create my emergency QR'));
    await t.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing); // nothing to replace
    expect(service.made, 1);
    expect(store.code!.url, 'http://localhost:3000/#/passport/new1');
    final qr = t.widget<QrImageView>(find.byType(QrImageView));
    expect(qr, isNotNull);
    expect(find.text('Active · created Oct 16, 2026'), findsOneWidget);
    expect(find.text('Last scanned: never'), findsOneWidget);
  });

  testWidgets('a code kept on this device is shown with its status',
      (t) async {
    final store = _MemoryStore(StoredQrCode(
        url: 'http://localhost:3000/#/passport/kept', createdAt: _created));
    await _open(
        t,
        _FakeService(view: _view(lastScanned: DateTime.utc(2026, 10, 17, 12))),
        store);

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.bySemanticsLabel('Your emergency QR code'), findsOneWidget);
    expect(find.text('Mary Johnson'), findsOneWidget);
    expect(find.text('Active · created Oct 15, 2026'), findsOneWidget);
    expect(find.text('Last scanned: Oct 17, 2026'), findsOneWidget);
    expect(find.text('Save QR image'), findsOneWidget);
    expect(find.text('Make a new code'), findsOneWidget);
  });

  testWidgets('an active code not kept here: make a new one after confirming',
      (t) async {
    final service = _FakeService(view: _view());
    final store = _MemoryStore(); // e.g. a new phone
    await _open(t, service, store);

    expect(find.text('Your QR isn\'t saved on this device'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    await t.tap(find.text('Make a new code'));
    await t.pumpAndSettle();
    expect(find.text('Make a new code?'), findsOneWidget);
    await t.tap(find.text('Make new code'));
    await t.pumpAndSettle();

    expect(service.made, 1);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('a code kept from an older code is not shown', (t) async {
    final store = _MemoryStore(StoredQrCode(
        url: 'http://localhost:3000/#/passport/old',
        createdAt: DateTime.utc(2026, 10, 1)));
    await _open(t, _FakeService(view: _view()), store);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Your QR isn\'t saved on this device'), findsOneWidget);
  });

  testWidgets('Cancel keeps the current code', (t) async {
    final service = _FakeService(view: _view());
    final store = _MemoryStore(StoredQrCode(
        url: 'http://localhost:3000/#/passport/kept', createdAt: _created));
    await _open(t, service, store);

    await t.tap(find.text('Make a new code'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();

    expect(service.made, 0);
    expect(store.code!.url, endsWith('/kept'));
  });

  testWidgets('Save QR image draws the code and saves the picture', (t) async {
    final saver = _Saver();
    final store = _MemoryStore(StoredQrCode(
        url: 'http://localhost:3000/#/passport/kept', createdAt: _created));
    await _open(t, _FakeService(view: _view()), store, saver: saver);

    await t.tap(find.text('Save QR image'));
    await t.pumpAndSettle();

    expect(saver.calls, [
      ('http://localhost:3000/#/passport/kept', ''),
      ('', 'careconnect-emergency-qr.png'),
    ]);
    expect(find.text('QR image ready. Save it to your photos.'), findsOneWidget);
  });

  testWidgets('when saving fails the patient is told to take a screenshot',
      (t) async {
    final saver = _Saver()..result = false;
    final store = _MemoryStore(StoredQrCode(
        url: 'http://localhost:3000/#/passport/kept', createdAt: _created));
    await _open(t, _FakeService(view: _view()), store, saver: saver);

    await t.tap(find.text('Save QR image'));
    await t.pumpAndSettle();
    expect(find.textContaining('take a screenshot'), findsOneWidget);
  });

  testWidgets('What a scan shows lists every section as Shown or Hidden',
      (t) async {
    await _open(t, _FakeService(view: _view(withCode: false)), _MemoryStore());
    expect(find.text('WHAT A SCAN SHOWS'), findsOneWidget);
    expect(find.bySemanticsLabel('Name and age: Always shown'), findsOneWidget);
    expect(find.bySemanticsLabel('Blood type: Shown'), findsOneWidget);
    expect(find.bySemanticsLabel('Allergies: Shown'), findsOneWidget);
    expect(find.bySemanticsLabel('Medications: Hidden'), findsOneWidget);
    expect(find.bySemanticsLabel('Emergency contact: Shown'), findsOneWidget);
    expect(find.bySemanticsLabel('Chronic conditions: Hidden'), findsOneWidget);
    expect(find.text('Change what\'s shared'), findsNothing);
  });

  testWidgets('a failed new code keeps the screen and says so', (t) async {
    final service =
        _FakeService(view: _view(withCode: false), makeError: PassportError.server);
    await _open(t, service, _MemoryStore());
    await t.tap(find.text('Create my emergency QR'));
    await t.pumpAndSettle();
    expect(find.textContaining('couldn\'t make a new code'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('no connection: a message and Try again loads again', (t) async {
    final service =
        _FakeService(view: _view(withCode: false), loadError: PassportError.network);
    await _open(t, service, _MemoryStore());
    expect(find.text('We couldn\'t load your emergency QR'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(service.loads, 2);
    expect(find.text('You don\'t have an emergency QR yet'), findsOneWidget);
  });

  testWidgets('a non-patient account is told the QR is for patients only',
      (t) async {
    await _open(
        t,
        _FakeService(
            view: _view(), loadError: PassportError.notPatient),
        _MemoryStore());
    expect(find.text('Only for patients'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });
}
