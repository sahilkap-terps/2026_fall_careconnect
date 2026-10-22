# Current FHIR storage inventory for Team B review

Reviewed October 22, 2026 (America/New_York). Author role: Team C Technical Architect.
Status: review draft. Related work: CR-2 / issue #305 and WBS 4.2.9, 4.2.10, 4.2.11.

## What this review establishes

This is a code-based map of FHIR storage on `team-c-develop`, at commit `21d5a521e87f70eb9c304bd5d993d24cdad9adad`. It covers the Epic, Medicare, athenahealth, and Cerner paths found in this branch. A configured fetch path is not proof that a vendor has granted access or that a live record has been fetched. Team owners must confirm enabled settings, granted scopes, and actual resource use in the target environment.

No schema, service, consent, or source data was changed. No live patient data was read. This draft does not approve CR-2, establish a release candidate, or close Team B's prerequisite. It gives Team B a concrete inventory to check.

The older October 21 plan used a different commit. This review uses a fresh remote-head check and a clean worktree. The original local Docker checkout is preserved.

## Resource coverage

The lists below come from fetch and sync code, not from UI category labels. All source owners should report any additional deployed paths absent from this branch.

| Source/path | Resource types handled by the path | Storage and current limit | Evidence |
| --- | --- | --- | --- |
| Medicare / Blue Button | Patient, Coverage, ExplanationOfBenefit | Raw history plus identity, coverage, and visit rows. Reads use the newest raw copy per external ID. Cache refresh is due after one day. | [MedicareRecordCache][cache], [MedicareService][medicare] |
| Epic | Patient; AllergyIntolerance, Condition, MedicationRequest, MedicationStatement, Observation, DiagnosticReport, Immunization, Procedure, DocumentReference, Encounter, CarePlan, Goal, CareTeam, FamilyMemberHistory, Coverage, Device | `ehr_resource` mirror; raw history when patient/source IDs resolve; selected types also produce search/index events. Feature flag and granted scopes limit actual fetches. | [EpicSyncService][epic] |
| athenahealth | Patient; AllergyIntolerance, Condition, MedicationRequest, Observation, DiagnosticReport, Immunization, Procedure, Encounter, CarePlan, Goal, CareTeam, FamilyMemberHistory, Coverage, Device | Mirror plus raw history on content change. Each type requires its system read scope. DocumentReference is excluded; MedicationStatement is not offered by this path. No Ask AI indexing in this sync service. | [AthenaSyncService][athena] |
| Shared appointment sync | Appointment | Raw row upsert plus `ehr_appointment_record`. The reviewed main-source search found no caller of this sync service; do not count it as a live import. | [EhrAppointmentSyncService][appointments] |
| Cerner appointment prototype | Appointment | Explicitly constructed adapter, not a registered component. Uses the shared raw and appointment tables. No HTTP or account-link flow here. | [CernerStorageAdapter][cerner] |
| Cerner Patient review | Patient | Projection and proposed identity conflicts stay in memory. This adapter does not save the Patient body or conflicts and does not write canonical patient values. | [CernerStorageAdapter][cerner], [CernerResourceMapper][mapper] |
| Cerner allergy boundary | AllergyIntolerance inside a searchset Bundle | Inactive HTTP client and pure mapper; list response has no repository write. Controller is feature-gated and relies on service/policy interfaces. No production implementations found in the reviewed main Java source. | [CernerAllergyHttpClient][allergyclient], [CernerAllergyMapper][allergymapper], [CernerAllergyController][allergycontroller] |

Bundle is a transport envelope in these flows, not proof of a separate stored clinical record. Resource names used only in interface comments or category mappings are not added to this inventory as consumed types.

## Shared stores, identity, and provenance

