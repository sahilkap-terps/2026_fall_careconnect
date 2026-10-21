package com.careconnect.controller;

import com.careconnect.dto.MedicareShareRequest;
import com.careconnect.dto.MedicareShareResponse;
import com.careconnect.exception.AppException;
import com.careconnect.model.User;
import com.careconnect.security.Role;
import com.careconnect.service.consent.MedicareShareService;
import com.careconnect.util.SecurityUtil;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import java.util.List;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * CR-2 (#305) patient-facing record sharing: share Medicare records with a registered user by
 * email (read-only, 90 days) and list current shares. Revoking uses the existing
 * {@code DELETE /api/v3/consent/medicare-view} with the recipient's user id.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping({"/api/v3/consent/medicare-share", "/v1/api/v3/consent/medicare-share"})
@Tag(name = "Consent", description = "Patient consent grants and record sharing")
@SecurityRequirement(name = "bearerAuth")
public class MedicareShareController {

    private final MedicareShareService medicareShareService;
    private final SecurityUtil securityUtil;

    @PostMapping(
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Share the patient's Medicare records with a registered user by email")
    public ResponseEntity<MedicareShareResponse> share(
            @RequestBody final MedicareShareRequest request) {
        final User patient = requirePatientCaller();
        if (request == null) {
            throw new AppException(HttpStatus.BAD_REQUEST, "recipientEmail is required");
        }
        final MedicareShareService.ShareResult result =
                medicareShareService.shareMedicareRecords(patient, request.recipientEmail());
        return ResponseEntity.status(HttpStatus.CREATED).body(MedicareShareResponse.from(
                result.grant(), result.recipient(), result.emailSent()));
    }

    @GetMapping(produces = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "List the patient's active Medicare shares")
    public ResponseEntity<List<MedicareShareResponse>> list() {
        final User patient = requirePatientCaller();
        return ResponseEntity.ok(medicareShareService.listActiveShares(patient.getId()).stream()
                .map(r -> MedicareShareResponse.from(r.grant(), r.recipient(), null))
                .toList());
    }

    private User requirePatientCaller() {
        final User caller = securityUtil.resolveCurrentUser();
        if (caller == null || caller.getId() == null) {
            throw new AppException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }
        if (caller.getRole() != Role.PATIENT) {
            throw new AppException(
                    HttpStatus.FORBIDDEN, "Only the patient may share their Medicare records");
        }
        return caller;
    }
}
