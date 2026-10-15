// CC-12 Increment 2: the public scan page (design screens 3 and 4) and its
// route. Test Plan IDs to be assigned by the Testing Lead.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:care_connect_app/config/router/app_router.dart';
import 'package:care_connect_app/features/emergency_passport/models/public_passport.dart';
import 'package:care_connect_app/features/emergency_passport/pages/passport_scan_page.dart';
import 'package:care_connect_app/features/emergency_passport/services/passport_scan_service.dart';
import 'package:care_connect_app/services/user_role_storage_service.dart';

import 'passport_test_support.dart';

class _FakeScan extends PassportScanService {
  _FakeScan(this.results);
  final List<ScanResult> results;
  int calls = 0;

  @override
  Future<ScanResult> scan(String token) async {
    final r = results[calls < results.length ? calls : results.length - 1];
    calls++;
    return r;
  }
}

final _full = ScanShown(PublicPassport.fromJson(fullPassport));
const _nameOnly =
    ScanShown(PublicPassport(name: 'Jordan Miller', age: 41));

Future<List<Uri>> _open(WidgetTester t, _FakeScan service) async {
  final launched = <Uri>[];
  await t.binding.setSurfaceSize(const Size(420, 2400));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(MaterialApp(
    home: PassportScanPage(
      token: 'abc123',
      service: service,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    ),
  ));
  await t.pumpAndSettle();
  return launched;
}

void main() {
  testWidgets('screen 3: an active code shows only what was shared',
      (t) async {
    final launched = await _open(t, _FakeScan([_full]));

    expect(find.text('EMERGENCY MEDICAL INFORMATION'), findsOneWidget);
    expect(find.text('Jordan Miller'), findsOneWidget);
    expect(find.text('Age 41'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.bySemanticsLabel('Blood type O positive'), findsOneWidget);
    expect(find.text('ALLERGIES'), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('Life-threatening'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.text('Latex'), findsOneWidget);
    expect(find.text('Lisinopril 10 mg'), findsOneWidget);
    expect(find.text('Once daily'), findsOneWidget);
    expect(find.text('Type 2 diabetes'), findsOneWidget);
    expect(find.text('Taylor Miller'), findsOneWidget);
    expect(find.text('Last updated Oct 13, 2026'), findsOneWidget);
    expect(find.text('Call 911'), findsNothing);
    expect(find.text('No information shared'), findsNothing);

    await t.tap(find.text('Call (415) 555-0184'));
    expect(launched, [Uri(scheme: 'tel', path: '4155550184')]);
  });

  testWidgets('screen 3: hidden sections are not shown', (t) async {
    await _open(
        t,
        _FakeScan([
          ScanShown(PublicPassport.fromJson(
              {'name': 'Jordan Miller', 'age': 41, 'bloodType': 'A_NEGATIVE'}))
        ]));
    expect(find.text('A−'), findsOneWidget);
    expect(find.text('ALLERGIES'), findsNothing);
    expect(find.text('CURRENT MEDICATIONS'), findsNothing);
    expect(find.text('CHRONIC CONDITIONS'), findsNothing);
    expect(find.text('EMERGENCY CONTACT'), findsNothing);
  });

  testWidgets('nothing shared: name and age, "No information shared", Call 911',
      (t) async {
    final launched = await _open(t, _FakeScan([_nameOnly]));
    expect(find.text('Jordan Miller'), findsOneWidget);
    expect(find.text('No information shared'), findsOneWidget);
    expect(find.textContaining('Last updated'), findsNothing);
    await t.tap(find.text('Call 911'));
    expect(launched, [Uri(scheme: 'tel', path: '911')]);
  });

  testWidgets('screen 4: a code that is not active shows no information',
      (t) async {
    final launched = await _open(t, _FakeScan([const ScanNotActive()]));
    expect(find.text('This code isn\'t active'), findsOneWidget);
    expect(find.text('Jordan Miller'), findsNothing);
    await t.tap(find.text('Call 911'));
    expect(launched, [Uri(scheme: 'tel', path: '911')]);
  });

  testWidgets('too many tries: Try again loads once more', (t) async {
    final service = _FakeScan([const ScanRateLimited(), _full]);
    await _open(t, service);
    expect(find.text('Too many tries'), findsOneWidget);
    expect(find.text('Call 911'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.text('Jordan Miller'), findsOneWidget);
  });

  testWidgets('no answer: a message, Try again and Call 911', (t) async {
    await _open(t, _FakeScan([const ScanFailed()]));
    expect(find.text('We couldn\'t load this information'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Call 911'), findsOneWidget);
  });

  testWidgets('the page loads once and never refreshes by itself', (t) async {
    final service = _FakeScan([_full]);
    await _open(t, service);
    await t.pump(const Duration(minutes: 2));
    expect(service.calls, 1);
  });

  testWidgets('opening a new code on the same page loads that code',
      (t) async {
    final service = _FakeScan([const ScanNotActive(), _full]);
    await t.pumpWidget(MaterialApp(
        home: PassportScanPage(token: 'old', service: service)));
    await t.pumpAndSettle();
    expect(find.text('This code isn\'t active'), findsOneWidget);

    await t.pumpWidget(MaterialApp(
        home: PassportScanPage(token: 'new', service: service)));
    await t.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.text('Jordan Miller'), findsOneWidget);
    expect(find.text('This code isn\'t active'), findsNothing);
  });

  group('route', () {
    const secure =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secure, (call) async {
        if (call.method == 'readAll') return <String, String>{};
        if (call.method == 'containsKey') return false;
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secure, null);
    });

    testWidgets('/passport/:token opens the scan page without signing in',
        (t) async {
      await UserRoleStorageService.instance.clearUserData();
      final router = GoRouter(
        initialLocation: '/passport/abc123',
        routes: appRouter.configuration.routes,
      );
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      for (var i = 0; i < 20; i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(router.routerDelegate.currentConfiguration.uri.path,
          '/passport/abc123');
      final page = t.widget<PassportScanPage>(find.byType(PassportScanPage));
      expect(page.token, 'abc123');
    });
  });
}
