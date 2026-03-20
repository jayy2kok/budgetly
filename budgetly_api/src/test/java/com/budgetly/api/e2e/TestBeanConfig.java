package com.budgetly.api.e2e;

import com.budgetly.api.llm.LlmProvider;
import com.budgetly.api.security.GoogleTokenVerifier;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * Test configuration that provides real test doubles for external services.
 * Uses concrete test implementations (no Mockito, no Byte Buddy) so it
 * works on all Java versions including 25+.
 */
@TestConfiguration
public class TestBeanConfig {

    @Bean
    @Primary
    public GoogleTokenVerifier testGoogleTokenVerifier() {
        return new TestGoogleTokenVerifier();
    }

    @Bean
    @Primary
    public LlmProvider testLlmProvider() {
        return new TestLlmProvider();
    }
}
