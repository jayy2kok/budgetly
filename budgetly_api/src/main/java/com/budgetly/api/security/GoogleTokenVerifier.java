package com.budgetly.api.security;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.Locale;

@Slf4j
@Component
public class GoogleTokenVerifier {

    /**
     * Placeholder values that used to be injected by docker-compose / application.yml.
     * Any of these reaching the API means the operator never supplied a real client ID.
     */
    private static final String[] PLACEHOLDER_CLIENT_IDS = {
            "your-google-client-id",
            "placeholder-client-id",
            "test-google-client-id",
    };

    private final GoogleIdTokenVerifier verifier;

    public GoogleTokenVerifier(@Value("${google.client-id}") String clientId) {
        this.verifier = new GoogleIdTokenVerifier.Builder(new NetHttpTransport(), GsonFactory.getDefaultInstance())
                .setAudience(Collections.singletonList(clientId))
                .build();
    }

    /**
     * Returns {@code true} when the configured Google client ID is missing or still a
     * placeholder value rather than a real {@code *.apps.googleusercontent.com} client ID.
     */
    public static boolean isPlaceholder(String clientId) {
        if (clientId == null || clientId.isBlank()) {
            return true;
        }
        String normalized = clientId.trim().toLowerCase(Locale.ROOT);
        for (String placeholder : PLACEHOLDER_CLIENT_IDS) {
            if (placeholder.equals(normalized)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Returns {@code true} when the configured Google client ID is usable for token
     * verification — i.e. it is neither missing nor a placeholder and looks like a
     * real Google OAuth client ID.
     */
    public static boolean isConfigured(String clientId) {
        if (isPlaceholder(clientId)) {
            return false;
        }
        return clientId.trim().endsWith(".apps.googleusercontent.com");
    }

    /**
     * Verifies a Google ID token and returns the payload if valid.
     * Returns null if invalid.
     */
    public GoogleIdToken.Payload verify(String idTokenString) {
        try {
            GoogleIdToken idToken = verifier.verify(idTokenString);
            if (idToken == null) {
                log.warn("Google token verification failed: null result");
                return null;
            }
            return idToken.getPayload();
        } catch (Exception e) {
            log.error("Google token verification error: {}", e.getMessage());
            return null;
        }
    }
}
