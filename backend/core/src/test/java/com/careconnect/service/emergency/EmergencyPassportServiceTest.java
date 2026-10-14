package com.careconnect.service.emergency;

import com.careconnect.dto.emergency.PassportDtos.NewTokenResponse;
import com.careconnect.dto.emergency.PassportDtos.PassportView;
import com.careconnect.dto.emergency.PassportDtos.ProfileRequest;
import com.careconnect.dto.emergency.PassportDtos.PublicPassport;
import com.careconnect.exception.AppException;
import com.careconnect.model.Allergy;
import com.careconnect.model.Medication;
import com.careconnect.model.Patient;
import com.careconnect.model.emergency.BloodType;
import com.careconnect.model.emergency.EmergencyPassportProfile;
import com.careconnect.model.emergency.EmergencyPassportToken;
import com.careconnect.model.emergency.PassportField;
import com.careconnect.repository.AllergyRepository;
import com.careconnect.repository.MedicationRepository;
import com.careconnect.repository.PatientRepository;
import com.careconnect.repository.emergency.EmergencyPassportFieldVisibilityRepository;
import com.careconnect.repository.emergency.EmergencyPassportProfileRepository;
import com.careconnect.repository.emergency.EmergencyPassportTokenRepository;
import com.careconnect.security.TokenHashService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.EnumSet;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The Emergency Care Passport service (CC-12 Increment 2) with its repositories mocked, so the rules
 * are tested without a database: what a scan reveals, which codes it accepts, and how a new code
 * replaces the old one.
 * <p>
 * Token hashing is real BCrypt (at the minimum cost, for speed) rather than a mock, so a test that
 * passes proves the stored hash actually verifies the raw token the patient was given.
 * <p>
 * No Test Plan IDs yet: they are issued by the Testing Lead, not chosen by the author.
 */
class EmergencyPassportServiceTest {

    private static final long PATIENT_ID = 42L;
    /** 2026-10-13, so a patient born 1985-06-14 is 41. */
    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-10-13T12:00:00Z"), ZoneOffset.UTC);
    private static final Instant PROFILE_CHANGED = Instant.parse("2026-03-01T09:00:00Z");
    private static final Instant ALLERGY_CHANGED = Instant.parse("2026-05-01T09:00:00Z");
    private static final Instant MEDICATION_CHANGED = Instant.parse("2026-07-01T09:00:00Z");

    private EmergencyPassportProfileRepository profiles;
    private EmergencyPassportFieldVisibilityRepository visibility;
    private EmergencyPassportTokenRepository tokens;
    private PatientRepository patients;
    private AllergyRepository allergies;
    private MedicationRepository medications;
    private TokenHashService tokenHashService;
    private EmergencyPassportService service;

    @BeforeEach
    void setUp() {
        profiles = mock(EmergencyPassportProfileRepository.class);
        visibility = mock(EmergencyPassportFieldVisibilityRepository.class);
        tokens = mock(EmergencyPassportTokenRepository.class);
        patients = mock(PatientRepository.class);
        allergies = mock(AllergyRepository.class);
        medications = mock(MedicationRepository.class);
        tokenHashService = spy(new TokenHashService());
        ReflectionTestUtils.setField(tokenHashService, "passwordEncoder", new BCryptPasswordEncoder(4));
        service = new EmergencyPassportService(profiles, visibility, tokens, patients, allergies, medications,
                tokenHashService, "https://app.example.test/passport", CLOCK);

        when(patients.findById(PATIENT_ID)).thenReturn(Optional.of(Patient.builder()
                .id(PATIENT_ID).firstName("Jordan").lastName("Miller").dob("1985-06-14").build()));
        when(tokens.saveAndFlush(any(EmergencyPassportToken.class))).thenAnswer(i -> i.getArgument(0));
        when(allergies.findActiveAllergiesByPatientId(PATIENT_ID)).thenReturn(List.of(
                Allergy.builder().allergen("Penicillin").severity(Allergy.AllergySeverity.SEVERE)
                        .reaction("Anaphylaxis").isActive(true).build()));
        when(medications.findActiveByPatientId(PATIENT_ID)).thenReturn(List.of(
                Medication.builder().medicationName("Lisinopril").dosage("10 mg").frequency("Once daily")
                        .approvalStatus("APPROVED").isActive(true).build(),
                Medication.builder().medicationName("Unreviewed").dosage("5 mg").frequency("Once daily")
                        .approvalStatus("PENDING").isActive(true).build()));
        when(profiles.findByPatientId(PATIENT_ID)).thenReturn(Optional.of(EmergencyPassportProfile.builder()
                .patientId(PATIENT_ID).bloodType(BloodType.O_POSITIVE)
                .chronicConditions("Type 2 diabetes")
                .emergencyContactName("Taylor Miller").emergencyContactRelationship("Spouse")
                .emergencyContactPhone("(415) 555-0184").build()));
    }

