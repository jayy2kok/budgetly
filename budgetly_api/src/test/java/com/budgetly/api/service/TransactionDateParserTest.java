package com.budgetly.api.service;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * WORK-003 — backfilled SMS carry their own date; the parser must map the
 * common human-readable formats to a transaction instant, falling back
 * gracefully on garbage.
 */
class TransactionDateParserTest {

    private final TransactionDateParser parser = new TransactionDateParser();

    private static final Instant D20261001 =
            java.time.LocalDate.of(2026, 10, 1).atStartOfDay().toInstant(java.time.ZoneOffset.UTC);

    @Test
    void parsesDdMmYyyy() {
        assertThat(parser.parse("01/10/2026")).contains(D20261001);
    }

    @Test
    void parsesDdMmYyyyWithTime() {
        assertThat(parser.parse("01/10/2026 14:30"))
                .contains(D20261001.plus(java.time.Duration.ofHours(14).plusMinutes(30)));
    }

    @Test
    void parsesDashedDate() {
        assertThat(parser.parse("01-10-2026")).contains(D20261001);
    }

    @Test
    void parsesTwoDigitYearBankDates() {
        Instant nov20 = java.time.LocalDate.of(2026, 11, 20)
                .atStartOfDay().toInstant(java.time.ZoneOffset.UTC);
        assertThat(parser.parse("20-11-26")).contains(nov20);
        assertThat(parser.parse("20/11/26")).contains(nov20);
    }

    @Test
    void parsesTwoDigitYearBankDateWithTime() {
        assertThat(parser.parse("20-11-26 13:45"))
                .contains(Instant.parse("2026-11-20T13:45:00Z"));
    }

    @Test
    void parsesIsoDate() {
        assertThat(parser.parse("2026-10-01")).contains(D20261001);
    }

    @Test
    void parsesIsoDateTimeWithoutZoneAsUtc() {
        assertThat(parser.parse("2026-10-01T14:30:00")).contains(Instant.parse("2026-10-01T14:30:00Z"));
    }

    @Test
    void parsesIsoInstantWithZone() {
        assertThat(parser.parse("2026-10-01T10:30:00+02:00")).contains(Instant.parse("2026-10-01T08:30:00Z"));
    }

    @Test
    void trimsSurroundingWhitespace() {
        assertThat(parser.parse("  01/10/2026  ")).contains(D20261001);
    }

    @Test
    void rejectsNullBlankAndGarbage() {
        assertThat(parser.parse(null)).isEmpty();
        assertThat(parser.parse("  ")).isEmpty();
        assertThat(parser.parse("not a date")).isEmpty();
        assertThat(parser.parse("31/13/2026")).isEmpty(); // invalid month
    }

    @Test
    void resolveTransactionDate_bodyDateTimeWinsOverReceivedTime() {
        Instant received = Instant.parse("2026-11-14T18:30:00Z");
        assertThat(parser.resolveTransactionDate(received, "01/10/2026 14:30", ZONE))
                .isEqualTo(java.time.LocalDateTime.of(2026, 10, 1, 14, 30)
                        .atZone(ZONE).toInstant());
    }

    @Test
    void resolveTransactionDate_dateOnlyUsesReceivedTimeOfDay() {
        // Received at 18:30 IST (13:00 UTC) → the body date keeps 18:30 IST.
        Instant received = Instant.parse("2026-11-14T13:00:00Z");
        assertThat(parser.resolveTransactionDate(received, "01/10/2026", ZONE))
                .isEqualTo(java.time.LocalDateTime.of(2026, 10, 1, 18, 30)
                        .atZone(ZONE).toInstant());
        assertThat(parser.resolveTransactionDate(received, "20-11-26", ZONE))
                .isEqualTo(java.time.LocalDateTime.of(2026, 11, 20, 18, 30)
                        .atZone(ZONE).toInstant());
    }

    @Test
    void resolveTransactionDate_dateOnlyWithoutReceivedTimeFallsBackToMidnight() {
        assertThat(parser.resolveTransactionDate(null, "2026-10-01", ZONE))
                .isEqualTo(java.time.LocalDate.of(2026, 10, 1)
                        .atStartOfDay(ZONE).toInstant());
    }

    @Test
    void resolveTransactionDate_missingBodyTimestampUsesReceivedInstant() {
        Instant received = Instant.parse("2026-11-14T13:00:00Z");
        assertThat(parser.resolveTransactionDate(received, null, ZONE)).isEqualTo(received);
        assertThat(parser.resolveTransactionDate(received, "not a date", ZONE)).isEqualTo(received);
    }

    @Test
    void resolveTransactionDate_noBodyAndNoReceivedFallsBackToNow() {
        Instant before = Instant.now();
        Instant resolved = parser.resolveTransactionDate(null, null, ZONE);
        assertThat(resolved).isBetween(before, Instant.now());
    }

    private static final java.time.ZoneId ZONE = java.time.ZoneId.of("Asia/Kolkata");
}