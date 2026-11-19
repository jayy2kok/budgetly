package com.budgetly.api.security;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

/**
 * Tests for the fail-fast startup guard (issue #24): a missing/placeholder
 * GOOGLE_CLIENT_ID must never silently reach production code.
 */
class GoogleAuthConfigValidatorTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withUserConfiguration(TestConfig.class);

    @Nested
    @DisplayName("isConfigured")
    class IsConfigured {

        @Test
        void realGoogleClientId_isConfigured() {
            assertThat(GoogleTokenVerifier.isConfigured(
                    "855687685081-5pfm3c76mlekvd15hvuoscbc6itao147.apps.googleusercontent.com")).isTrue();
        }

        @Test
        void composePlaceholder_isNotConfigured() {
            assertThat(GoogleTokenVerifier.isConfigured("placeholder-client-id")).isFalse();
        }

        @Test
        void applicationYmlPlaceholder_isNotConfigured() {
            assertThat(GoogleTokenVerifier.isConfigured("your-google-client-id")).isFalse();
        }

        @Test
        void nullOrBlank_isNotConfigured() {
            assertThat(GoogleTokenVerifier.isConfigured(null)).isFalse();
            assertThat(GoogleTokenVerifier.isConfigured("")).isFalse();
            assertThat(GoogleTokenVerifier.isConfigured("   ")).isFalse();
        }

        @Test
        void nonGoogleDomain_isNotConfigured() {
            assertThat(GoogleTokenVerifier.isConfigured("some-other-client-id")).isFalse();
            assertThat(GoogleTokenVerifier.isConfigured("client.apps.googleusercontent.com.evil.tld")).isFalse();
        }
    }

    @Nested
    @DisplayName("startup validation")
    class StartupValidation {

        @Test
        @DisplayName("placeholder in a production-like profile fails startup")
        void placeholderFailsStartup() {
            contextRunner
                    .withPropertyValues("google.client-id=placeholder-client-id")
                    .run(context -> assertThat(context).hasFailed());
        }

        @Test
        @DisplayName("missing client ID fails startup")
        void missingFailsStartup() {
            contextRunner.run(context -> assertThat(context).hasFailed());
        }

        @Test
        @DisplayName("a real client ID starts normally")
        void realClientIdStarts() {
            contextRunner
                    .withPropertyValues(
                            "google.client-id=855687685081-5pfm3c76mlekvd15hvuoscbc6itao147.apps.googleusercontent.com")
                    .run(context -> assertThat(context).hasNotFailed());
        }

        @Test
        @DisplayName("local profile only warns, so tests and local dev still boot")
        void localProfileOnlyWarns() {
            contextRunner
                    .withPropertyValues(
                            "spring.profiles.active=local",
                            "google.client-id=your-google-client-id")
                    .run(context -> assertThat(context).hasNotFailed());
        }

        @Test
        @DisplayName("startup failure message names the variable to fix")
        void failureMessageNamesFix() {
            contextRunner
                    .withPropertyValues("google.client-id=placeholder-client-id")
                    .run(context -> assertThat(context)
                            .getFailure()
                            .hasRootCauseMessage("Google sign-in is not configured: google.client-id is missing or still set to the placeholder 'placeholder-client-id'.\n"
                                    + "Every POST /api/v1/auth/google request will fail until a real value is supplied.\n"
                                    + "Set the GOOGLE_CLIENT_ID environment variable to the web client ID from\n"
                                    + "https://console.cloud.google.com/apis/credentials (format:\n"
                                    + "<digits>-<hash>.apps.googleusercontent.com), then restart the API."));
        }
    }

    @Test
    @DisplayName("guard can be constructed without a Spring context")
    void constructorOnly() {
        assertThatCode(() -> new GoogleAuthConfigValidator("placeholder-client-id", ""))
                .doesNotThrowAnyException();
    }
}