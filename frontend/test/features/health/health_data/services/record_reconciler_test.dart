// RecordReconciler (WBS 6.2.41, FR-EHR-07): the same record from several
// providers is shown once as Epic's version and flagged as a possible
// duplicate when the versions agree, flagged for the patient to decide when
// they don't, and left untouched for a caregiver when it is a medication.

import 'package:flutter_test/flutter_test.dart';

import 'package:care_connect_app/features/health/health_data/models/health_record.dart';
import 'package:care_connect_app/features/health/health_data/services/record_reconciler.dart';

HealthRecord rec(
  String id,
  RecordSource source, {
  RecordType type = RecordType.condition,
  String title = 'Type 2 diabetes',
  String? status = 'active',
  DateTime? date,
}) =>
    HealthRecord.single(
        id: id,
        source: source,
        type: type,
        title: title,
        status: status,
        date: date ?? DateTime.utc(2026, 7, 1));

void main() {
  test('identical records from Epic and athenahealth show once as Epic\'s '
      'version and are flagged, never merged silently', () {
    final r = RecordReconciler.reconcile([
      rec('ath-1', RecordSource.athena, title: 'TYPE 2 Diabetes.'),
      rec('epic-1', RecordSource.epic),
    ]);
    expect(r.unresolved.single.kind, RecordConflictKind.possibleDuplicate);
    expect(r.records, hasLength(1));
    expect(r.records.single.id, 'epic-1');
    expect(r.records.single.sources, [RecordSource.epic, RecordSource.athena]);
  });

  test('without Epic, athenahealth is preferred over other sources', () {
    final r = RecordReconciler.reconcile([
      rec('c-1', RecordSource.cerner),
      rec('a-1', RecordSource.athena),
    ]);
    expect(r.records.single.id, 'a-1');
  });

  test('a different status or date is a conflict; Epic shows until the '
      'patient chooses', () {
    final r = RecordReconciler.reconcile([
      rec('epic-1', RecordSource.epic, status: 'active'),
      rec('ath-1', RecordSource.athena, status: 'resolved'),
    ]);
    expect(r.records.single.id, 'epic-1');
    expect(r.unresolved, hasLength(1));
    final c = r.unresolved.single;
    expect(c.versions.map((v) => v.id), ['epic-1', 'ath-1']);

    final dated = RecordReconciler.reconcile([
      rec('epic-1', RecordSource.epic, date: DateTime.utc(2026, 1, 1)),
      rec('ath-1', RecordSource.athena, date: DateTime.utc(2026, 2, 1)),
    ]);
    expect(dated.unresolved, hasLength(1));
  });

  test('a remembered choice is shown and not asked again, until either '
      'version changes', () {
    final records = [
      rec('epic-1', RecordSource.epic, status: 'active'),
      rec('ath-1', RecordSource.athena, status: 'resolved'),
    ];
    final c = RecordReconciler.reconcile(records).unresolved.single;
    final choices = {
      c.storageKey: RecordReconciler.encodeChoice(c, c.versions.last),
    };
    final r = RecordReconciler.reconcile(records, choices: choices);
    expect(r.unresolved, isEmpty);
    expect(r.records.single.id, 'ath-1');

    final changed = RecordReconciler.reconcile([
      rec('epic-1', RecordSource.epic, status: 'inactive'),
      rec('ath-1', RecordSource.athena, status: 'resolved'),
    ], choices: choices);
    expect(changed.unresolved, hasLength(1));
    expect(changed.records.single.id, 'epic-1');
  });

  test('one-off events only match on the same day; conditions match on title',
      () {
    final visits = RecordReconciler.reconcile([
      rec('e', RecordSource.epic,
          type: RecordType.appointment,
          title: 'Office visit',
          date: DateTime.utc(2026, 3, 1)),
      rec('a', RecordSource.athena,
          type: RecordType.appointment,
          title: 'Office visit',
          date: DateTime.utc(2026, 4, 1)),
    ]);
    expect(visits.records, hasLength(2));
    expect(visits.unresolved, isEmpty);
  });

  test('records from the same source, different types, and ambiguous '
      'matches are left alone', () {
    final r = RecordReconciler.reconcile([
      rec('e1', RecordSource.epic),
      rec('e2', RecordSource.epic),
      rec('a1', RecordSource.athena),
      rec('m1', RecordSource.epic,
          type: RecordType.medication, title: 'Type 2 diabetes'),
    ]);
    expect(r.records.map((x) => x.id).toSet(), {'e1', 'e2', 'a1', 'm1'});
    expect(r.unresolved, isEmpty);
  });

  test('"keep both" shows every version separately and resolves the conflict',
      () {
    final records = [
      rec('epic-1', RecordSource.epic, status: 'active'),
      rec('ath-1', RecordSource.athena, status: 'resolved'),
    ];
    final c = RecordReconciler.reconcile(records).unresolved.single;
    final r = RecordReconciler.reconcile(records,
        choices: {c.storageKey: RecordReconciler.encodeKeepBoth(c)});
    expect(r.unresolved, isEmpty);
    expect(r.records.map((x) => x.id), ['epic-1', 'ath-1']);
    expect(r.records.first.sources, [RecordSource.epic]);
  });

  test('confirming a possible duplicate clears the flag; the record stays '
      'shown once', () {
    final records = [
      rec('epic-1', RecordSource.epic),
      rec('ath-1', RecordSource.athena),
    ];
    final c = RecordReconciler.reconcile(records).unresolved.single;
    final r = RecordReconciler.reconcile(records,
        choices: {c.storageKey: RecordReconciler.encodeChoice(c, c.versions.first)});
    expect(r.unresolved, isEmpty);
    expect(r.records.single.id, 'epic-1');
  });

  test('FR-EHR-07: a medication conflict keeps every version and waits for '
      'a caregiver; a stored choice does not overwrite it', () {
    HealthRecord med(String id, RecordSource s, String status) => rec(id, s,
        type: RecordType.medication, title: 'Lisinopril 10 mg', status: status);
    final records = [
      med('epic-1', RecordSource.epic, 'active'),
      med('ath-1', RecordSource.athena, 'stopped'),
    ];
    final r = RecordReconciler.reconcile(records);
    expect(r.unresolved.single.kind, RecordConflictKind.medicationNeedsCaregiver);
    expect(r.records.map((x) => x.id), ['epic-1', 'ath-1']);

    final c = r.unresolved.single;
    final chosen = RecordReconciler.reconcile(records,
        choices: {c.storageKey: RecordReconciler.encodeChoice(c, c.versions.first)});
    expect(chosen.records.map((x) => x.id), ['epic-1', 'ath-1']);
    expect(chosen.unresolved, hasLength(1));
  });

  test('nothing about a record\'s title is stored with a decision', () {
    final c = RecordReconciler.reconcile([
      rec('epic-1', RecordSource.epic, status: 'active'),
      rec('ath-1', RecordSource.athena, status: 'resolved'),
    ]).unresolved.single;
    final stored = '${c.storageKey} ${RecordReconciler.encodeChoice(c, c.versions.first)} '
        '${RecordReconciler.encodeKeepBoth(c)}';
    expect(stored.toLowerCase(), isNot(contains('diabetes')));
    expect(stored, isNot(contains('active')));
  });
}
