package com.careconnect.repository.ehr;

import com.careconnect.model.ehr.EhrRawPayload;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface EhrRawPayloadRepository extends JpaRepository<EhrRawPayload, Long> {

    /** Most recent stored body for one resource type, used to re-derive a mapping. */
    Optional<EhrRawPayload> findFirstByPatientIdAndSourceIdAndResourceTypeOrderByRetrievedAtDesc(
            Long patientId, Long sourceId, String resourceType);

    /**
     * All stored bodies for one resource type, newest first (by id when two share a retrieval
     * time). The first row per external resource id is that resource's current copy.
     */
    List<EhrRawPayload> findByPatientIdAndSourceIdAndResourceTypeOrderByRetrievedAtDescIdDesc(
            Long patientId, Long sourceId, String resourceType);

    /** Retrieval history for one patient and source, newest first. */
    List<EhrRawPayload> findByPatientIdAndSourceIdOrderByRetrievedAtDesc(
            Long patientId, Long sourceId);

    /** Delete the raw-payload history for one patient and source (disconnect cleanup). */
    int deleteByPatientIdAndSourceId(Long patientId, Long sourceId);
}
