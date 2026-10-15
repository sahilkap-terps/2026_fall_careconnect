// EhrDataService: the Epic / Cerner / Athena read surface (/api/ehr/resources,
// /api/ehr/patient) the Health Data screen merges with Medicare.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:care_connect_app/features/health/health_data/models/health_record.dart';
import 'package:care_connect_app/features/health/health_data/models/patient_demographics.dart';
import 'package:care_connect_app/features/health/health_data/services/ehr_data_service.dart';
import 'package:care_connect_app/services/api_client.dart';

import '../health_data_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpClientAdapter original;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = ApiClient.instance.debugHttpClientAdapter;
  });
  tearDown(() => ApiClient.instance.debugSetHttpClientAdapter(original));

  test('TC-HDATA-022: a record from a source the app does not know is never '
      'shown as coming from Epic (DEF-MCR-22)', () async {
    ApiClient.instance.debugSetHttpClientAdapter(RouteAdapter({
      '/api/ehr/resources': '[{"resourceId":"x-1","source":"ALLSCRIPTS",'
          '"category":"Conditions","title":"Hypertension"},'
          '{"resourceId":"x-2","category":"Allergies","title":"Penicillin"}]',
    }));
    final records = await EhrDataService().fetchRecords();
    expect(records.where((r) => r.sources.contains(RecordSource.epic)), isEmpty,
        reason: records.map((r) => '${r.id}: ${r.sources}').join('; '));
  });

  test('TC-HDATA-028: resources map to records by id, source, category, '
      'title, date and status, and the patient record to demographics',
      () async {
    ApiClient.instance.debugSetHttpClientAdapter(RouteAdapter({
      '/api/ehr/resources': '['
          '{"resourceId":"c-1","source":"cerner","category":"Medications",'
          '"title":"Metformin 500 mg","occurredAt":"2026-08-01T12:00:00Z",'
          '"status":"active"},'
          '{"resourceId":"a-1","source":"ATHENA","category":"Something else",'
          '"title":"  ","occurredAt":""}'
          ']',
      '/api/ehr/patient':
          '{"name":"Test Patient","birthDate":"1980-05-14","gender":" "}',
    }));
    final service = EhrDataService();
    final records = await service.fetchRecords();
    expect(records, hasLength(2));
    final med = records.first;
    expect(med.id, 'c-1');
    expect(med.sources, [RecordSource.cerner]);
    expect(med.type, RecordType.medication);
    expect(med.title, 'Metformin 500 mg');
    expect(med.date, DateTime.utc(2026, 8, 1, 12));
    expect(med.status, 'active');
    final other = records.last;
    expect(other.sources, [RecordSource.athena]);
    expect(other.type, RecordType.other);
    expect(other.title, 'Health record');
    expect(other.date, isNull);
    expect(other.status, isNull);

    final who = await service.fetchPatientDemographics();
    expect(who!.name, 'Test Patient');
    expect(who.birthDate, DateTime(1980, 5, 14));
    expect(who.gender, isNull);
  });

  test('rows stored by athenahealth (ATHENAHEALTH) are shown as athena '
      'records, with their resource type', () async {
    ApiClient.instance.debugSetHttpClientAdapter(RouteAdapter({
      '/api/ehr/resources': '[{"resourceType":"Condition","resourceId":"a-2",'
          '"source":"ATHENAHEALTH","category":"Conditions","title":"Asthma"}]',
    }));
    final records = await EhrDataService().fetchRecords();
    expect(records.single.sources, [RecordSource.athena]);
    expect(records.single.resourceType, 'Condition');
  });

  test('record types come from the FHIR resource type first, then the '
      'category', () async {
    String row(String type, String category) =>
        '{"resourceType":"$type","resourceId":"$type","source":"EPIC",'
        '"category":"$category","title":"$type"}';
    ApiClient.instance.debugSetHttpClientAdapter(RouteAdapter({
      '/api/ehr/resources': '[${[
        row('Condition', 'Conditions'),
        row('MedicationStatement', 'Medications'),
        row('AllergyIntolerance', 'Allergies'),
        row('Encounter', 'Care Context'),
        row('Observation', 'Results'),
        row('DiagnosticReport', 'Results'),
        row('Immunization', 'Immunizations'),
        row('Procedure', 'Procedures'),
        row('DocumentReference', 'Documents'),
        row('CarePlan', 'Care Context'),
        row('Coverage', 'Coverage/Insurance'),
        row('SomethingNew', 'Results'),
      ].join(',')}]',
    }));
    final types = {
      for (final r in await EhrDataService().fetchRecords()) r.id: r.type
    };
    expect(types, {
      'Condition': RecordType.condition,
      'MedicationStatement': RecordType.medication,
      'AllergyIntolerance': RecordType.allergy,
      'Encounter': RecordType.appointment,
      'Observation': RecordType.clinicalRecord,
      'DiagnosticReport': RecordType.clinicalRecord,
      'Immunization': RecordType.clinicalRecord,
      'Procedure': RecordType.clinicalRecord,
      'DocumentReference': RecordType.clinicalRecord,
      'CarePlan': RecordType.other,
      'Coverage': RecordType.other,
      'SomethingNew': RecordType.clinicalRecord,
    });
  });

  group('Patient Information', () {
    Future<PatientDemographics?> demographics(
        Map<String, String?> bySource) async {
      ApiClient.instance.debugSetHttpClientAdapter(_BySource(bySource));
      return EhrDataService().fetchPatientDemographics();
    }

    test('Epic wins every field it has; athenahealth fills the rest',
        () async {
      final d = await demographics({
        'EPIC': '{"name":"Epic Name","birthDate":"1980-05-14","gender":" "}',
        'ATHENAHEALTH':
            '{"name":"Athena Name","birthDate":"1981-01-01","gender":"female"}',
      });
      expect(d!.name, 'Epic Name');
      expect(d.birthDate, DateTime(1980, 5, 14));
      expect(d.gender, 'female');
    });

    test('athenahealth alone fills the whole card', () async {
      final d = await demographics({
        'EPIC': null,
        'ATHENAHEALTH':
            '{"name":"Athena Name","birthDate":"1981-01-01","gender":"male"}',
      });
      expect(d!.name, 'Athena Name');
      expect(d.birthDate, DateTime(1981, 1, 1));
      expect(d.gender, 'male');
    });

    test('no source with demographics means no card', () async {
      expect(await demographics({'EPIC': null, 'ATHENAHEALTH': null}), isNull);
    });
  });
}

/// Answers /api/ehr/patient by its ?source=; a null body is a 404.
class _BySource implements HttpClientAdapter {
  _BySource(this.bodies);
  final Map<String, String?> bodies;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final body = bodies[options.queryParameters['source']];
    return ResponseBody.fromString(body ?? '{}', body == null ? 404 : 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}