| Store | Key and content | Time/history rules | Evidence |
| --- | --- | --- | --- |
| `ehr_source` | Source code, display name, FHIR version, enabled flag. Seed codes include MEDICARE, EPIC, ATHENAHEALTH, ORACLE_HEALTH. A seed is not a working connector. | Shared audit timestamps. | [EhrSource][source], [SchemaPatchRunner][patches] |
| `ehr_patient_crosswalk` | Internal `patient_id`, `source_id`, external patient ID; link state and credential fields also exist for Medicare. Unique source/external and patient/source pairs. Pending links can have no external ID. Medicare token/refresh-token fields are String columns without an encryption converter on this entity; verify storage protection separately from Epic encrypted credential fields. | Link lifecycle is distinct from record retention. Do not match patients by name and date of birth. | [EhrPatientCrosswalk][crosswalk], [MedicareConnectionService][medconnect] |
| `ehr_raw_payload` | Row ID, patient/source IDs, resource type, external record ID, JSONB payload, UTF-8 size, `photo_stripped`. | `retrieved_at` is separate from `created_at`/`updated_at`. Raw record ID alone is not globally unique. Writers differ on append versus overwrite; see below. | [EhrRawPayload][raw] |
| `ehr_resource` | Unique user/source/type/FHIR-ID tuple; status, title, occurred-at string, content hash, full JSON mirror. This store uses a user ID, while canonical tables use a patient ID. | `last_synced_at` and `created_at`. This is a current mirror, not the raw history table. | [EhrResource][mirror] |
| `ehr_source_identity` | Patient/source pair; given/family name, full DOB, phone/email, address, member ID, gender, managing organization, language. | Source update instant plus shared audit timestamps. Medicare cache updates the existing identity row. | [EhrSourceIdentity][identity], [MedicareRecordCache][cache] |
| `ehr_coverage_record` | Patient/source/external coverage ID; subscriber ID, beneficiary, network, payor, status, coverage type, end date. | Source update instant plus audit timestamps. | [EhrCoverageRecord][coverage] |
| `ehr_visit_record` | Patient/source/external visit ID from ExplanationOfBenefit; service date, facility, care team, diagnosis, procedure, prescription, disposition, referral, accident, status, visit type, notes. | Source update instant plus audit timestamps. | [EhrVisitRecord][visit] |
| `ehr_appointment_record` | Patient/source/external appointment ID; optional raw-row link, start/end, status, provider/location/service/reason. | Source created/updated times plus audit timestamps. Prototype use must not be called deployed ingestion. | [EhrAppointmentRecord][appointmentmodel], [EhrAppointmentMapper][appointmentmapper] |
| `ehr_identity_conflict` / `ehr_identity_field_provenance` | Field-level conflict values and resolution; selected field source and timestamp. Conflict values contain patient information. | Pending conflicts are not aged out by the retention worker. Field provenance is deliberately retained. | [EhrIdentityConflict][conflicts], [EhrRetentionWorker][retention], [EhrSourceDataPurger][purger] |
| `ehr_audit_event` | Retrieval outcome/count/actor/time and hashed event details through EhrAuditService. Keep payloads and tokens out of audit details. | The retention worker targets this store; a complete cross-app access-log review is still needed. | [EhrAuditEvent][audit], [EhrAuditService][accessaudit], [EhrRetentionWorker][retention] |
| `ehr_credentials` | User/source, FHIR patient ID/base URL, encrypted token fields, scopes, expiry/state. Record field names only; never copy token values into a review. | Epic disconnect deletes its credential rows. | [EhrCredential][credentials], [EpicOAuthService][epicoauth] |
| Search/index copies | Epic creates transactional index events and retrieval chunks for supported clinical types. These are extra copies to include in lifecycle review. | Epic disconnect removes indexed sources before mirror rows. Outbox/in-flight behavior still needs a live check. | [EpicSyncService][epic], [EpicResourceChunker][chunker] |

## How each source writes data

**Medicare.** The cache reads stored raw rows newest-first, then selects one per external ID. It appends a raw row only if parsed JSON changed. Patient photos are removed before serialization. It also maps Patient to identity, Coverage to coverage, and ExplanationOfBenefit to visits. Source metadata is retained in raw JSON. Refresh uses the last successful/empty retrieval audit event; a newly emptied cache forces a full fetch. This is cache freshness, not a retention period. See [cache][cache] and [EhrService][ehrservice].

**Epic.** Full sync can use `$everything`, direct Patient read, and typed searches. Delta sync uses a watermark and safety margin. It mirrors only its allowlisted types and applies the status gate. Each resource is saved in its own transaction. The raw write appends a row whenever `upsertAndEmit` reaches it; the method has no unchanged-body early return before that save. Raw writes are skipped when canonical patient/source IDs are missing. The raw writer removes a top-level photo, but the mirror serializes the original resource first. Thus the raw table's stripping flag does not prove the mirror is free of inline binary. See [Epic sync][epic].

