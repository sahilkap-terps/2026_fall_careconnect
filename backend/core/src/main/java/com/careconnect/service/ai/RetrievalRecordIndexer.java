package com.careconnect.service.ai;

import com.careconnect.service.ai.RetrievalRecordChangeListener.RetrievalRecordChanged;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Rebuilds a medication or task's Ask AI chunk once the write that changed it
 * has committed.
 *
 * <p>Failures are logged and swallowed: the user's save already succeeded, and
 * a missed chunk can be recovered with {@code POST /v1/api/ai/index/{patientId}}.
 * This method deliberately has no {@code @Transactional}; the indexing methods
 * open their own transaction, so a failure rolls back only the index write
 * instead of surfacing as an {@code UnexpectedRollbackException} on the request.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RetrievalRecordIndexer {

    private final RetrievalIndexingService retrievalIndexingService;

    // fallbackExecution covers a write made outside any transaction, where
    // there is no commit to wait for.
    @TransactionalEventListener(fallbackExecution = true)
    public void onRecordChanged(final RetrievalRecordChanged event) {
        try {
            switch (event.recordType()) {
                case MEDICATION -> retrievalIndexingService.reindexMedication(event.recordId(), event.patientId());
                case TASK -> retrievalIndexingService.reindexTask(event.recordId(), event.patientId());
                default -> log.warn("No per-record indexer for recordType={}", event.recordType());
            }
        } catch (RuntimeException e) {
            log.warn("Ask AI re-index failed for {} id={} patientId={}: {}",
                    event.recordType(), event.recordId(), event.patientId(), e.getMessage());
        }
    }
}
