package com.careconnect.service.ehr;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.careconnect.client.ehr.EhrApiClient;
import com.careconnect.model.Patient;
import com.careconnect.model.ehr.EhrAppointmentRecord;
import com.careconnect.model.ehr.EhrPatientCrosswalk;
import com.careconnect.model.ehr.EhrRawPayload;
import com.careconnect.model.ehr.EhrSource;
import com.careconnect.repository.ehr.EhrAppointmentRecordRepository;
import com.careconnect.repository.ehr.EhrPatientCrosswalkRepository;
import com.careconnect.repository.ehr.EhrRawPayloadRepository;
import com.careconnect.repository.ehr.EhrSourceRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class EhrAppointmentSyncServiceTest {

    private static final long PATIENT_ID = 7L;
    private static final long SOURCE_ID = 3L;

    private final ObjectMapper json = new ObjectMapper();

    @Mock private EhrSourceRepository sourceRepository;
    @Mock private EhrPatientCrosswalkRepository crosswalkRepository;
    @Mock private EhrRawPayloadRepository rawPayloadRepository;
    @Mock private EhrAppointmentRecordRepository appointmentRepository;
    @Mock private ObjectMapper objectMapper;
    @Mock private EhrApiClient apiClient;
    @InjectMocks private EhrAppointmentSyncService service;

    private Patient patient;
    private EhrSource source;

    @BeforeEach
    void setUp() {
        patient = new Patient();
        patient.setId(PATIENT_ID);
        source = new EhrSource();
        source.setId(SOURCE_ID);
        source.setCode("EPIC");
        final EhrPatientCrosswalk crosswalk = new EhrPatientCrosswalk();
        crosswalk.setExternalPatientId("ext-patient-1");

        when(apiClient.sourceCode()).thenReturn("EPIC");
        when(sourceRepository.findByCode("EPIC")).thenReturn(Optional.of(source));
        when(crosswalkRepository.findByPatientIdAndSourceId(PATIENT_ID, SOURCE_ID))
                .thenReturn(Optional.of(crosswalk));
        when(rawPayloadRepository.findByPatientIdAndSourceIdAndResourceTypeAndExternalResourceId(
                any(), any(), anyString(), anyString())).thenReturn(Optional.empty());
        when(rawPayloadRepository.save(any(EhrRawPayload.class))).thenAnswer(i -> i.getArgument(0));
        when(appointmentRepository.findByPatientIdAndSourceIdAndExternalAppointmentId(
                any(), any(), anyString())).thenReturn(Optional.empty());
        when(appointmentRepository.save(any(EhrAppointmentRecord.class))).thenAnswer(i -> i.getArgument(0));
    }

    private JsonNode appointment(final String id) throws Exception {
        return json.readTree("{\"resourceType\":\"Appointment\",\"id\":\"" + id + "\",\"status\":\"booked\"}");
    }

    @Test
    void sync_newAppointment_storesRawPayloadThenSavesMappedRecord() throws Exception {
        final JsonNode resource = appointment("appt-1");
        when(apiClient.fetchResources("Appointment", "ext-patient-1")).thenReturn(List.of(resource));

        final List<EhrAppointmentRecord> saved = service.sync(patient, apiClient);

        final ArgumentCaptor<EhrRawPayload> raw = ArgumentCaptor.forClass(EhrRawPayload.class);
        verify(rawPayloadRepository).save(raw.capture());
        assertThat(raw.getValue().getPatientId()).isEqualTo(PATIENT_ID);
        assertThat(raw.getValue().getSourceId()).isEqualTo(SOURCE_ID);
        assertThat(raw.getValue().getResourceType()).isEqualTo("Appointment");
        assertThat(raw.getValue().getExternalResourceId()).isEqualTo("appt-1");
        assertThat(raw.getValue().getPayload()).isEqualTo(resource.toString());
        assertThat(raw.getValue().getPayloadSizeBytes())
                .isEqualTo(resource.toString().getBytes(StandardCharsets.UTF_8).length);
        assertThat(raw.getValue().getPhotoStripped()).isFalse();
        assertThat(raw.getValue().getRetrievedAt()).isNotNull();

        assertThat(saved).hasSize(1);
        final EhrAppointmentRecord record = saved.get(0);
        assertThat(record.getId()).isNull();
        assertThat(record.getExternalAppointmentId()).isEqualTo("appt-1");
        assertThat(record.getPatient()).isSameAs(patient);
        assertThat(record.getSource()).isSameAs(source);
        assertThat(record.getRawPayload()).isSameAs(raw.getValue());
    }

    @Test
    void sync_existingAppointmentAndPayload_updatesInPlace() throws Exception {
        when(apiClient.fetchResources("Appointment", "ext-patient-1")).thenReturn(List.of(appointment("appt-1")));
        final EhrRawPayload existingRaw = new EhrRawPayload();
        existingRaw.setId(40L);
        when(rawPayloadRepository.findByPatientIdAndSourceIdAndResourceTypeAndExternalResourceId(
                PATIENT_ID, SOURCE_ID, "Appointment", "appt-1")).thenReturn(Optional.of(existingRaw));
        final EhrAppointmentRecord existing = new EhrAppointmentRecord();
        existing.setId(99L);
        when(appointmentRepository.findByPatientIdAndSourceIdAndExternalAppointmentId(
                PATIENT_ID, SOURCE_ID, "appt-1")).thenReturn(Optional.of(existing));

        final List<EhrAppointmentRecord> saved = service.sync(patient, apiClient);

        verify(rawPayloadRepository).save(existingRaw);
        assertThat(existingRaw.getExternalResourceId()).isEqualTo("appt-1");
        assertThat(saved.get(0).getId()).isEqualTo(99L);
        assertThat(saved.get(0).getRawPayload()).isSameAs(existingRaw);
    }

    @Test
    void sync_severalAppointments_savesEachInOrder() throws Exception {
        when(apiClient.fetchResources("Appointment", "ext-patient-1"))
                .thenReturn(List.of(appointment("a"), appointment("b")));

        final List<EhrAppointmentRecord> saved = service.sync(patient, apiClient);

        assertThat(saved).extracting(EhrAppointmentRecord::getExternalAppointmentId).containsExactly("a", "b");
    }

    @Test
    void sync_noAppointments_savesNothing() {
        when(apiClient.fetchResources("Appointment", "ext-patient-1")).thenReturn(List.of());

        assertThat(service.sync(patient, apiClient)).isEmpty();
        verify(rawPayloadRepository, never()).save(any());
        verify(appointmentRepository, never()).save(any());
    }

    @Test
    void sync_unknownSourceCode_throwsAndFetchesNothing() {
        when(sourceRepository.findByCode("EPIC")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.sync(patient, apiClient))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Unknown EHR source code: EPIC");
        verify(apiClient, never()).fetchResources(anyString(), anyString());
    }

    @Test
    void sync_noCrosswalk_throwsAndFetchesNothing() {
        when(crosswalkRepository.findByPatientIdAndSourceId(PATIENT_ID, SOURCE_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.sync(patient, apiClient))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("No crosswalk entry for patient 7 at source EPIC");
        verify(apiClient, never()).fetchResources(anyString(), anyString());
    }
}
