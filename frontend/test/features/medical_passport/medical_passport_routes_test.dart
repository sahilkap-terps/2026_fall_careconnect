// /medical-passport on the production route table, as
// health_data_routes_test.dart does for the Health Data routes.
//
// No Test Plan IDs yet: they are issued by the Testing Lead.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:care_connect_app/config/router/app_router.dart';
import 'package:care_connect_app/features/medical_passport/pages/medical_passport_page.dart';
import 'package:care_connect_app/l10n/app_localizations.dart';
import 'package:care_connect_app/providers/user_provider.dart';
import 'package:care_connect_app/services/user_role_storage_service.dart';

const _secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
const _connectivityStatus = EventChannel('dev.fluttercommunity.plus/connectivity_status');

Future<GoRouter> _open(WidgetTester t, {required bool signedIn}) async {
  if (signedIn) {
    await UserRoleStorageService.instance.setUserData(role: 'PATIENT', userId: 1, patientId: 1);
  } else {
    await UserRoleStorageService.instance.clearUserData();
  }
  final router = GoRouter(
    initialLocation: '/medical-passport',
    routes: appRouter.configuration.routes,
  );
  await t.pumpWidget(ChangeNotifierProvider<UserProvider>.value(
    value: UserProvider(),
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  ));
  for (var i = 0; i < 20; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 50));
  }
  return router;
}

String _path(GoRouter r) => r.routerDelegate.currentConfiguration.uri.path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      if (call.method == 'containsKey') return false;
      return null;
    });
    messenger.setMockMethodCallHandler(
        _connectivity, (call) async => call.method == 'check' ? ['wifi'] : null);
    messenger.setMockStreamHandler(
        _connectivityStatus, MockStreamHandler.inline(onListen: (_, __) {}));
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_secure, null);
    messenger.setMockMethodCallHandler(_connectivity, null);
    messenger.setMockStreamHandler(_connectivityStatus, null);
  });

  testWidgets('/medical-passport without signing in goes to the login page', (t) async {
    // Only where the router lands is under test. The inherited login page
    // overflows its Rows with the test font; that layout error is ignored.
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exceptionAsString().contains('RenderFlex overflowed')) previous?.call(d);
    };
    addTearDown(() => FlutterError.onError = previous);
    final r = await _open(t, signedIn: false);
    FlutterError.onError = previous;
    expect(_path(r), '/login');
    expect(find.byType(MedicalPassportPage), findsNothing);
  });

  testWidgets('/medical-passport opens the passport for a signed-in patient', (t) async {
    await http.runWithClient(() async {
      final r = await _open(t, signedIn: true);
      expect(_path(r), '/medical-passport');
      expect(find.byType(MedicalPassportPage), findsOneWidget);
    }, () => MockClient((_) async => http.Response(jsonEncode({'name': 'Jordan Miller'}), 200)));
  });
}
