// MedicareSharingService against the 6.2.56 consent API (WBS 6.2.59, #323):
//   GET    /v1/api/caregiver-patient-links/patients/{id}/caregivers
//   GET    /v1/api/v3/consent/medicare-view?patientUserId=&granteeUserId=
//   POST   /v1/api/v3/consent/medicare-view
//   DELETE /v1/api/v3/consent/medicare-view
//
// Every request goes through http.runWithClient + MockClient; nothing touches
// the network. Test IDs TC-MCR-SHR-* are proposed; the Testing Lead assigns
// the final ones.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:care_connect_app/features/health/health_data/services/medicare_sharing_service.dart';

const _patient = 7;

Future<T> _with<T>(
  Future<T> Function() body,
  Future<http.Response> Function(http.Request req) handler, {
  List<http.Request>? seen,
}) =>
    http.runWithClient(
      body,
      () => MockClient((req) {
        seen?.add(req);
        return handler(req);
      }),
    );

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Future<MedicareSharingError?> _loadError(
    Future<http.Response> Function(http.Request) handler) async {
  try {
    await _with(() => MedicareSharingService().load(), handler);
    return null;
  } on MedicareSharingException catch (e) {
    return e.error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Future<int?> Function() previousUser;
  setUp(() {
    previousUser = MedicareSharingService.currentUserId;
    MedicareSharingService.currentUserId = () async => _patient;
  });
  tearDown(() => MedicareSharingService.currentUserId = previousUser);

  test(
      'TC-MCR-SHR-001: load lists the patient\'s ACTIVE caregivers once each, '
      'sorted by name, with each one\'s Medicare sharing state', () async {
    final seen = <http.Request>[];
    final list =
        await _with(() => MedicareSharingService().load(), (req) async {
      if (req.url.path
          .endsWith('/caregiver-patient-links/patients/7/caregivers')) {
        return _json([
          {
            'caregiverUserId': 21,
            'caregiverName': 'Zoe Park',
            'status': 'ACTIVE'
          },
          {
            'caregiverUserId': 22,
            'caregiverName': 'Ann Lee',
            'caregiverEmail': 'ann@example.test',
            'status': 'ACTIVE'
          },
          {
            'caregiverUserId': 22,
            'caregiverName': 'Ann Lee',
            'status': 'ACTIVE'
          },
          {
            'caregiverUserId': 23,
            'caregiverName': 'Pending Pat',
            'status': 'PENDING'
          },
          {
            'caregiverUserId': 24,
            'caregiverName': 'Gone Gil',
            'status': 'REVOKED'
          },
        ]);
      }
      if (req.url.path.endsWith('/v3/consent/medicare-view')) {
        expect(req.url.queryParameters['patientUserId'], '7');
        return _json(
            {'granted': req.url.queryParameters['granteeUserId'] == '22'});
      }
      fail('Unexpected request ${req.url}');
    }, seen: seen);

    expect(list.map((c) => c.name), ['Ann Lee', 'Zoe Park']);
    expect(list.map((c) => c.shared), [true, false]);
    expect(list.first.email, 'ann@example.test');
    // One links call and one consent check per listed caregiver, all GETs.
    expect(seen, hasLength(3));
    expect(seen.every((r) => r.method == 'GET'), isTrue);
  });

  test(
      'TC-MCR-SHR-002: a link with no status counts as active, and a blank '
      'name shows as "Caregiver"', () async {
    final list =
        await _with(() => MedicareSharingService().load(), (req) async {
      if (req.url.path.contains('caregiver-patient-links')) {
        return _json([
          {'caregiverUserId': '30', 'caregiverName': '  '},
        ]);
      }
      return _json({'granted': false});
    });
    expect(list.single.userId, 30);
    expect(list.single.name, 'Caregiver');
  });

  test(
      'TC-MCR-SHR-003: load maps 401, 403, 500, a bad body and a dropped '
      'connection to signedOut, notPatient, server, server and network',
      () async {
    expect(await _loadError((_) async => http.Response('', 401)),
        MedicareSharingError.signedOut);
    expect(await _loadError((_) async => http.Response('', 403)),
        MedicareSharingError.notPatient);
    expect(await _loadError((_) async => http.Response('', 500)),
        MedicareSharingError.server);
    expect(await _loadError((_) async => http.Response('not json', 200)),
        MedicareSharingError.server);
    expect(await _loadError((_) async => throw http.ClientException('down')),
        MedicareSharingError.network);
  });

  test('TC-MCR-SHR-004: with no signed-in user nothing is requested', () async {
    MedicareSharingService.currentUserId = () async => null;
    final seen = <http.Request>[];
    try {
      await _with(() => MedicareSharingService().load(), (_) async => _json([]),
          seen: seen);
      fail('expected signedOut');
    } on MedicareSharingException catch (e) {
      expect(e.error, MedicareSharingError.signedOut);
    }
    expect(seen, isEmpty);
  });

  test(
      'TC-MCR-SHR-005: a failed consent check fails the load rather than '
      'showing a guessed switch state', () async {
    expect(
        await _loadError((req) async => req.url.path.contains('consent')
            ? http.Response('', 500)
            : _json([
                {
                  'caregiverUserId': 21,
                  'caregiverName': 'Zoe',
                  'status': 'ACTIVE'
                }
              ])),
        MedicareSharingError.server);
  });

  test(
      'TC-MCR-SHR-006: turning sharing on POSTs the caregiver as a CAREGIVER '
      'grantee and succeeds on 201', () async {
    final seen = <http.Request>[];
    final ok = await _with(() => MedicareSharingService().setShared(21, true),
        (_) async => _json({'status': 'ACTIVE'}, 201),
        seen: seen);
    expect(ok, isTrue);
    expect(seen.single.method, 'POST');
    expect(seen.single.url.path, endsWith('/v1/api/v3/consent/medicare-view'));
    expect(jsonDecode(seen.single.body),
        {'granteeUserId': 21, 'granteeRole': 'CAREGIVER'});
    expect(seen.single.headers['Content-Type'], startsWith('application/json'));
  });

  test(
      'TC-MCR-SHR-007: turning sharing off DELETEs with the caregiver\'s id '
      'and succeeds on 200', () async {
    final seen = <http.Request>[];
    final ok = await _with(() => MedicareSharingService().setShared(21, false),
        (_) async => _json({'revokedCount': 1}),
        seen: seen);
    expect(ok, isTrue);
    expect(seen.single.method, 'DELETE');
    expect(jsonDecode(seen.single.body), {'granteeUserId': 21});
  });

  test('TC-MCR-SHR-008: a refused or failed change reports false', () async {
    expect(
        await _with(() => MedicareSharingService().setShared(21, true),
            (_) async => http.Response('', 400)),
        isFalse);
    expect(
        await _with(() => MedicareSharingService().setShared(21, false),
            (_) async => throw http.ClientException('down')),
        isFalse);
  });
  test('malformed consent state fails load instead of guessing not shared',
      () async {
    for (final state in [
      <String, Object?>{},
      {'granted': null},
      {'granted': 'true'},
      {'granted': 0}
    ]) {
      expect(
          await _loadError((req) async => req.url.path.contains('consent')
              ? _json(state)
              : _json([
                  {'caregiverUserId': 21, 'status': 'ACTIVE'}
                ])),
          MedicareSharingError.server);
    }
  });
}
