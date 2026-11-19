package com.budgetly.api.security;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;

/**
 * Minimal context used by {@link GoogleAuthConfigValidatorTest} to exercise the
 * startup guard without booting the full application (no MongoDB, no web server).
 */
@TestConfiguration(proxyBeanMethods = false)
class TestConfig {

    @Bean
    String googleClientId(org.springframework.core.env.Environment env) {
        return env.getProperty("google.client-id", "");
    }

    @Bean
    String activeProfile(org.springframework.core.env.Environment env) {
        String[] active = env.getActiveProfiles();
        return active.length == 0 ? "" : String.join(",", active);
    }

    @Bean
    GoogleTokenVerifier googleTokenVerifier(String googleClientId) {
        return new GoogleTokenVerifier(googleClientId);
    }

    @Bean
    GoogleAuthConfigValidator googleAuthConfigValidator(String googleClientId, String activeProfile) {
        return new GoogleAuthConfigValidator(googleClientId, activeProfile);
    }
}