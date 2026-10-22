# M4 requirements and evidence table

October 22, 2026 (America/New_York). Prepared for Terence Boyce, Technical Architect; Jonathan, Team C lead; and Tiffany, Test Lead.
Status: review draft. Code baseline: `team-c-develop` at `21d5a521e87f70eb9c304bd5d993d24cdad9adad`.

## Purpose and use

This table shows what supports each personal task, what is still missing, and who should review it. It does not change the WBS, task owners, hours, dates, or completion bands. Proposed contacts below are routing suggestions, not new assignments.

The October 21 remaining-work plan is the task list for this review. The repo's older M1/M3 reports are dated evidence; they do not define a newly approved M4 baseline. CR-2 is still a proposed change: its review fields do not establish approval. The user reported no known approval. Scope and access-rule changes need the lead/PM decision recorded in [issue #305][cr].

**Evidence terms:** Code found means the file or test exists. Past result means an earlier run was reported. Not verified means current execution or acceptance was not established. A merged PR is not Test Lead or release acceptance.

## Current evidence register

| Item | What was verified in this review | Limit |
| --- | --- | --- |
| App baseline | Fresh explicit fetch and remote-head check gave the SHA above. | Jonathan must choose the final accepted candidate. |
| Storage inventory | [PR #395][inventory-pr] is OPEN and DRAFT; head `a3ca31cdd41e9352ce39d1dea70ffb40f3c7daaf`. [Inventory at that head][inventory] contains 39 pinned source links. | Team B acceptance is not recorded by this review. |
| Prior contribution PRs | #79, #331, #347, #348, #349, #355 and #387 are merged into Team C. #387 merged at October 21, 8:02 p.m. EDT. | Merge is bounded evidence of inclusion, not current execution or scope-wide acceptance. |
| Prior CI | [Develop Merge CI run 39492352193][ci] reports success at `29ca58e49ab757595061a94ecfcf8b34af789007`. | It is a different SHA from this review baseline. Do not attach its success to the newer commit. |
| Current SHA checks | GitHub check-runs query returned `total_count: 0` for this review SHA. | This is an API observation, not a claim that all possible CI systems failed or never ran. Request the exact candidate's evidence. |
| Old local suites | [October 17 validation][validation] records affected backend/language results and broad failures at its own baseline. | Not rerun here. Old failures are not proof that the current branch fails. |
| Local consent demo | Course file `input/M4_Final/README/VALIDATION.md` reports 17 Python/SQLite tests passed October 21. Test methods were inspected locally. | Local synthetic demo only; not included in this PR, not rerun here, and not evidence of CareConnect endpoints, PostgreSQL, UI, or real auth. |
| Live workbook | Not opened in this review. | WBS references below come from the October 21 plan and repo reports. No live status or labor update is claimed. |

## Personal task closure table

| WBS / task | Requirement or acceptance focus | Existing design/code/test evidence | Missing proof / next action | Proposed contact and closure check |
| --- | --- | --- | --- | --- |
| 4.1.6 String extraction | Exact assigned string-extraction scope must be identified and checked. | [Old WBS review][wbs], [architecture audit][architecture], current [picker tests][language]. | Original named extraction section is not established. Current picker file has two tests; the earlier named visible-text switch test was not found in that file or a targeted frontend test search. Find any replacement and review its assertions before adding a test. | Jonathan confirms scope; Terence maps that scope to files and proof. Prior Done status is not changed. |
| 4.2.5 i18n tests/review/integration | Named i18n regression scope, distinct from whole-app translation. | Merged #331/#348; [dated validation][validation]; newer #387. | Preserve earlier completion evidence. Check whether the prior switch regression was replaced or lost at the current baseline; do not infer current behavior from 89 historical passes. | Jonathan/Tiffany decide whether current regression follow-up is needed; no percentage change here. |
| 4.2.6 Quality and review | Required independent reviews, dependency 4.1.5, and accepted candidate. | [Review packet][m1review], [trace][m3trace], merged fixes #347/#348/#355. | Lead names candidate and resolves 4.1.5; reviewers record decisions and defect dispositions. | Jonathan routes reviewers; each names date, SHA, scope, decision, and any conditions. |
| 4.2.7 Repo/build/CI | Reproducible candidate build and required checks; branch controls. | [Build baseline][build], [workflow][workflow], earlier [CI][ci]. | Obtain exact current/final candidate results and artifacts. A maintainer must provide detailed branch rules; prior 404 was not proof of no rules. Reuse valid artifacts; rerun when SHA or coverage requires it. | Jonathan/maintainer plus Tiffany review checks, failures, dispositions, and rule evidence. |
| 4.2.8 Architecture/handoff audit | Narrow localization architecture audit. | [Audit][architecture]; merged #79. | No new work identified for that narrow audit. Do not count it as Cerner architecture acceptance. | Retain scope-specific evidence; final app handoff is separate. |
| 4.2.9 Mapping and provenance | Approved resources, mapping rules, storage and source/patient identity. | [Inventory][inventory], [adapter][adapter], [mapping tests][adaptertest], merged #347. | Team B checks full store coverage; source owners approve profiles/fields; run PostgreSQL replay/rollback/concurrency checks on the candidate. | Ian/Team B, Jonathan, source/schema owners. Close only with named review and agreed gaps resolved or formally accepted. |
| 4.2.10 Trust boundary/accessibility | Real auth, record isolation, organization rules, data minimization, accessible flow. | [Controller][controller], [mock-policy tests][controllertest], [consent code][consent], [inventory][inventory]. | Approve record-scoped design; verify real security filters, token/encryption handling, and UI with keyboard/screen reader. Prototype tests do not meet these gates. | Jonathan assigns security/privacy/accessibility reviewers; Tiffany records results against the accepted scope. |
| 4.2.11 TDD/test plan | Controlled requirement and API baseline; exact trace, test results, defects, and Test Lead decision. | [M1 review][m1review], [M3 test plan][m3plan], [M3 trace][m3trace], table below. | Obtain approved SRS/TDD/OpenAPI versions and checksums. Reconcile proposed CR-2 with current baseline. Old QA thresholds remain proposals/history until confirmed for M4. | Tiffany and document/contract owners approve references and each required test/disposition. |
| 4.5.4 Deliverable handoff | Agreed package, resolved dependency 2.5, delivery and receipt. | Dated handoff checklist in [WBS review][wbs]; inventory PR and this draft. | Name receiver/channel; settle 2.5; assemble accepted docs, code/test links, setup, known gaps, and review record. Deliver only the agreed package, then capture receipt. | Jonathan/document owner/receiver; record package version, accepted SHA, date, and receipt. |
| 4.5.6 Final check handoff | Final candidate checks, approved artifacts, named decisions, receipt. | [CI workflow][workflow], review packet and handoff checklist. | Complete current app/regression/integration checks, independent review, package checks, and receiver confirmation. | Tiffany plus Jonathan/receiver; no closure from local docs or green unit tests alone. |
| 4.5.7 Draft lessons | Existing draft criterion, distinct from final retrospective. | October 21 plan records Done; [dated WBS review][wbs] cites prior lesson files. | Exact cited personal lesson files were not found by a targeted search under current repo docs. Preserve the historical claim; attach their controlled location if needed for handoff. | Terence locates draft; Jonathan confirms scope. Final retrospective is separate. |
| 4.5.1 Support for Tiffany's task | Cerner HTTP-client contribution within the owner's larger integration task. | Merged #349; [client][http] and [loopback tests][httptest]. | Owner must accept the full task: app wiring, trusted links, approved errors/retry/refresh/paging, localized UI and E2E. | Tiffany owns task closure. Do not change her completion value from this packet. |

## Requirement-to-code-to-test table

Rows T01–T12 are document row labels, not official SRS or WBS IDs. Requirement IDs shown are references from the repo trace or CR-2; their controlled M4 versions still need approval. Test names are inspected code evidence, not fresh passing results.

| Row / requirement source | Design or code | Exact existing test / proposed verification | Evidence state and remaining acceptance |
| --- | --- | --- | --- |
| T01 — Team B storage prerequisite in #305; 4.2.9 | [Inventory][inventory]; shared stores and per-source paths | Team B checks every fetch type, table, writer, source/patient key, timestamp, delete/unlink path. | Draft review artifact exists. Ian/source owners must confirm coverage; no new implementation requested by this row. |
| T02 — M3-REQ-01/02: deterministic mapping and dates | [Allergy mapper][allergy], [adapter][adapter] | `CernerAllergyMapperTest.completeResourceMapsAllFields`, `invalidCalendarDatesRejected`; `CernerStorageAdapterTest.utcInstantAndOriginalOffsetBothSurvive`. | Code/tests found; dated results in #347/#348. Approved profiles and current-candidate run pending. |
| T03 — M3-REQ-03/12: trusted patient/source and provenance | [Adapter][adapter] | `CernerStorageAdapterTest.wrongPatientIsRejectedBeforeAnyStorage`, `absoluteReferenceFromAnotherTenantIsRejected`, `sameExternalIdAtSeparateSourcesStaysSeparate`. | Prototype/mock proof only. Real request identity chain and organization policy pending. |
| T04 — M3-REQ-04/06/09: retrieval, malformed data, denials | [Client][http], [controller][controller] | `CernerAllergyHttpClientIntegrationTest.mapsSharedFixtureAndSendsToken`, `malformedJsonIsNotEmptySuccess`, `wrongPatientRejectsResponse`; `CernerAllergyControllerTest.unauthenticated`, `forbidden`. | Loopback/mock tests found. Source access, real security filters and deployed app wiring not verified. |
| T05 — M3-REQ-05/07/08: refresh, retry, pagination | [Client][http] | `CernerAllergyHttpClientIntegrationTest.timeoutDoesNotLoop`, `paginationExplicitlyBlocked`, `translatesFailuresWithoutRetryOrRedirect`. | Existing client rejects pagination and does not retry or refresh. These tests do not prove full paged retrieval or refresh. Tiffany/source owners must agree the contract and needed implementation. |
| T06 — CR-2 recipient-by-email, selected record, view-only | [Grant][grant], [consent service][consent] show patient/grantee scope, not a record key. | Local demo: `test_wrong_record_and_recipient_denied`, `test_unknown_recipient_rejected`, `test_only_owner_can_share_or_revoke`. Plan authenticated API and UI checks for registered email lookup, wrong user/source/record, editing/export/resharing denial. | Demo uses user IDs, not email lookup. No record-share app path established by this review. PM/affected leads must approve scope; Tiffany defines app assertions. |
| T07 — CR-2 90-day expiry; updates do not extend | Existing [consent service][consent] refreshes grants; it cannot be assumed to meet fixed record-share expiry. | Local demo: `test_expiry_boundary`, `test_updates_and_repeat_share_preserve_deadline`. Plan API reads immediately before/at/after expiry and after record update. | Demo result is dated October 21; app implementation/current run pending. Check expiry on every read, independent of cleanup. |
| T08 — CR-2 revoke, unlink and relink | [Purger][purger], [Medicare cache][cache], source-specific paths in [inventory][inventory] | Local demo: `test_revoke_blocks_read_and_ai_immediately`, `test_unlink_and_relink_do_not_restore_share`; `MedicareRecordCacheTest.relinkInsideTheDayRefetches`. Plan PostgreSQL and authenticated lifecycle tests. | Existing cache test covers Medicare cache, not CR-2 grants. Review Epic raw/crosswalk cleanup and stale search/outbox copies. Source and consent owners must define outcome. |
| T09 — Storage history, data minimization, retention | [Retention worker][retention], [Epic][epic], [athena][athena] | `EhrRetentionWorkerTest.purgesAdultPastRetentionPeriod`, `keepsRecordOfMinorUntilAge25`, `unknownDateOfBirthIsKept`; `MedicareRecordCacheTest.patientPhotoStrippedAndIdentityUpdated`; [PostgreSQL purger test][purgetest]. | Code found. Confirm policy/settings, PostgreSQL execution, binary copies, concurrency, and source-specific append/overwrite differences. This is policy inspection, not legal validation. |
| T10 — M3-REQ-10/11: approved API, retrieval-only UI, accessibility | [M3 trace][m3trace] and [review][m1review] | Plan contract validation using one approved checksum; integrated loading/success/empty/denied/expired/reconnect/partial states; keyboard/focus/screen-reader/zoom checks. | Controlled contract and current UI/manual results not established. Named reviewers and accepted platform/resource scope pending. |
| T11 — i18n regression scope | [Current picker tests][language] | Existing tests: `uses a centered dialog with only supported choices`; `System Default clears an explicit selection`. Reconcile prior visible-text switch test or replacement; then run approved focused suites. | Two named tests found. Earlier visible-text switch test not found in targeted current test search. No current language test run. Preserve old success as history. |
| T12 — M3-REQ-13/14/15 and final handoff | [Workflow][workflow], [trace][m3trace], final package | Candidate-specific unit/widget/build/coverage, required integration/E2E, approved synthetic sandbox smoke, defect decisions, review and receipt. | Earlier CI is green at a different SHA. Workflow explicitly excludes E2E/integration at that stage. No exact-SHA check runs returned; release acceptance and receipt pending. |

## Next work, in order

1. Terence/Jonathan: ask Ian to review #395 and record coverage/gap decisions. No new shared schema change is needed to review the inventory.
2. Jonathan/PM: name approved CR-2 scope, app candidate, deadline, owners, and reviewers; resolve dependencies 4.1.5 and 2.5. The plan's October 31 versus November 4 dates remain unconfirmed.
3. Terence/Tiffany: locate the original 4.1.6 scope, reconcile the missing switch-test evidence, and select the current checks. Do not rebuild a removed test until its intended replacement and behavior are checked.
4. Contract/document owners with Tiffany: attach the controlled SRS, TDD, API version/checksum and accepted criteria. Link each approved requirement to exact code/test methods and immutable result artifacts.
5. Assigned owners: run only the tests needed for the chosen candidate and gaps. Record failures, owner, disposition, and retest evidence. Keep local demo, loopback, PostgreSQL, live integration, and accessibility results separate.
6. Terence: assemble the handoff index after decisions are in place. Jonathan names the receiver/channel; obtain receipt before closing handoff tasks.

## Review and closure record

No reviewer has signed this table. A PR approval should specify which task/requirement it accepts; general merge approval alone does not close all rows.

| Task/row | Reviewer / role | Reviewed SHA and artifact | Decision / conditions | Result or defect link | Date / receipt |
| --- | --- | --- | --- | --- | --- |
| Team B inventory / T01 | Pending | PR #395 | Pending | Pending | Pending |
| Scope/dependencies | Jonathan / PM, pending | #305 and selected candidate | Pending | Pending | Pending |
| Test baseline / T02–T12 | Tiffany, pending | Controlled docs and selected candidate | Pending | Pending | Pending |
| Security/privacy/accessibility | Assigned reviewers pending | Selected candidate/platform | Pending | Pending | Pending |
| 4.5.4 / 4.5.6 | Named receiver pending | Final package pending | Pending | Pending | Pending |

## Source and validation notes

Course-only inputs read: `M4_Remaining_Work_Plan_2026-10-21.md`, `M4_Evidence_Review_2026-10-21.md` from the prior inventory review, and `README/VALIDATION.md` in `input/M4_Final`. These local files are not attached to this PR. Their claims are labeled with their dates and are not promoted to current app results.

Validation for this documentation change: checked each pinned repo source path; checked each named Java and local demo test method; verified all Markdown reference labels; checked the staged diff. Live GitHub reads checked branch head, cited PR states, current-SHA checks, recent branch runs, and #305. No app tests, database queries, vendor calls, live workbook edits, or reviewer sign-offs were performed.

## Pinned sources

[wbs]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/docs/testing/team-c-wbs-review-2026-10-13.md
[validation]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/docs/testing/team-c-task-validation-2026-10-17.md
[fixture-review]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/docs/testing/team-c-docs-fixtures-review-2026-10-17.md
[m3trace]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/docs/testing/m3-traceability-matrix.md
[m3plan]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/docs/testing/m3-test-plan.md
[m1review]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/docs/testing/team-c-m1-test-lead-review-2026-10-17.md
[build]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/docs/TEAM_C_REPOSITORY_BUILD_CI_BASELINE.md
[architecture]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/docs/TEAM_C_FRONTEND_ARCHITECTURE_AUDIT.md
[workflow]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/.github/workflows/develop-merge-ci.yml
[language]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/frontend/test/widgets/language/language_picker_test.dart
[consent]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/consent/ConsentService.java
[grant]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/model/ConsentGrant.java
[adapter]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/CernerStorageAdapter.java
[adaptertest]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/test/java/com/careconnect/service/ehr/CernerStorageAdapterTest.java
[allergy]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/integration/cerner/CernerAllergyMapper.java
[allergytest]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/test/java/com/careconnect/integration/cerner/CernerAllergyMapperTest.java
[controller]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/integration/cerner/CernerAllergyController.java
[controllertest]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/test/java/com/careconnect/integration/cerner/CernerAllergyControllerTest.java
[http]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/integration/cerner/CernerAllergyHttpClient.java
[httptest]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/test/java/com/careconnect/integration/cerner/CernerAllergyHttpClientIntegrationTest.java
[cache]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/MedicareRecordCache.java
[cachetest]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/test/java/com/careconnect/service/ehr/MedicareRecordCacheTest.java
[purger]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EhrSourceDataPurger.java
[purgetest]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/test/java/com/careconnect/service/ehr/EhrSourceDataPurgerPostgresTest.java
[retention]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EhrRetentionWorker.java
[retentiontest]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/test/java/com/careconnect/service/ehr/EhrRetentionWorkerTest.java
[epic]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/EpicSyncService.java
[athena]: https://github.com/umgc/2026_fall_careconnect/blob/21d5a521e87f70eb9c304bd5d993d24cdad9adad/backend/core/src/main/java/com/careconnect/service/ehr/athena/AthenaSyncService.java
[cr]: https://github.com/umgc/2026_fall_careconnect/issues/305
[inventory-pr]: https://github.com/umgc/2026_fall_careconnect/pull/395
[inventory]: https://github.com/umgc/2026_fall_careconnect/blob/a3ca31cdd41e9352ce39d1dea70ffb40f3c7daaf/docs/team-c/FHIR_STORAGE_INVENTORY_2026-10-22.md
[ci]: https://github.com/umgc/2026_fall_careconnect/actions/runs/39492352193