    // ---- Making and revoking codes ----

    @Test
    @DisplayName("a new code stores only its prefix and a hash that verifies the raw token")
    void newCodeStoresPrefixAndVerifyingHash() {
        // Arrange
        when(tokens.findByPatientIdAndStatus(PATIENT_ID, EmergencyPassportToken.Status.ACTIVE)).thenReturn(List.of());

        // Act
        NewTokenResponse response = service.regenerateToken(PATIENT_ID);

        // Assert
        ArgumentCaptor<EmergencyPassportToken> saved = ArgumentCaptor.forClass(EmergencyPassportToken.class);
        verify(tokens).saveAndFlush(saved.capture());
        EmergencyPassportToken row = saved.getValue();
        assertThat(response.token()).hasSize(43);
        assertThat(response.url()).isEqualTo("https://app.example.test/passport/" + response.token());
        assertThat(row.getTokenLookup()).isEqualTo(response.token().substring(0, 16));
        assertThat(row.getTokenHash()).isNotEqualTo(response.token());
        assertThat(new BCryptPasswordEncoder().matches(response.token(), row.getTokenHash())).isTrue();
        assertThat(row.getStatus()).isEqualTo(EmergencyPassportToken.Status.ACTIVE);
    }

    @Test
    @DisplayName("making a new code revokes the active one before inserting")
    void newCodeRevokesTheOldOne() {
        EmergencyPassportToken old = activeToken("unused-raw-token-value-0000000000");
        when(tokens.findByPatientIdAndStatus(PATIENT_ID, EmergencyPassportToken.Status.ACTIVE)).thenReturn(List.of(old));

        service.regenerateToken(PATIENT_ID);

        assertThat(old.getStatus()).isEqualTo(EmergencyPassportToken.Status.REVOKED);
        assertThat(old.getRevokedAt()).isEqualTo(CLOCK.instant());
        verify(tokens).saveAllAndFlush(List.of(old));
    }

    @Test
    @DisplayName("revoking with no active code is a no-op, not an error")
    void revokeWithoutActiveCodeIsIdempotent() {
        when(tokens.findByPatientIdAndStatus(PATIENT_ID, EmergencyPassportToken.Status.ACTIVE)).thenReturn(List.of());

        service.revokeToken(PATIENT_ID);

        verify(tokens, never()).saveAllAndFlush(any());
    }

    // ---- Which codes a scan accepts ----

    @Test
    @DisplayName("an unknown code is rejected without any hashing")
    void unknownCodeIsRejectedCheaply() {
        when(tokens.findByTokenLookup(anyString())).thenReturn(Optional.empty());

        assertThat(service.scan("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")).isEmpty();
        verify(tokenHashService, never()).verifyToken(anyString(), anyString());
    }

    @Test
    @DisplayName("too-short and too-long codes are rejected before any lookup")
    void malformedCodesAreRejectedBeforeLookup() {
        assertThat(service.scan("short")).isEmpty();
        assertThat(service.scan("x".repeat(200))).isEmpty();
        assertThat(service.scan(null)).isEmpty();
        verify(tokens, never()).findByTokenLookup(anyString());
    }

    @Test
    @DisplayName("a revoked code shows nothing")
    void revokedCodeShowsNothing() {
        String raw = "revokedTokenAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
        EmergencyPassportToken token = activeToken(raw);
        token.setStatus(EmergencyPassportToken.Status.REVOKED);
        when(tokens.findByTokenLookup(raw.substring(0, 16))).thenReturn(Optional.of(token));

        assertThat(service.scan(raw)).isEmpty();
    }

