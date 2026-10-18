package com.careconnect.service.ai;

import com.careconnect.model.Medication;
import com.careconnect.model.Patient;
import com.careconnect.model.Task;
import com.careconnect.model.retrieval.RetrievalIndexChunk;
import com.careconnect.repository.MedicationRepository;
import com.careconnect.repository.TaskRepository;
import com.careconnect.repository.VitalsRepository;
import com.careconnect.repository.retrieval.RetrievalIndexChunkRepository;
import com.careconnect.testsupport.fixtures.MedicationFixtures;
import com.careconnect.testsupport.fixtures.PatientFixtures;
import com.careconnect.testsupport.fixtures.TaskFixtures;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RetrievalIndexingServiceTest {

    private static final Long PATIENT_ID = 5L;

    @Mock
    private RetrievalIndexChunkRepository chunkRepository;
    @Mock
    private MedicationRepository medicationRepository;
    @Mock
    private TaskRepository taskRepository;
    @Mock
    private VitalsRepository vitalsRepository;

    private RetrievalIndexingService service;
    private Patient patient;

    @BeforeEach
    void setUp() {
        service = new RetrievalIndexingService(
                chunkRepository, medicationRepository, taskRepository, vitalsRepository);
        patient = PatientFixtures.patientWithId(PATIENT_ID);
    }

    @Test
    void reindexMedication_replacesChunkForActiveMedication() {
        // Arrange
        when(medicationRepository.findById(10L))
                .thenReturn(Optional.of(MedicationFixtures.activeMedication(10L, patient)));

        // Act
        service.reindexMedication(10L, PATIENT_ID);

        // Assert
        verify(chunkRepository).deleteByPatientIdAndSourceRecordIdAndRecordType(
                PATIENT_ID, "medication-10", "MEDICATION");
        final ArgumentCaptor<RetrievalIndexChunk> saved = ArgumentCaptor.forClass(RetrievalIndexChunk.class);
        verify(chunkRepository).save(saved.capture());
        assertThat(saved.getValue().getPatientId()).isEqualTo(PATIENT_ID);
        assertThat(saved.getValue().getRecordType()).isEqualTo("MEDICATION");
        assertThat(saved.getValue().getSourceRecordId()).isEqualTo("medication-10");
        assertThat(saved.getValue().getChunkText()).isEqualTo(
                "Lisinopril 10mg is an active medication. Lisinopril is taken once daily."
                        + " Lisinopril is taken by the oral route.");
    }

    @Test
    void reindexMedication_removesChunkWhenMedicationDeactivated() {
        // Arrange
        when(medicationRepository.findById(10L))
                .thenReturn(Optional.of(MedicationFixtures.inactiveMedication(10L, patient)));

        // Act
        service.reindexMedication(10L, PATIENT_ID);

        // Assert
        verify(chunkRepository).deleteByPatientIdAndSourceRecordIdAndRecordType(
                PATIENT_ID, "medication-10", "MEDICATION");
        verify(chunkRepository, never()).save(any());
    }

    @Test
    void reindexMedication_removesChunkWhenMedicationDeleted() {
        // Arrange
        when(medicationRepository.findById(10L)).thenReturn(Optional.empty());

        // Act
        service.reindexMedication(10L, PATIENT_ID);

        // Assert
        verify(chunkRepository).deleteByPatientIdAndSourceRecordIdAndRecordType(
                PATIENT_ID, "medication-10", "MEDICATION");
        verify(chunkRepository, never()).save(any());
    }

    @Test
    void reindexTask_replacesChunkForExistingTask() {
        // Arrange
        final Task task = TaskFixtures.taskWithId(20L);
        task.setPatient(patient);
        when(taskRepository.findById(20L)).thenReturn(Optional.of(task));

        // Act
        service.reindexTask(20L, PATIENT_ID);

        // Assert
        verify(chunkRepository).deleteByPatientIdAndSourceRecordIdAndRecordType(
                PATIENT_ID, "task-20", "TASK");
        final ArgumentCaptor<RetrievalIndexChunk> saved = ArgumentCaptor.forClass(RetrievalIndexChunk.class);
        verify(chunkRepository).save(saved.capture());
        assertThat(saved.getValue().getSourceRecordId()).isEqualTo("task-20");
        assertThat(saved.getValue().getChunkText()).isEqualTo(
                "Check Vitals is a Health task scheduled for 2025-01-01 at 08:00."
                        + " Check Vitals repeats daily. Check Vitals details: Daily vitals check."
                        + " Check Vitals is not completed.");
    }

    @Test
    void reindexTask_removesChunkWhenTaskDeleted() {
        // Arrange
        when(taskRepository.findById(20L)).thenReturn(Optional.empty());

        // Act
        service.reindexTask(20L, PATIENT_ID);

        // Assert
        verify(chunkRepository).deleteByPatientIdAndSourceRecordIdAndRecordType(
                PATIENT_ID, "task-20", "TASK");
        verify(chunkRepository, never()).save(any());
    }

    @Test
    void reindexMedication_writesEveryFactAsItsOwnSentence() {
        // Arrange: notes already ending in a period must not get a second one
        final Medication medication = MedicationFixtures.activeMedication(10L, patient);
        medication.setPrescribedBy("Dr. Rivera");
        medication.setStartDate("2026-10-01");
        medication.setEndDate("2026-12-31");
        medication.setNotes("Take with food.");
        when(medicationRepository.findById(10L)).thenReturn(Optional.of(medication));

        // Act
        service.reindexMedication(10L, PATIENT_ID);

        // Assert
        final ArgumentCaptor<RetrievalIndexChunk> saved = ArgumentCaptor.forClass(RetrievalIndexChunk.class);
        verify(chunkRepository).save(saved.capture());
        assertThat(saved.getValue().getChunkText()).isEqualTo(
                "Lisinopril 10mg is an active medication. Lisinopril is taken once daily."
                        + " Lisinopril is taken by the oral route. Lisinopril was prescribed by Dr. Rivera."
                        + " Lisinopril was started on 2026-10-01. Lisinopril ends on 2026-12-31."
                        + " Lisinopril notes: Take with food.");
    }

    @Test
    void reindexTask_describesUntypedUnscheduledCompletedTask() {
        // Arrange
        final Task task = Task.builder().id(21L).name("Call pharmacy").isCompleted(true).patient(patient).build();
        when(taskRepository.findById(21L)).thenReturn(Optional.of(task));

        // Act
        service.reindexTask(21L, PATIENT_ID);

        // Assert
        final ArgumentCaptor<RetrievalIndexChunk> saved = ArgumentCaptor.forClass(RetrievalIndexChunk.class);
        verify(chunkRepository).save(saved.capture());
        assertThat(saved.getValue().getChunkText())
                .isEqualTo("Call pharmacy is a task. Call pharmacy is completed.");
    }
}
