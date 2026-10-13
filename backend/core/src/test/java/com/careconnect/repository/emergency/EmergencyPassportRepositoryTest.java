package com.careconnect.repository.emergency;

import com.careconnect.model.emergency.BloodType;
import com.careconnect.model.emergency.EmergencyPassportFieldVisibility;
import com.careconnect.model.emergency.EmergencyPassportProfile;
import com.careconnect.model.emergency.PassportField;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Entity mapping and repository behaviour for the CC-12 Increment 1 passport tables, on the H2 test
 * profile. Covers what the entities themselves declare: column mapping, the hidden-by-default rule
 * and the two unique constraints.
 * <p>
 * The foreign keys, cascade and {@code TIMESTAMPTZ} columns come from {@code SchemaPatchRunner},
 * which skips its PostgreSQL patches on H2; {@link EmergencyPassportSchemaPostgresTest} covers those.
 * Patient ids are bare longs here because H2 has no foreign key to satisfy.
 * <p>
 * No Test Plan IDs yet: they are issued by the Testing Lead, not chosen by the author.
 */
@DataJpaTest
@ActiveProfiles("test")
@DisplayName("Emergency passport repositories (CC-12 Increment 1)")
class EmergencyPassportRepositoryTest {

    @Autowired
    private EmergencyPassportProfileRepository profileRepository;

    @Autowired
    private EmergencyPassportFieldVisibilityRepository visibilityRepository;

    @Test
    @DisplayName("a profile round-trips every field, blood type stored by enum name")
    void profileRoundTrips() {
        profileRepository.saveAndFlush(EmergencyPassportProfile.builder()
                .patientId(101L)
                .bloodType(BloodType.AB_NEGATIVE)
                .chronicConditions("Type 2 diabetes; atrial fibrillation")
                .emergencyContactName("Dana Example")
                .emergencyContactPhone("+1-555-0100")
                .emergencyContactRelationship("daughter")
                .build());

        EmergencyPassportProfile reloaded = profileRepository.findByPatientId(101L).orElseThrow();
        assertThat(reloaded.getBloodType()).isEqualTo(BloodType.AB_NEGATIVE);
        assertThat(reloaded.getChronicConditions()).isEqualTo("Type 2 diabetes; atrial fibrillation");
        assertThat(reloaded.getEmergencyContactName()).isEqualTo("Dana Example");
        assertThat(reloaded.getEmergencyContactPhone()).isEqualTo("+1-555-0100");
        assertThat(reloaded.getEmergencyContactRelationship()).isEqualTo("daughter");
        assertThat(reloaded.getCreatedAt()).isNotNull();
        assertThat(reloaded.getUpdatedAt()).isNotNull();
    }

    @Test
    @DisplayName("a profile may leave every value empty")
    void emptyProfileIsAllowed() {
        profileRepository.saveAndFlush(EmergencyPassportProfile.builder().patientId(102L).build());

        EmergencyPassportProfile reloaded = profileRepository.findByPatientId(102L).orElseThrow();
        assertThat(reloaded.getBloodType()).isNull();
        assertThat(reloaded.getChronicConditions()).isNull();
        assertThat(reloaded.getEmergencyContactName()).isNull();
    }

    @Test
    @DisplayName("a patient cannot hold two profiles")
    void secondProfileForOnePatientIsRejected() {
        profileRepository.saveAndFlush(EmergencyPassportProfile.builder().patientId(103L).build());

        assertThatThrownBy(() -> profileRepository.saveAndFlush(
                EmergencyPassportProfile.builder().patientId(103L).build()))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    @DisplayName("a visibility row built without is_public is hidden")
    void visibilityDefaultsToHidden() {
        visibilityRepository.saveAndFlush(EmergencyPassportFieldVisibility.builder()
                .patientId(104L)
                .fieldKey(PassportField.BLOOD_TYPE)
                .build());

        assertThat(visibilityRepository.findByPatientIdAndFieldKey(104L, PassportField.BLOOD_TYPE))
                .get().extracting(EmergencyPassportFieldVisibility::getIsPublic).isEqualTo(false);
        assertThat(visibilityRepository.findPublicFields(104L)).isEmpty();
    }

    @Test
    @DisplayName("a patient with no visibility rows shows nothing")
    void noRowsMeansNothingIsPublic() {
        assertThat(visibilityRepository.findPublicFields(105L)).isEmpty();
    }

    @Test
    @DisplayName("only fields explicitly made public are returned, and only for that patient")
    void findPublicFieldsReturnsOnlyExplicitOptIns() {
        // Arrange: patient 106 makes two fields public and one hidden; patient 107 makes one public.
        save(106L, PassportField.ALLERGIES, true);
        save(106L, PassportField.MEDICATIONS, true);
        save(106L, PassportField.EMERGENCY_CONTACT, false);
        save(107L, PassportField.BLOOD_TYPE, true);

        // Assert: CHRONIC_CONDITIONS has no row and EMERGENCY_CONTACT is false; neither appears.
        assertThat(visibilityRepository.findPublicFields(106L))
                .containsExactlyInAnyOrder(PassportField.ALLERGIES, PassportField.MEDICATIONS);
        assertThat(visibilityRepository.findByPatientId(106L)).hasSize(3);
    }

    @Test
    @DisplayName("a patient cannot hold two visibility rows for the same field")
    void secondVisibilityRowForOneFieldIsRejected() {
        save(108L, PassportField.ALLERGIES, false);

        assertThatThrownBy(() -> save(108L, PassportField.ALLERGIES, true))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    private void save(long patientId, PassportField field, boolean isPublic) {
        visibilityRepository.saveAndFlush(EmergencyPassportFieldVisibility.builder()
                .patientId(patientId)
                .fieldKey(field)
                .isPublic(isPublic)
                .build());
    }
}
