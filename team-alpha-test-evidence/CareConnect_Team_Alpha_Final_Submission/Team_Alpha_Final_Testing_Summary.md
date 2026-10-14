# CareConnect — Team Alpha Final Testing Summary

**Project:** CareConnect
**Course:** SWEN 670
**Team:** Team Alpha
**Evidence Date:** October 10, 2026

## 1. Executive Summary

Team Alpha performed automated testing of the CareConnect Flutter frontend, including accessibility, keyboard navigation, functional behavior, and selected end-to-end test scenarios.

The full Flutter test suite recorded 11,609 passed tests, 8 skipped tests, and 1 failed test. The measured line coverage was 70.7%, exceeding the 60% coverage requirement by 10.7 percentage points.

The full test suite did not achieve a completely passing result because one EVV schedule widget test remains unresolved.

## 2. Full Automated Test Suite

- Total tests: 11,618
- Passed: 11,609
- Skipped: 8
- Failed: 1
- Final result: Completed with one test failure
- Execution command: `ulimit -n 4096 && flutter test --coverage --concurrency=1`
- Primary evidence: `full-suite-coverage-retry.log`

## 3. Code Coverage

- Line coverage: 70.7%
- Covered lines: 54,752
- Instrumented lines: 77,433
- Source files: 516
- Required coverage: 60%
- Result: Coverage requirement met
- HTML report: `CareConnect_HTML_Coverage_Report.zip`

Coverage was measured using Flutter's coverage output and summarized using LCOV. The HTML report was generated using genhtml.

## 4. Accessibility Testing

Team Alpha collected automated accessibility evidence covering login, keyboard navigation, focus behavior, welcome screens, disclaimers, localization, medication-related interfaces, and ADA mail accessibility.

The accessibility test effort recorded 256 unique passing automated test cases with no failures in that accessibility set.

The expanded login keyboard test exercised Tab, Shift+Tab, Enter, password visibility, Forgot Password, and Sign In behavior. These interactions were checked within one automated test, not counted as separate test cases.

Relevant evidence includes:
- `login-accessibility.log`
- `login-keyboard-final.log`
- `login-keyboard-focus.log`
- `medication-accessibility.log`
- `localization-accessibility.log`
- `disclaimer-accessibility.log`
- `disclaimer-scaling.log`
- `welcome-accessibility.log`
- `ada-mail-accessibility.log`

Some login testing output also reported layout overflow warnings. These should be reviewed separately and should not be represented as resolved accessibility issues.

## 5. Functional, Integration, and E2E Evidence

Test execution logs were collected for authentication, AI chat, analytics, EVV, symptom tracking, video calling, and chat/messaging scenarios.

Evidence includes:
- `authentication-test.log`
- `ai-chat-test.log`
- `analytics-test.log`
- `evv-test.log`
- `symptom-tracking-test.log`
- `video-call-test.log`
- `video-call-e2e.log`
- `chat-messaging-e2e.log`
- `chat-messaging-web-e2e.log`
- `chat-messaging-chrome-drive.log`

The presence of these logs documents test execution attempts and collected output; it does not independently establish that every individual scenario passed.

## 6. Unresolved EVV Test Failure

**Test file:** `test/features/evv/schedule_page_test.dart`

**Test:** SchedulePage - with scheduled visits shows Overdue badge for past visit

**Failure location:** Line 481

**Expected:** Exactly one widget containing `Start Overdue Visit`.

**Actual:** No matching widgets were found.

**Status:** Failed; root cause not confirmed.

The test log also contains a Flutter warning that default HttpClient requests return HTTP 400 during widget tests. Whether this contributed to the failure has not been established.

Evidence: `evv-overdue-failure.log`

## 7. Evidence Archives

- `CareConnect_Test_Logs.zip` — Collected testing execution logs
- `CareConnect_HTML_Coverage_Report.zip` — Generated HTML line-coverage report

## 8. Final Assessment

Team Alpha met the 60% line-coverage threshold with 70.7% measured coverage. Extensive automated testing and accessibility evidence were collected.

The final full-suite execution remains partially unsuccessful due to one unresolved EVV widget-test failure. The issue should be investigated and retested before the suite is described as fully passing.

This summary reflects observed testing evidence and does not claim that the application is defect-free.

