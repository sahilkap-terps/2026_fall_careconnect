package com.careconnect.controller.emergency;

import com.careconnect.dto.emergency.PassportDtos.PublicPassport;
import com.careconnect.exception.AppException;
import com.careconnect.model.Patient;
import com.careconnect.model.User;
import com.careconnect.dto.emergency.PassportDtos.VisibilityRequest;
import com.careconnect.repository.PatientRepository;
import com.careconnect.repository.UserRepository;
import com.careconnect.service.emergency.EmergencyPassportService;
import com.careconnect.service.emergency.PassportScanRateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The passport controller's own decisions: who counts as the patient, how a scan answers each case,
 * and which address the rate limit keys on. The service is mocked; its rules have their own test.
 * <p>
 * No Test Plan IDs yet: they are issued by the Testing Lead, not chosen by the author.
 */
class EmergencyPassportControllerTest {

    private static final String EMAIL = "patient@example.test";
    private static final Authentication SIGNED_IN = new UsernamePasswordAuthenticationToken(EMAIL, null, List.of());

    private EmergencyPassportService passports;
    private PassportScanRateLimiter rateLimiter;
    private UserRepository users;
    private PatientRepository patients;
    private EmergencyPassportController controller;

    @BeforeEach
    void setUp() {
        passports = mock(EmergencyPassportService.class);
        rateLimiter = mock(PassportScanRateLimiter.class);
        users = mock(UserRepository.class);
        patients = mock(PatientRepository.class);
        controller = new EmergencyPassportController(passports, rateLimiter, users, patients);
        when(rateLimiter.tryAcquire(anyString())).thenReturn(true);
    }

    @Test
    @DisplayName("a valid scan is 200 and never cached")
    void validScanIsOkAndNoStore() {
        PublicPassport passport = new PublicPassport("Jordan Miller", 41, null, null, null, null, null, null);
        when(passports.scan("good")).thenReturn(Optional.of(passport));

        ResponseEntity<?> response = controller.scan("good", new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(passport);
        assertThat(response.getHeaders().getCacheControl()).isEqualTo("no-store");
    }

    @Test
    @DisplayName("an unknown or revoked code is the same 404")
    void inactiveScanIsUniform404() {
        when(passports.scan(anyString())).thenReturn(Optional.empty());

        ResponseEntity<?> response = controller.scan("anything", new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody()).isEqualTo(Map.of("status", "NOT_ACTIVE"));
    }

    @Test
    @DisplayName("over the limit is 429 and the code is never looked up")
    void rateLimitedScanIs429() {
        when(rateLimiter.tryAcquire(anyString())).thenReturn(false);

        ResponseEntity<?> response = controller.scan("anything", new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        verify(passports, never()).scan(anyString());
    }

    @Test
    @DisplayName("the rate limit keys on the address the load balancer appended, not one the client sent")
    void clientKeyIsTheLastForwardedHop() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.9");
        request.addHeader("X-Forwarded-For", "1.2.3.4, 203.0.113.5");
        assertThat(EmergencyPassportController.clientKey(request)).isEqualTo("203.0.113.5");

        MockHttpServletRequest direct = new MockHttpServletRequest();
        direct.setRemoteAddr("10.0.0.9");
        assertThat(EmergencyPassportController.clientKey(direct)).isEqualTo("10.0.0.9");
    }

    @Test
    @DisplayName("a signed-in user with no patient record cannot manage a passport")
    void nonPatientIsForbidden() {
        User caregiver = User.builder().id(9L).email(EMAIL).build();
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(caregiver));
        when(patients.findByUserId(9L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> controller.get(SIGNED_IN))
                .isInstanceOf(AppException.class)
                .extracting(e -> ((AppException) e).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    @DisplayName("an unknown field name is 404 and a missing isPublic is 400")
    void visibilityRequestValidation() {
        User user = User.builder().id(9L).email(EMAIL).build();
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(user));
        when(patients.findByUserId(9L)).thenReturn(Optional.of(Patient.builder().id(42L).build()));

        assertThatThrownBy(() -> controller.setVisibility("SSN", new VisibilityRequest(true), SIGNED_IN))
                .isInstanceOf(AppException.class)
                .extracting(e -> ((AppException) e).getStatus())
                .isEqualTo(HttpStatus.NOT_FOUND);
        assertThatThrownBy(() -> controller.setVisibility("allergies", new VisibilityRequest(null), SIGNED_IN))
                .isInstanceOf(AppException.class)
                .extracting(e -> ((AppException) e).getStatus())
                .isEqualTo(HttpStatus.BAD_REQUEST);
    }
}
