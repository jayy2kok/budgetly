package com.budgetly.api.service;

import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

class CurrencyConversionServiceTest {

    @Test
    void inrReturnsOriginalAmount() {
        CurrencyConversionService service = new CurrencyConversionService();
        assertThat(service.convertToInr(500.0, "INR")).isEqualTo(500.0);
        assertThat(service.convertToInr(500.0, null)).isEqualTo(500.0);
        assertThat(service.convertToInr(500.0, "")).isEqualTo(500.0);
        assertThat(service.convertToInr(0.0, "USD")).isEqualTo(0.0);
    }

    @Test
    void foreignCurrencyConvertsCorrectly() {
        CurrencyConversionService service = new CurrencyConversionService();
        Map<String, Double> rates = new ConcurrentHashMap<>();
        // 1 INR = 0.0106 USD (~ 94.3396 INR per USD)
        rates.put("USD", 0.0106);
        // 1 INR = 0.0100 EUR (~ 100.0 INR per EUR)
        rates.put("EUR", 0.0100);
        ReflectionTestUtils.setField(service, "rates", rates);

        // 21.20 USD at 0.0106 rate = 21.20 / 0.0106 = 2000.0 INR
        double convertedUsd = service.convertToInr(21.20, "USD");
        assertThat(convertedUsd).isCloseTo(2000.0, within(0.01));

        // 50.0 EUR at 0.0100 rate = 50.0 / 0.0100 = 5000.0 INR
        double convertedEur = service.convertToInr(50.0, "EUR");
        assertThat(convertedEur).isCloseTo(5000.0, within(0.01));
    }

    @Test
    void unknownCurrencyFallsBackToOriginalAmount() {
        CurrencyConversionService service = new CurrencyConversionService();
        ReflectionTestUtils.setField(service, "rates", new ConcurrentHashMap<>());
        assertThat(service.convertToInr(100.0, "XYZ")).isEqualTo(100.0);
    }
}
