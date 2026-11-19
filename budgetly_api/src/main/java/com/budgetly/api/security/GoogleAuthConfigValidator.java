package com.budgetly.api.security;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Fails fast (or loudly warns) when {@code google.client-id} is missing or still a
 * placeholder, so Google sign-in never degrades into an opaque per-request 400.
 *
 * <p>Production-like runs (anything other than {@code test} or {@code local}) abort
 * startup when the client ID is unusable. In local/test profiles a prominent WARN is
 * emitted instead, because those profiles deliberately run without real credentials.
 */
@Slf4j
@Component
public class GoogleAuthConfigValidator implements InitializingBean {

    private final String clientId;
    private final String activeProfile;

    public GoogleAuthConfigValidator(
            @Value("${google.client-id:}") String clientId,
            @Value("${spring.profiles.active:}") String activeProfile) {
        this.clientId = clientId;
        this.activeProfile = activeProfile == null ? "" : activeProfile;
    }

    @Override
    public void afterPropertiesSet() {
        if (GoogleTokenVerifier.isConfigured(clientId)) {
            log.info("Google sign-in configured with client ID ending in '{}'.",
                    clientId.trim().substring(Math.max(0, clientId.trim().length() - 20)));
            return;
        }

        String message = buildMessage();
        if (isRelaxedProfile()) {
            log.warn(message);
            return;
        }
        throw new IllegalStateException(message);
    }

    /**
     * Whether the application is running with a placeholder Google client ID. Exposed so
     * {@code AuthService} can return a clear "auth not configured" response instead of a
     * generic 400 when this validator only warned (local/test profiles).
     */
    public boolean isConfigured() {
        return GoogleTokenVerifier.isConfigured(clientId);
    }

    private boolean isRelaxedProfile() {
        return activeProfile.contains("test") || activeProfile.contains("local");
    }

    private String buildMessage() {
        String reason;
        if (GoogleTokenVerifier.isPlaceholder(clientId)) {
            reason = "google.client-id is missing or still set to the placeholder '%s'".formatted(clientId);
        } else {
            reason = "google.client-id '%s' is not a Google OAuth client ID".formatted(clientId);
        }
        return """
                Google sign-in is not configured: %s.
                Every POST /api/v1/auth/google request will fail until a real value is supplied.
                Set the GOOGLE_CLIENT_ID environment variable to the web client ID from
                https://console.cloud.google.com/apis/credentials (format:
                <digits>-<hash>.apps.googleusercontent.com), then restart the API.""".formatted(reason);
    }
}