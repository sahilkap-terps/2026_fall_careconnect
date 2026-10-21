import '../../../../services/auth_token_manager.dart';
import '../../../../services/api_client.dart';
import '../models/health_record.dart';
import '../models/patient_demographics.dart';
import 'ehr_resource_mapper.dart';

class EhrDataService {
  Future<List<HealthRecord>> fetchRecords() async =>
      await tryFetchRecords() ?? <HealthRecord>[];

  /// The records, or null when the read failed (so the screen can say so).
  Future<List<HealthRecord>?> tryFetchRecords() async {
    try {
      final headers = await AuthTokenManager.getAuthHeaders();

      final resources = await ApiClient.instance.getJson<List<dynamic>>(
        '/api/ehr/resources',
        headers: headers,
        parser: (json) => json is List ? json : <dynamic>[],
      );

      // A resource whose source the app does not know is dropped, never
      // relabelled as another source (see EhrResourceMapper.sourceFrom).
      return resources
          .whereType<Map<String, dynamic>>()
          .map(EhrResourceMapper.toHealthRecord)
          .whereType<HealthRecord>()
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Sources the Patient Information card reads, most preferred first.
  /// Epic is the default source of /api/ehr/patient; athenahealth fills any
  /// field Epic doesn't have, or the whole card when there is no Epic chart.
  static const demographicsSources = ['EPIC', 'ATHENAHEALTH'];

  /// The patient's demographics, field by field from the first source in
  /// [demographicsSources] that has each one. Null when no source has any.
  Future<PatientDemographics?> fetchPatientDemographics() async =>
      mergeDemographics(await fetchDemographicsBySource());

  /// Each source's demographics by source name (null where a source has
  /// none), so a caller can see where they disagree. Callers look sources
  /// up by name: a source that isn't there is null, never an error.
  Future<Map<String, PatientDemographics?>> fetchDemographicsBySource() async {
    final results = await Future.wait(
        demographicsSources.map(_fetchPatientDemographicsFrom));
    return {
      for (var i = 0; i < demographicsSources.length; i++)
        demographicsSources[i]: results[i],
    };
  }

  /// Field by field from the first source, in [demographicsSources] order,
  /// that has each one. A source missing from [bySource] is skipped.
  static PatientDemographics? mergeDemographics(
      Map<String, PatientDemographics?> bySource) {
    PatientDemographics? merged;
    for (final source in demographicsSources) {
      final d = bySource[source];
      merged = merged == null ? d : merged.fillFrom(d);
    }
    return merged == null || merged.isEmpty ? null : merged;
  }

  Future<PatientDemographics?> _fetchPatientDemographicsFrom(
      String source) async {
    try {
      final headers = await AuthTokenManager.getAuthHeaders();

      return await ApiClient.instance.getJson<PatientDemographics>(
        '/api/ehr/patient',
        query: {'source': source},
        headers: headers,
        parser: (json) => PatientDemographics.fromJson(
          json as Map<String, dynamic>,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
