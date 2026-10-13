package com.careconnect.dto;

import java.time.Instant;

/**
 * Request body for granting Caregiver-retrieval consent from the authenticated patient to a
 * caregiver (or other grantee).
 *
 * @param granteeUserId user id of the caregiver receiving consent (required)
 * @param granteeRole   optional role label; defaults to {@code CAREGIVER}
 * @param expiresAt     optional expiry; null means no expiry
 */
public record MedicareViewConsentRequest(
        Long granteeUserId,
        String granteeRole,
        Instant expiresAt
) {
}
