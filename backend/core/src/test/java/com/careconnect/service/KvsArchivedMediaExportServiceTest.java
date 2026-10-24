package com.careconnect.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import org.junit.jupiter.api.Test;

/**
 * Validates where the requested attendee window lies inside an exported KVS file. Fragments are
 * fetched with ten seconds of padding, so the file usually starts before the window; the trim
 * offsets are what keep that padding (possibly another call's audio on a reused pool stream) out
 * of the transcoded WAV. Pure arithmetic: no KVS client is involved.
 */
class KvsArchivedMediaExportServiceTest {

    private static final Instant WINDOW_START = Instant.parse("2026-10-24T15:00:00Z");
    private static final Instant WINDOW_END = Instant.parse("2026-10-24T15:05:00Z");

    /** Scenario: the first fetched fragment began 8 s before the join (inside the padding). */
    @Test
    void trimWindowMs_fileStartsInPadding_skipsThePadding() {
        // Arrange: 8 s of someone else's (or nobody's) audio precedes the window.
        final Instant mediaStart = WINDOW_START.minusSeconds(8);

        // Act
        final long[] trim = KvsArchivedMediaExportService.trimWindowMs(mediaStart, WINDOW_START, WINDOW_END);

        // Assert: start 8 s in; end 8 s + 5 min in, so the trailing padding is cut too.
        assertThat(trim).containsExactly(8_000L, 308_000L);
    }

    /** Scenario: the stream's first audio is 3 s after the join, so nothing precedes the window. */
    @Test
    void trimWindowMs_fileStartsInsideWindow_startsAtZero() {
        final long[] trim = KvsArchivedMediaExportService.trimWindowMs(
                WINDOW_START.plusSeconds(3), WINDOW_START, WINDOW_END);

        assertThat(trim).containsExactly(0L, 297_000L);
    }

    /** Scenario: only trailing padding was found (first fragment after the leave): nothing to decode. */
    @Test
    void trimWindowMs_fileStartsAfterWindow_isEmpty() {
        assertThat(KvsArchivedMediaExportService.trimWindowMs(
                WINDOW_END.plusSeconds(2), WINDOW_START, WINDOW_END)).isEmpty();
    }
}
