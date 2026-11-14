package com.budgetly.api.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import jakarta.annotation.PostConstruct;
import java.time.Instant;
import java.util.Collections;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Fetches and caches exchange rates with base INR from open.er-api.com.
 *
 * <p>API response format:
 * <pre>{@code
 * {
 *   "result": "success",
 *   "base_code": "INR",
 *   "rates": { "INR": 1.0, "USD": 0.0106, ... }
 * }
 * }</pre>
 *
 * <p>Since {@code 1 INR = rate * CURRENCY}, converting an amount in {@code CURRENCY}
 * to INR is {@code amount / rate}.
 */
@Slf4j
@Service
public class CurrencyConversionService {

    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${budgetly.exchange-rate.api-url:https://open.er-api.com/v6/latest/INR}")
    private String apiUrl;

    /** Cached rates: currency code -> units per 1 INR. */
    private final Map<String, Double> rates = new ConcurrentHashMap<>();
    private volatile Instant lastUpdated;

    @PostConstruct
    public void init() {
        refreshRates();
    }

    /**
     * Refreshes rates every 12 hours (the free endpoint updates daily).
     */
    @Scheduled(fixedRate = 12 * 3600 * 1000, initialDelay = 12 * 3600 * 1000)
    public void refreshRates() {
        try {
            log.info("Fetching latest exchange rates from {}", apiUrl);
            @SuppressWarnings("unchecked")
            Map<String, Object> resp = restTemplate.getForObject(apiUrl, Map.class);
            if (resp != null && "success".equals(resp.get("result"))) {
                @SuppressWarnings("unchecked")
                Map<String, Object> rawRates = (Map<String, Object>) resp.get("rates");
                if (rawRates != null) {
                    rates.clear();
                    rawRates.forEach((k, v) -> {
                        if (v instanceof Number n) {
                            rates.put(k.toUpperCase(Locale.ROOT), n.doubleValue());
                        }
                    });
                    lastUpdated = Instant.now();
                    log.info("Loaded {} exchange rates with base INR (USD={}, EUR={})",
                            rates.size(), rates.get("USD"), rates.get("EUR"));
                    return;
                }
            }
            log.warn("Exchange rate API response missing success or rates map: {}", resp);
        } catch (Exception e) {
            log.warn("Failed to fetch exchange rates from {}: {} (retaining {} existing rates)",
                    apiUrl, e.getMessage(), rates.size());
        }
    }

    /**
     * Converts the given {@code amount} in {@code currency} to INR.
     *
     * @param amount   amount in source currency
     * @param currency ISO-4217 currency code (e.g. "USD", "INR"); null/blank defaults to INR
     * @return converted amount in INR, or original {@code amount} if conversion rate is missing
     */
    public double convertToInr(double amount, String currency) {
        if (amount == 0.0) return 0.0;
        if (currency == null || currency.isBlank()) return amount;

        String code = currency.trim().toUpperCase(Locale.ROOT);
        if ("INR".equals(code)) return amount;

        Double rate = rates.get(code);
        if (rate == null || rate <= 0) {
            log.debug("No exchange rate found for currency {}; treating as 1:1 INR", code);
            return amount;
        }

        // rate = (units of `code` per 1 INR) -> amount in INR = amount / rate
        return amount / rate;
    }

    public Map<String, Double> getCachedRates() {
        return Collections.unmodifiableMap(rates);
    }

    public Instant getLastUpdated() {
        return lastUpdated;
    }
}
