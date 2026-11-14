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
    void parseOrDefaultFallsBackToSuppliedInstant() {
        Instant fallback = Instant.parse("2026-11-14T00:00:00Z");
        assertThat(parser.parseOrDefault(null, fallback)).isEqualTo(fallback);
        assertThat(parser.parseOrDefault("2026-10-01", fallback)).isEqualTo(D20261001);
    }
}