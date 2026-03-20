package com.budgetly.api.e2e;

import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.document.UserDocument;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.hamcrest.Matchers.*;

/**
 * E2E tests for Pattern Registry API: /api/v1/patterns/*
 */
class PatternRegistryE2ETest extends BaseE2ETest {

    // ── Get All Patterns ────────────────────────────────────────

    @Test
    void getPatterns_returnsActivePatterns() {
        UserDocument user = seedUser("g-pat-1", "Pat User", "pat1@test.com");
        seedPattern("HDFCBK", "(?<amount>\\d+).*debited.*(?<merchant>\\w+)", "Rs.500 debited for Amazon");
        seedPattern("SBIUPI", "(?<amount>\\d+).*sent.*(?<merchant>\\w+)", "Rs.200 sent to PhonePe");

        givenAuth(user.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(2))
                .body("sender", hasItems("HDFCBK", "SBIUPI"));
    }

    // ── Get Patterns — Delta Sync ───────────────────────────────

    @Test
    void getPatterns_withSince_returnsOnlyRecent() {
        UserDocument user = seedUser("g-pat-2", "Delta User", "delta@test.com");

        // Create an old pattern directly with a past date
        SmsPatternDocument oldPattern = SmsPatternDocument.builder()
                .sender("OLDBK")
                .regex("old-regex")
                .extractionMap(Map.of("amount", "amount"))
                .sampleMessage("Old message")
                .usageCount(1)
                .active(true)
                .createdAt(java.time.Instant.parse("2025-01-01T00:00:00Z"))
                .build();
        patternRegistryRepository.save(oldPattern);

        // Create a recent pattern
        seedPattern("NEWBK", "new-regex", "New message");

        givenAuth(user.getId())
                .queryParam("since", "2026-01-01T00:00:00Z")
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(1))
                .body("[0].sender", equalTo("NEWBK"));
    }

    // ── Get Pattern Senders ─────────────────────────────────────

    @Test
    void getPatternSenders_returnsSenderCounts() {
        UserDocument user = seedUser("g-pat-3", "Sender User", "sender@test.com");
        seedPattern("HDFCBK", "regex1", "sample1");
        seedPattern("HDFCBK", "regex2", "sample2");
        seedPattern("SBIUPI", "regex3", "sample3");

        givenAuth(user.getId())
                .get("/patterns/senders")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(2))
                .body("find { it.sender == 'HDFCBK' }.patternCount", equalTo(2))
                .body("find { it.sender == 'SBIUPI' }.patternCount", equalTo(1));
    }

    // ── Report Pattern — Below Threshold ────────────────────────

    @Test
    void reportPattern_belowThreshold_notRemoved() {
        UserDocument user = seedUser("g-pat-4", "Report User", "report@test.com");
        SmsPatternDocument pattern = seedPattern("BADPAT", "bad-regex", "bad sample");

        givenAuth(user.getId())
                .body(Map.of("reason", "Wrong extraction", "sampleMessage", "Actual SMS text"))
                .post("/patterns/" + pattern.getId() + "/report")
                .then()
                .statusCode(200)
                .body("patternId", equalTo(pattern.getId()))
                .body("reportCount", equalTo(1))
                .body("removed", equalTo(false));
    }

    // ── Report Pattern — Reaches Threshold ──────────────────────

    @Test
    void reportPattern_reachesThreshold_autoRemoved() {
        // report-threshold is set to 3 in application-test.yml
        SmsPatternDocument pattern = seedPattern("THRESHOLD", "threshold-regex", "threshold sample");

        // Report from 3 different users (threshold = 3)
        for (int i = 0; i < 3; i++) {
            UserDocument reporter = seedUser("g-pat-5-" + i, "Reporter " + i, "reporter" + i + "@test.com");
            givenAuth(reporter.getId())
                    .body(Map.of("reason", "Bad pattern", "sampleMessage", "Wrong"))
                    .post("/patterns/" + pattern.getId() + "/report");
        }

        // The last report should have triggered removal
        UserDocument checker = seedUser("g-pat-5-check", "Checker", "checker@test.com");
        givenAuth(checker.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + pattern.getId() + "' }", nullValue());
    }

    // ── Get Pattern Stats ───────────────────────────────────────

    @Test
    void getPatternStats_returnsCorrectCounts() {
        UserDocument user = seedUser("g-pat-6", "Stats User", "stats@test.com");
        seedPattern("HDFCBK", "regex1", "sample1");
        seedPattern("SBIUPI", "regex2", "sample2");

        givenAuth(user.getId())
                .get("/patterns/stats")
                .then()
                .statusCode(200)
                .body("totalPatterns", equalTo(2))
                .body("totalSenders", equalTo(2));
    }
}
