package com.careconnect.integration.cerner;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class CernerAllergyServiceTest {

    @Test
    void unknownPatientException_hasGenericMessage() {
        assertThat(new CernerAllergyService.UnknownPatientException())
                .isInstanceOf(RuntimeException.class)
                .hasMessage("Patient not found");
    }

    @Test
    void cernerSourceException_keepsCodeAndRetryable() {
        final CernerAllergyService.CernerSourceException retryable =
                new CernerAllergyService.CernerSourceException("CERNER_UNAVAILABLE", true);
        final CernerAllergyService.CernerSourceException notRetryable =
                new CernerAllergyService.CernerSourceException("CERNER_AUTH_EXPIRED", false);

        assertThat(retryable).hasMessage("Cerner source error");
        assertThat(retryable.code()).isEqualTo("CERNER_UNAVAILABLE");
        assertThat(retryable.retryable()).isTrue();
        assertThat(notRetryable.code()).isEqualTo("CERNER_AUTH_EXPIRED");
        assertThat(notRetryable.retryable()).isFalse();
    }
}