**athenahealth.** Each type needs a granted system scope. MedicationRequest also uses `intent=order`. Both mirror and raw JSON pass through `InlineBinary.strip`: Patient.photo and attachment data with a contentType are removed. Raw history is appended only when the hash changes; the mirror's last-sync time moves on each save. A complete type fetch prunes missing mirror records; an incomplete fetch does not. Pruning does not delete old raw history. See [athena sync][athena] and [InlineBinary][binary].

**Cerner/shared Appointment.** Both existing writers look up a matching raw row and overwrite it, unlike the append-only pattern above. The Cerner prototype validates the trusted source/patient link before writes and rejects a stale or unknown version over a timestamped record. It preserves original JSON and maps UTC-normalized times into the appointment. The shared sync uses its mapper directly and does not provide the same prototype checks. The code contains both `client/ehr/EhrApiClient` and `service/ehr/EhrApiClient`; the shared appointment service imports the former, while Epic/athena clients implement the latter. Do not assume those clients are wired into appointment sync. See [prototype][cerner], [shared sync][appointments], and the two interfaces [old][oldclient]/[current][newclient].

**Cerner allergy fields.** The mapper returns source, source record ID, substance text/code, clinical and verification status, severity, recorded date, and reaction text. It rejects another patient's reference and excludes entered-in-error records. The HTTP client rejects a next-page link instead of returning a partial list. No persistent allergy store was found in this path. See [allergy mapper][allergymapper] and [client][allergyclient].

## Retention, delete, unlink, and relink

These are code findings, not legal advice or proof that a job ran in deployment.

| Path | Observed behavior | Review needed |
| --- | --- | --- |
| Scheduled retention | Worker defaults to 7 years and age 25; both conditions must hold. Unknown/unreadable DOB is retained. Targets raw payloads, resolved conflicts, identity snapshots, retrieval audit, coverage, and visits. Years at or below zero disables purge. | Team B must confirm chosen policy, deployed settings, and execution evidence. Mirror, appointment, credential, consent, and search stores are not all covered by this worker. [Worker][retention] |
| Medicare disconnect | Revokes source token where available; transaction deletes raw, identity, coverage, visits, conflicts, and crosswalk. Retrieval audit remains. Cache handles relink after payloads were removed. | Confirm retention-versus-unlink decision and run source-specific lifecycle tests. [Connection][medconnect], [cache][cache] |
| athena disconnect | Transaction calls shared purger for mirror, raw, identity, conflicts, and crosswalk; may revoke import consent when no Epic connection remains. Audit and already applied demographics/provenance stay. | Shared purger does not delete coverage, visit, appointment, or retrieval-index rows. Confirm which are applicable to each caller. [Connection][athenaconnect], [purger][purger] |
| Epic disconnect | Controller deletes credentials, revokes import consent, then removes Epic index sources and mirror rows. | No raw-payload/crosswalk deletion found in this call chain. Confirm intended policy and canonical cleanup. The controller is not one shared transaction around all steps. [Controller][epiccontroller], [OAuth][epicoauth], [sync][epic] |
| Source record removed/invalidated | athena prunes mirror rows only after a complete fetch. Epic skips disallowed resources; its sync path does not establish a full missing-record purge. Medicare incremental cache keeps prior records not replaced by new results. | Define and test vendor deletion/status handling for every source, including raw history and search copies. [Status gate][status], [sync][epic], [cache][cache], [athena][athena] |
| Record-scoped CR-2 grants | Existing consent model has patient/grantee scope and lifecycle fields; this branch has AI_RETRIEVAL, MEDICARE_VIEW, EHR_IMPORT. | No source/type/record key in this model. Settle one shared model before adding sharing. Grant expiry must be checked on reads; a cleanup schedule alone is not authorization. [ConsentGrant][consent] |

## Schema and environment limits

Entities and `SchemaPatchRunner` are the main schema evidence. The canonical SQL file says it is a reference, not an executed migration. Flyway is disabled in the main properties. The main properties also set `ddl-auto=none`, despite nearby comments describing update-based deployment; profile settings and deployment must be checked before claiming tables or constraints exist. No PostgreSQL catalog or deployed profile was inspected here. See [properties][properties], [schema reference][schema], and [runner][patches].

The canonical schema explicitly leaves organization/tenant scoping unresolved. Source codes identify systems; they do not prove tenant isolation. Team B and affected leads must define organization rules before cross-user sharing.

## Team B review and next actions

