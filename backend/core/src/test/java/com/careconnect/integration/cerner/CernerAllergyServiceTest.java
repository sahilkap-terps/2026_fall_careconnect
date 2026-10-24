package com.careconnect.integration.cerner;

import static org.assertj.core.api.Assertions.assertThat;

import com.careconnect.integration.cerner.CernerAllergyService.CernerSourceException;
import com.careconnect.integration.cerner.CernerAllergyService.UnknownPatientException;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

/** Contract coverage for exception types declared by {@link CernerAllergyService}. */
class CernerAllergyServiceTest {

    @Test
    void unknownPatientExceptionIsUncheckedWithStableMessage() {
        final UnknownPatientException exception = new UnknownPatientException();

        assertThat(exception).isInstanceOf(RuntimeException.class);
        assertThat(exception.getMessage()).isEqualTo("Patient not found");
    }

    @Test
    @Tag("M3-REQ-09")
    void sourceExceptionCarriesCodeAndRetryableFlag() {
        final CernerSourceException exception =
                new CernerSourceException("CERNER_UNAVAILABLE", true);

        assertThat(exception).isInstanceOf(RuntimeException.class);
        assertThat(exception.code()).isEqualTo("CERNER_UNAVAILABLE");
        assertThat(exception.retryable()).isTrue();
    }

    @Test
    @Tag("M3-REQ-09")
    void sourceExceptionCanBeNonRetryable() {
        final CernerSourceException exception =
                new CernerSourceException("CERNER_AUTH_EXPIRED", false);

        assertThat(exception.code()).isEqualTo("CERNER_AUTH_EXPIRED");
        assertThat(exception.retryable()).isFalse();
    }

    @Test
    @Tag("M3-REQ-09")
    void sourceExceptionMessageDoesNotLeakCode() {
        final CernerSourceException exception =
                new CernerSourceException("CERNER_AUTH_EXPIRED", false);

        assertThat(exception.getMessage())
                .isEqualTo("Cerner source error")
                .doesNotContain("CERNER_AUTH_EXPIRED");
    }
}
