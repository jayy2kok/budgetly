package com.budgetly.api.e2e;

import com.budgetly.api.security.GoogleTokenVerifier;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * A test-only GoogleTokenVerifier that always returns a configurable payload.
 * Avoids Mockito entirely — works on any Java version including 25+.
 */
public class TestGoogleTokenVerifier extends GoogleTokenVerifier {

    private GoogleIdToken.Payload nextPayload = null;

    public TestGoogleTokenVerifier() {
        super("test-client-id");
    }

    /**
     * Configure what the next verify() call should return.
     * Call this from your test before making the API request.
     */
    public void setNextPayload(GoogleIdToken.Payload payload) {
        this.nextPayload = payload;
    }

    /** Clear the configured payload (verify will return null). */
    public void clearPayload() {
        this.nextPayload = null;
    }

    @Override
    public GoogleIdToken.Payload verify(String idTokenString) {
        return nextPayload;
    }
}
