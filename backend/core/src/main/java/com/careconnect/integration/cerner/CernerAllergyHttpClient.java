package com.careconnect.integration.cerner;

import com.careconnect.integration.cerner.CernerAllergyService.CernerSourceException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.SocketTimeoutException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;

/**
 * Explicitly constructed, single-page client. No Spring bean or app wiring enables it.
 * The caller must supply a trusted vendor patient ID and a server-held token after access checks.
 * Error codes and limits are provisional pending the team's contract review.
 */
public final class CernerAllergyHttpClient {
    private static final int MAX_BYTES = 1_048_576;
    private final URI base;
    private final int timeoutMillis;
    private final ObjectMapper mapper = new ObjectMapper()
            .enable(com.fasterxml.jackson.databind.DeserializationFeature.FAIL_ON_TRAILING_TOKENS);

    public CernerAllergyHttpClient(URI base, Duration timeout) {
        String host = base.getHost();
        boolean local = "localhost".equals(host) || "127.0.0.1".equals(host) || "[::1]".equals(host);
        if (host == null || base.getUserInfo() != null || base.getQuery() != null
                || base.getFragment() != null || !base.getPath().endsWith("/")
                || !("https".equals(base.getScheme()) || (local && "http".equals(base.getScheme())))) {
            throw new IllegalArgumentException("HTTPS base URI with trailing slash required; HTTP is loopback-only");
        }
        long millis = timeout.toMillis();
        if (millis < 1 || millis > 30_000) {
            throw new IllegalArgumentException("Timeout must be between 1 and 30000 milliseconds");
        }
        this.base = base;
        this.timeoutMillis = (int) millis;
    }

    /** Does not refresh tokens, retry, follow redirects, or return incomplete paginated results. */
    public List<CernerAllergyMapper.Allergy> getAllergies(String trustedPatientId, String token) {
        if (trustedPatientId == null || !trustedPatientId.matches("[A-Za-z0-9.-]{1,64}")) {
            throw new IllegalArgumentException("Trusted FHIR patient ID required");
        }
        if (token == null || token.isBlank() || token.contains("\r") || token.contains("\n")) {
            throw failure("CERNER_AUTH_EXPIRED", false);
        }
        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) base.resolve("AllergyIntolerance?patient=" + trustedPatientId)
                    .toURL().openConnection();
            connection.setInstanceFollowRedirects(false);
            connection.setConnectTimeout(timeoutMillis);
            connection.setReadTimeout(timeoutMillis);
            connection.setUseCaches(false);
            connection.setRequestProperty("Accept", "application/fhir+json");
            connection.setRequestProperty("Authorization", "Bearer " + token);
            int status = connection.getResponseCode();
            if (status == 401) { throw failure("CERNER_AUTH_EXPIRED", false); }
            if (status == 403) { throw failure("CERNER_ACCESS_DENIED", false); }
            if (status == 429 || status >= 500) { throw failure("CERNER_UNAVAILABLE", true); }
            if (status != 200) { throw failure("CERNER_UNEXPECTED_RESPONSE", false); }
            byte[] body;
            try (var input = connection.getInputStream()) {
                body = input.readNBytes(MAX_BYTES + 1);
            }
            if (body.length > MAX_BYTES) { throw failure("CERNER_INVALID_RESPONSE", false); }
            JsonNode bundle = mapper.readTree(new String(body, StandardCharsets.UTF_8));
            if (bundle == null || !"Bundle".equals(bundle.path("resourceType").asText())
                    || !"searchset".equals(bundle.path("type").asText())
                    || (bundle.has("entry") && !bundle.path("entry").isArray())
                    || (bundle.has("link") && !bundle.path("link").isArray())) {
                throw failure("CERNER_INVALID_RESPONSE", false);
            }
            for (JsonNode link : bundle.path("link")) {
                if ("next".equals(link.path("relation").asText())) {
                    throw failure("CERNER_PAGINATION_UNSUPPORTED", false);
                }
            }
            return CernerAllergyMapper.map(bundle, trustedPatientId);
        } catch (SocketTimeoutException e) {
            throw failure("CERNER_TIMEOUT", true);
        } catch (IOException | IllegalArgumentException e) {
            // Never include upstream bodies, tokens, URLs, or patient values in diagnostics.
            throw failure(e instanceof IOException && !(e instanceof com.fasterxml.jackson.core.JsonProcessingException)
                    ? "CERNER_UNAVAILABLE" : "CERNER_INVALID_RESPONSE", e instanceof IOException
                    && !(e instanceof com.fasterxml.jackson.core.JsonProcessingException));
        } finally {
            if (connection != null) { connection.disconnect(); }
        }
    }

    private static CernerSourceException failure(String code, boolean retryable) {
        return new CernerSourceException(code, retryable);
    }
}
