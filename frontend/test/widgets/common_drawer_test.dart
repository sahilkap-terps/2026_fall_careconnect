// Tests for CommonDrawer
// (lib/widgets/common_drawer.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:care_connect_app/widgets/common_drawer.dart';
import 'package:care_connect_app/providers/user_provider.dart';
import 'package:care_connect_app/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mock_user_provider.dart';

class _NullUserProvider extends MockUserProvider {
  _NullUserProvider() : super(mockUser: null);

  @override
  UserSession? get user => null;
}

/// Mock that returns offline so _loadProfilePicture() skips HTTP.
class _OfflineMockUserProvider extends MockUserProvider {
  _OfflineMockUserProvider({required UserSession mockUser})
      : super(mockUser: mockUser);

  @override
  bool get isDeviceOnline => false;
}

Widget _wrapNull() {
  final provider = _NullUserProvider();
  return MaterialApp(
    home: ChangeNotifierProvider<UserProvider>.value(
      value: provider,
      child: Scaffold(
        drawer: const CommonDrawer(currentRoute: '/dashboard'),
        body: const SizedBox(),
      ),
    ),
  );
}

Widget _wrapWithUser({
  String role = 'PATIENT',
  String currentRoute = '/dashboard',
}) {
  final user = MockUser(
    id: 1,
    name: 'Jane',
    email: 'j@e.com',
    role: role,
    patientId: 1,
    caregiverId: role == 'CAREGIVER' ? 10 : null,
  );
  final provider = _OfflineMockUserProvider(mockUser: user);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: provider),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1200)),
        child: Scaffold(
          drawer: CommonDrawer(currentRoute: currentRoute),
          body: const SizedBox(),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CommonDrawer – null user', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_wrapNull());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('opens drawer and shows "Please log in"', (tester) async {
      await tester.pumpWidget(_wrapNull());
      await tester.pump();
      final ScaffoldState scaffold = tester.state(find.byType(Scaffold));
      scaffold.openDrawer();
      await tester.pump();
      expect(find.text('Please log in'), findsOneWidget);
    });
  });

  group('CommonDrawer – logged-in PATIENT', () {
    Future<void> openDrawer(WidgetTester tester, {String role = 'PATIENT', String currentRoute = '/dashboard'}) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = origOnError;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_wrapWithUser(role: role, currentRoute: currentRoute));
      await tester.pump();
      final ScaffoldState scaffold = tester.state(find.byType(Scaffold));
      scaffold.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows user name in drawer header', (tester) async {
      await openDrawer(tester);
      expect(find.text('Jane'), findsOneWidget);
    });

    testWidgets('shows Dashboard item', (tester) async {
      await openDrawer(tester);
      expect(find.text('Dashboard'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Calendar Assistant', (tester) async {
      await openDrawer(tester);
      expect(find.text('Calendar Assistant'), findsOneWidget);
    });

    testWidgets('TC-HDATA-049: a patient sees Health Data in the menu',
        (tester) async {
      await openDrawer(tester);
      expect(find.text('Health Data'), findsOneWidget);
      expect(find.byIcon(Icons.health_and_safety), findsOneWidget);
    });

    for (final role in ['CAREGIVER', 'FAMILY_MEMBER', 'ADMIN']) {
      testWidgets('TC-HDATA-050: a $role does not see Health Data in the menu',
          (tester) async {
        await openDrawer(tester, role: role);
        expect(find.text('Health Data'), findsNothing);
      });
    }

    testWidgets('shows Medication Management', (tester) async {
      await openDrawer(tester);
      expect(find.text('Medication Management'), findsOneWidget);
    });

    testWidgets('shows Gamification', (tester) async {
      await openDrawer(tester);
      expect(find.text('Gamification'), findsOneWidget);
    });

    testWidgets('shows Wearables', (tester) async {
      await openDrawer(tester);
      expect(find.text('Wearables'), findsOneWidget);
    });

    testWidgets('shows Logout', (tester) async {
      await openDrawer(tester);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('does NOT show Add Patient for PATIENT role', (tester) async {
      await openDrawer(tester, role: 'PATIENT');
      expect(find.text('Add Patient'), findsNothing);
    });

    testWidgets('shows role text', (tester) async {
      await openDrawer(tester);
      expect(find.text('PATIENT'), findsOneWidget);
    });

    testWidgets('shows View Profile text', (tester) async {
      await openDrawer(tester);
      expect(find.text(' View Profile'), findsOneWidget);
    });
  });

  group('CommonDrawer – logged-in CAREGIVER', () {
    Future<void> openDrawer(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = origOnError;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_wrapWithUser(role: 'CAREGIVER'));
      await tester.pump();
      final ScaffoldState scaffold = tester.state(find.byType(Scaffold));
      scaffold.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows Add Patient for CAREGIVER role', (tester) async {
      await openDrawer(tester);
      expect(find.text('Add Patient'), findsOneWidget);
    });

    testWidgets('shows Invoice Assistant expansion tile', (tester) async {
      await openDrawer(tester);
      expect(find.text('Invoice Assistant'), findsOneWidget);
    });
  });
}
