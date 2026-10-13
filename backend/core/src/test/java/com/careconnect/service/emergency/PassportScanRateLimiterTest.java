package com.careconnect.service.emergency;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The per-client limit on public passport scans, driven by a clock the test advances.
 * <p>
 * No Test Plan IDs yet: they are issued by the Testing Lead, not chosen by the author.
 */
class PassportScanRateLimiterTest {

    @Test
    @DisplayName("a client gets the limit, then 429s, until the window passes")
    void limitResetsAfterTheWindow() {
        MutableClock clock = new MutableClock();
        PassportScanRateLimiter limiter = new PassportScanRateLimiter(3, clock);

        assertThat(limiter.tryAcquire("203.0.113.5")).isTrue();
        assertThat(limiter.tryAcquire("203.0.113.5")).isTrue();
        assertThat(limiter.tryAcquire("203.0.113.5")).isTrue();
        assertThat(limiter.tryAcquire("203.0.113.5")).isFalse();

        clock.advance(Duration.ofSeconds(61));
        assertThat(limiter.tryAcquire("203.0.113.5")).isTrue();
    }

    @Test
    @DisplayName("clients are limited separately")
    void clientsAreIndependent() {
        PassportScanRateLimiter limiter = new PassportScanRateLimiter(1, new MutableClock());

        assertThat(limiter.tryAcquire("203.0.113.5")).isTrue();
        assertThat(limiter.tryAcquire("203.0.113.5")).isFalse();
        assertThat(limiter.tryAcquire("198.51.100.7")).isTrue();
    }

    /** A clock the test moves forward by hand. */
    private static final class MutableClock extends Clock {
        private Instant now = Instant.parse("2026-10-13T12:00:00Z");

        void advance(Duration by) {
            now = now.plus(by);
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }
}