    @Test
    @DisplayName("a code with the right prefix but the wrong secret shows nothing")
    void rightPrefixWrongSecretShowsNothing() {
        String raw = "sharedPrefix0000realSecretAAAAAAAAAAAAAAAAA";
        when(tokens.findByTokenLookup(raw.substring(0, 16))).thenReturn(Optional.of(activeToken(raw)));

        assertThat(service.scan("sharedPrefix0000guessedSecretBBBBBBBBBBBBBB")).isEmpty();
    }

    // ---- What a scan reveals ----

    @Test
    @DisplayName("with nothing shared, a scan shows name and age only")
    void nothingSharedShowsNameAndAgeOnly() {
        String raw = stubActiveCode();
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.noneOf(PassportField.class));

        PublicPassport passport = service.scan(raw).orElseThrow();

        assertThat(passport.name()).isEqualTo("Jordan Miller");
        assertThat(passport.age()).isEqualTo(41);
        assertThat(passport.bloodType()).isNull();
        assertThat(passport.allergies()).isNull();
        assertThat(passport.medications()).isNull();
        assertThat(passport.chronicConditions()).isNull();
        assertThat(passport.emergencyContact()).isNull();
    }

    @Test
    @DisplayName("a scan shows exactly the shared sections, and only approved medications")
    void sharedSectionsAreShownAndHiddenOnesAreNot() {
        String raw = stubActiveCode();
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.of(
                PassportField.BLOOD_TYPE, PassportField.ALLERGIES, PassportField.MEDICATIONS,
                PassportField.EMERGENCY_CONTACT));

        PublicPassport passport = service.scan(raw).orElseThrow();

        assertThat(passport.bloodType()).isEqualTo(BloodType.O_POSITIVE);
        assertThat(passport.allergies()).singleElement()
                .satisfies(a -> {
                    assertThat(a.allergen()).isEqualTo("Penicillin");
                    assertThat(a.severity()).isEqualTo("SEVERE");
                    assertThat(a.reaction()).isEqualTo("Anaphylaxis");
                });
        assertThat(passport.medications()).extracting(m -> m.name()).containsExactly("Lisinopril");
        assertThat(passport.emergencyContact().phone()).isEqualTo("(415) 555-0184");
        assertThat(passport.chronicConditions()).as("not shared").isNull();
    }

    @Test
    @DisplayName("a shared section with nothing in it is left out, not shown as empty")
    void emptySharedListIsAbsent() {
        String raw = stubActiveCode();
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.of(PassportField.ALLERGIES));
        when(allergies.findActiveAllergiesByPatientId(PATIENT_ID)).thenReturn(List.of());

        assertThat(service.scan(raw).orElseThrow().allergies()).isNull();
    }

    @Test
    @DisplayName("a successful scan records when it happened")
    void scanRecordsLastScannedAt() {
        String raw = stubActiveCode();
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.noneOf(PassportField.class));

        service.scan(raw);

        ArgumentCaptor<EmergencyPassportToken> saved = ArgumentCaptor.forClass(EmergencyPassportToken.class);
        verify(tokens).save(saved.capture());
        assertThat(saved.getValue().getLastScannedAt()).isEqualTo(CLOCK.instant());
    }

    // ---- How current a passport is ----

    @Test
    @DisplayName("a scan's lastUpdated is the latest change to the shown sections; a newer hidden section never counts")
    void scanLastUpdatedCountsShownSectionsOnly() {
        String raw = stubActiveCode();
        stubSectionDates();
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.of(
                PassportField.BLOOD_TYPE, PassportField.ALLERGIES));

        PublicPassport passport = service.scan(raw).orElseThrow();

        assertThat(passport.lastUpdated()).as("allergies, not the newer hidden medications")
                .isEqualTo(ALLERGY_CHANGED);
        verify(medications, never()).findActiveByPatientId(PATIENT_ID);
    }

    @Test
    @DisplayName("a recently edited hidden profile section does not move a scan's lastUpdated")
    void hiddenProfileEditDoesNotCount() {
        String raw = stubActiveCode();
        stubSectionDates();
        // The patient just edited their (hidden) conditions and contact.
        profiles.findByPatientId(PATIENT_ID).orElseThrow()
                .setUpdatedAt(LocalDateTime.ofInstant(Instant.parse("2026-10-01T09:00:00Z"), ZoneId.systemDefault()));
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.of(PassportField.ALLERGIES));

        assertThat(service.scan(raw).orElseThrow().lastUpdated()).isEqualTo(ALLERGY_CHANGED);
    }

    @Test
    @DisplayName("a medication that is not approved does not make the passport look newer")
    void unapprovedMedicationDoesNotCount() {
        String raw = stubActiveCode();
        stubSectionDates();
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.of(PassportField.MEDICATIONS));

        assertThat(service.scan(raw).orElseThrow().lastUpdated())
                .as("Lisinopril's date, not the newer PENDING row's").isEqualTo(MEDICATION_CHANGED);
    }

    @Test
    @DisplayName("with nothing shown, a scan has no lastUpdated")
    void nothingShownHasNoLastUpdated() {
        String raw = stubActiveCode();
        stubSectionDates();
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.noneOf(PassportField.class));
        assertThat(service.scan(raw).orElseThrow().lastUpdated()).as("nothing shared").isNull();

        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.of(PassportField.ALLERGIES));
        when(allergies.findActiveAllergiesByPatientId(PATIENT_ID)).thenReturn(List.of());
        assertThat(service.scan(raw).orElseThrow().lastUpdated()).as("shared but empty").isNull();
    }

    @Test
    @DisplayName("the patient's view dates every section with content, shared or not, and falls back to created_at")
    void patientViewDatesEverySection() {
        stubSectionDates();
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.noneOf(PassportField.class));
        when(tokens.findByPatientIdAndStatus(PATIENT_ID, EmergencyPassportToken.Status.ACTIVE)).thenReturn(List.of());
        // An allergy never edited since it was added has no updated_at.
        when(allergies.findActiveAllergiesByPatientId(PATIENT_ID)).thenReturn(List.of(
                Allergy.builder().allergen("Penicillin").isActive(true).createdAt(ALLERGY_CHANGED).build()));

        PassportView view = service.getPassport(PATIENT_ID);

        assertThat(view.lastUpdated()).isEqualTo(MEDICATION_CHANGED);
        assertThat(view.lastUpdatedBySection())
                .containsEntry(PassportField.BLOOD_TYPE, PROFILE_CHANGED)
                .containsEntry(PassportField.CHRONIC_CONDITIONS, PROFILE_CHANGED)
                .containsEntry(PassportField.EMERGENCY_CONTACT, PROFILE_CHANGED)
                .containsEntry(PassportField.ALLERGIES, ALLERGY_CHANGED)
                .containsEntry(PassportField.MEDICATIONS, MEDICATION_CHANGED);
    }

    @Test
    @DisplayName("an empty section has no date in the patient's view")
    void emptySectionHasNoDate() {
        stubSectionDates();
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.noneOf(PassportField.class));
        when(tokens.findByPatientIdAndStatus(PATIENT_ID, EmergencyPassportToken.Status.ACTIVE)).thenReturn(List.of());
        EmergencyPassportProfile bloodTypeOnly = EmergencyPassportProfile.builder()
                .patientId(PATIENT_ID).bloodType(BloodType.A_POSITIVE).build();
        bloodTypeOnly.setUpdatedAt(LocalDateTime.ofInstant(PROFILE_CHANGED, ZoneId.systemDefault()));
        when(profiles.findByPatientId(PATIENT_ID)).thenReturn(Optional.of(bloodTypeOnly));
        when(allergies.findActiveAllergiesByPatientId(PATIENT_ID)).thenReturn(List.of());

        assertThat(service.getPassport(PATIENT_ID).lastUpdatedBySection())
                .containsOnlyKeys(PassportField.BLOOD_TYPE, PassportField.MEDICATIONS);
    }

    // ---- The patient's own view and edits ----

    @Test
    @DisplayName("the passport is ready only with an active code and at least one shared section")
    void readyNeedsActiveCodeAndASharedSection() {
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.of(PassportField.ALLERGIES));
        when(tokens.findByPatientIdAndStatus(PATIENT_ID, EmergencyPassportToken.Status.ACTIVE)).thenReturn(List.of());
        assertThat(service.getPassport(PATIENT_ID).ready()).as("no code").isFalse();

        when(tokens.findByPatientIdAndStatus(PATIENT_ID, EmergencyPassportToken.Status.ACTIVE))
                .thenReturn(List.of(activeToken("x".repeat(43))));
        PassportView view = service.getPassport(PATIENT_ID);
        assertThat(view.ready()).isTrue();
        assertThat(view.sharing()).containsEntry(PassportField.ALLERGIES, true)
                .containsEntry(PassportField.BLOOD_TYPE, false)
                .hasSize(PassportField.values().length);

        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.noneOf(PassportField.class));
        assertThat(service.getPassport(PATIENT_ID).ready()).as("nothing shared").isFalse();
    }

    @Test
    @DisplayName("saving the profile trims values and stores blanks as empty")
    void profileIsTrimmedAndBlanksCleared() {
        when(tokens.findByPatientIdAndStatus(PATIENT_ID, EmergencyPassportToken.Status.ACTIVE)).thenReturn(List.of());
        when(visibility.findPublicFields(PATIENT_ID)).thenReturn(EnumSet.noneOf(PassportField.class));

        service.updateProfile(PATIENT_ID, new ProfileRequest(BloodType.AB_NEGATIVE, "  Asthma  ", " ", "Dana", ""));

        ArgumentCaptor<EmergencyPassportProfile> saved = ArgumentCaptor.forClass(EmergencyPassportProfile.class);
        verify(profiles).save(saved.capture());
        assertThat(saved.getValue().getBloodType()).isEqualTo(BloodType.AB_NEGATIVE);
        assertThat(saved.getValue().getChronicConditions()).isEqualTo("Asthma");
        assertThat(saved.getValue().getEmergencyContactName()).isNull();
        assertThat(saved.getValue().getEmergencyContactRelationship()).isEqualTo("Dana");
        assertThat(saved.getValue().getEmergencyContactPhone()).isNull();
    }

    @Test
    @DisplayName("an over-long field is rejected with 400")
    void overLongFieldIsRejected() {
        ProfileRequest tooLong = new ProfileRequest(null, null, null, null, "1".repeat(33));

        assertThatThrownBy(() -> service.updateProfile(PATIENT_ID, tooLong))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("emergencyContactPhone");
    }

    @Test
    @DisplayName("age is read from ISO and MM/DD/YYYY birth dates, and is absent otherwise")
    void ageHandlesBothStoredFormats() {
        assertThat(service.ageOf("1985-06-14")).isEqualTo(41);
        assertThat(service.ageOf("06/14/1985")).isEqualTo(41);
        assertThat(service.ageOf("10/14/1985")).as("birthday tomorrow").isEqualTo(40);
        assertThat(service.ageOf("June 1985")).isNull();
        assertThat(service.ageOf("2030-01-01")).as("future").isNull();
        assertThat(service.ageOf(null)).isNull();
    }

    // ---- Helpers ----

    /** An active code for {@code raw}, hashed the way the service stores it. */
    private EmergencyPassportToken activeToken(String raw) {
        return EmergencyPassportToken.builder()
                .id(7L)
                .patientId(PATIENT_ID)
                .tokenLookup(raw.substring(0, 16))
                .tokenHash(new BCryptPasswordEncoder(4).encode(raw))
                .status(EmergencyPassportToken.Status.ACTIVE)
                .build();
    }

    /**
     * Profile, then allergy, then the approved medication change, in that order; the PENDING
     * medication is newest of all, so a test sees it if it ever wrongly counts.
     */
    private void stubSectionDates() {
        EmergencyPassportProfile profile = profiles.findByPatientId(PATIENT_ID).orElseThrow();
        profile.setUpdatedAt(LocalDateTime.ofInstant(PROFILE_CHANGED, ZoneId.systemDefault()));
        when(allergies.findActiveAllergiesByPatientId(PATIENT_ID)).thenReturn(List.of(
                Allergy.builder().allergen("Penicillin").severity(Allergy.AllergySeverity.SEVERE)
                        .reaction("Anaphylaxis").isActive(true).updatedAt(ALLERGY_CHANGED).build()));
        when(medications.findActiveByPatientId(PATIENT_ID)).thenReturn(List.of(
                Medication.builder().medicationName("Lisinopril").approvalStatus("APPROVED").isActive(true)
                        .updatedAt(MEDICATION_CHANGED).build(),
                Medication.builder().medicationName("Unreviewed").approvalStatus("PENDING").isActive(true)
                        .updatedAt(Instant.parse("2026-09-01T00:00:00Z")).build()));
    }

    private String stubActiveCode() {
        String raw = "validTokenAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
        when(tokens.findByTokenLookup(raw.substring(0, 16))).thenReturn(Optional.of(activeToken(raw)));
        return raw;
    }
}