| Priority | Proposed contact | Decision or evidence requested |
| --- | --- | --- |
| 1 | Ian Ard / Team B (`@ianscottard`) | Check this inventory against Team B's prerequisite. Name missing stores/types and the owner of each gap. Confirm retention and unlink rules. |
| 1 | Jonathan Barreto / Team C (`@jonathanbarreto37`) | Confirm this baseline for review and the Cerner wiring owner. Route prototype, duplicate-interface, and appointment storage questions. |
| 1 | Epic and athena owners, routed by their leads | Confirm actual granted types and enabled settings; resolve Epic canonical cleanup, binary handling, and deletion/status behavior. |
| 1 | Medicare / shared-schema owner | Confirm append-history policy, cache behavior, source identity rules, and all required indexes/FKs in PostgreSQL. |
| 2 | Crystal Schelmety / PM (`@cschel`) and affected leads | Record CR-2 scope/deadline and shared consent decisions. This inventory does not approve the pilot. |
| 2 | Tiffany / Test Lead, plus security/privacy reviewers | Assign current PostgreSQL and lifecycle checks, defect owners, and acceptance criteria. |

Names/handles for PM, Team B lead, and Team C lead are supported by `.github/CODEOWNERS` and issue #305. Other owner assignments need lead confirmation.

Suggested review result: list each finding as accepted, needs correction, or needs another team's evidence. Record reviewer, date, reviewed commit, issue/PR link, owner, and due date. Only mark the prerequisite complete after Team B confirms coverage and any required fixes.

## Checks performed and limits

- Fetched the remote branch explicitly into its tracking ref and verified the reviewed commit against the remote head.
- Searched main Java, resource/schema, and related test paths for FHIR fetch, save, purge, and access paths. Read the source files linked below.
- Checked main-source callers to distinguish Cerner prototypes from wired services.
- Read issue #305's current discussion for Team B's request and PM's conditional pilot recommendation.
- Verified local existence of each linked source file and checked this documentation diff for whitespace errors.
- No app tests, database queries, vendor calls, or deployed UI checks were run. Existing tests are listed below as follow-up targets, not fresh passing results.

Relevant test targets: `MedicareRecordCacheTest`, `MedicareRecordCachePostgresTest`, `EpicSyncServiceCanonicalWriteTest`, `EpicSyncServiceDeltaTest`, `AthenaSyncServiceTest`, `EhrRetentionWorkerTest`, `EhrRetentionQueriesPostgresTest`, `EhrSourceDataPurgerTest`, `EhrSourceDataPurgerPostgresTest`, `CernerStorageAdapterTest`.

## Pinned evidence

[cache]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/MedicareRecordCache.java
[medicare]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/MedicareService.java
[epic]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EpicSyncService.java
[athena]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/athena/AthenaSyncService.java
[appointments]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EhrAppointmentSyncService.java
[cerner]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/CernerStorageAdapter.java
[mapper]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/cerner/CernerResourceMapper.java
[allergyclient]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/integration/cerner/CernerAllergyHttpClient.java
[allergymapper]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/integration/cerner/CernerAllergyMapper.java
[allergycontroller]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/integration/cerner/CernerAllergyController.java
[source]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrSource.java
[patches]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/config/SchemaPatchRunner.java
[crosswalk]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrPatientCrosswalk.java
[medconnect]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/MedicareConnectionService.java
[raw]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrRawPayload.java
[mirror]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrResource.java
[identity]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrSourceIdentity.java
[coverage]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrCoverageRecord.java
[visit]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrVisitRecord.java
[appointmentmodel]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrAppointmentRecord.java
[appointmentmapper]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EhrAppointmentMapper.java
[conflicts]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrIdentityConflict.java
[retention]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EhrRetentionWorker.java
[purger]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EhrSourceDataPurger.java
[audit]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrAuditEvent.java
[accessaudit]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EhrAuditService.java
[credentials]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ehr/EhrCredential.java
[epicoauth]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EpicOAuthService.java
[chunker]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ai/indexing/chunker/EpicResourceChunker.java
[ehrservice]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EhrService.java
[binary]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/athena/InlineBinary.java
[oldclient]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/client/ehr/EhrApiClient.java
[newclient]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EhrApiClient.java
[athenaconnect]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/athena/AthenaConnectionService.java
[epiccontroller]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/controller/EpicOAuthController.java
[status]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EhrStatusGate.java
[consent]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ConsentGrant.java
[properties]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/resources/application.properties
[schema]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/resources/db/migration/V2609261500__create_ehr_canonical_schema.sql

Review request: https://github.com/umgc/2026_fall_careconnect/issues/305
