package com.budgetly.api.service;

import org.springframework.stereotype.Component;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.List;

/**
 * Parses the human-readable timestamps that SMS bodies / LLM results carry
 * (e.g. {@code "01/10/2026"}, {@code "2026-10-01 14:30"}) into a transaction
 * date. Backfilled SMS predate "now", so using {@code Instant.now()} would
 * corrupt feeds and budgets — this is the single parser shared by every
 * transaction-creation call site (WORK-003).
 *
 * <p>Supported: ISO instant / offset date-times, ISO date, {@code dd/MM/yyyy},
 * {@code dd-MM-yyyy} (each optionally with a {@code HH:mm[:ss]} time part).
 * Date-only values resolve to start-of-day UTC.
 */
@Component
public class TransactionDateParser {

    private static final List<DateTimeFormatter> DATE_FORMATS = List.of(
            DateTimeFormatter.ofPattern("dd/MM/yyyy"),
            DateTimeFormatter.ofPattern("dd-MM-yyyy"),
            DateTimeFormatter.ISO_LOCAL_DATE
    );

    private static final List<DateTimeFormatter> DATE_TIME_FORMATS = List.of(
            DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss"),
            DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"),
            DateTimeFormatter.ofPattern("dd-MM-yyyy HH:mm:ss"),
            DateTimeFormatter.ofPattern("dd-MM-yyyy HH:mm"),
            DateTimeFormatter.ISO_LOCAL_DATE_TIME
    );

    /**
     * Parse a zoned message timestamp. Uses the authoritative {@code receivedAt}
     * (always a UTC instant) when present; otherwise falls back to the SMS-body
     * timestamp string, which is assumed to be in {@code defaultZone} because it
     * carries no offset (Indian bank SMS report local wall-clock time). Either
     * way the result is a correct absolute instant — never "now" unless nothing
     * is available.
     */
    public Instant parseOrDefault(Instant receivedAt, String rawTimestamp,
                                  java.time.ZoneId defaultZone) {
        if (receivedAt != null) {
            return receivedAt;
        }
        if (rawTimestamp == null || rawTimestamp.isBlank()) {
            return Instant.now();
        }
        return parse(rawTimestamp, defaultZone).orElse(Instant.now());
    }

    /**
     * @return the parsed instant, or {@link Optional#empty()} when the value is
     *         null/blank or not in a supported format. Zone-less date-times are
     *         resolved against {@code defaultZone}.
     */
    public java.util.Optional<Instant> parse(String rawTimestamp, java.time.ZoneId defaultZone) {
        if (rawTimestamp == null || rawTimestamp.isBlank()) {
            return java.util.Optional.empty();
        }
        String t = rawTimestamp.trim();

        // Full ISO variants (Instant / OffsetDateTime carry zone info directly).
        try {
            return java.util.Optional.of(Instant.parse(t));
        } catch (DateTimeParseException ignored) {
        }
        try {
            return java.util.Optional.of(OffsetDateTime.parse(t).toInstant());
        } catch (DateTimeParseException ignored) {
        }

        // Date + time, no zone → defaultZone.
        for (DateTimeFormatter f : DATE_TIME_FORMATS) {
            try {
                return java.util.Optional.of(
                        LocalDateTime.parse(t, f).atZone(defaultZone).toInstant());
            } catch (DateTimeParseException ignored) {
            }
        }

        // Date only → start of day in defaultZone.
        for (DateTimeFormatter f : DATE_FORMATS) {
            try {
                return java.util.Optional.of(
                        LocalDate.parse(t, f).atStartOfDay(defaultZone).toInstant());
            } catch (DateTimeParseException ignored) {
            }
        }
        return java.util.Optional.empty();
    }

    /**
     * @return the parsed instant, or {@link Optional#empty()} when the value is
     *         null/blank or not in a supported format. Zone-less values are
     *         treated as UTC.
     */
    public java.util.Optional<Instant> parse(String rawTimestamp) {
        return parse(rawTimestamp, ZoneOffset.UTC);
    }

    /**
     * Convenience: parse, else fall back to {@code fallback}.
     */
    public Instant parseOrDefault(String rawTimestamp, Instant fallback) {
        return parse(rawTimestamp).orElse(fallback);
    }
}