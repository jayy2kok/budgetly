package com.budgetly.api.service;

import org.springframework.stereotype.Component;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.format.ResolverStyle;
import java.util.List;

/**
 * Parses the human-readable timestamps that SMS bodies / LLM results carry
 * (e.g. {@code "01/10/2026"}, {@code "2026-10-01 14:30"}) into a transaction
 * date. Backfilled SMS predate "now", so using {@code Instant.now()} would
 * corrupt feeds and budgets — this is the single parser shared by every
 * transaction-creation call site (WORK-003).
 *
 * <p>Supported: ISO instant / offset date-times, ISO date, {@code dd/MM/yyyy},
 * {@code dd-MM-yyyy}, the two-digit-year bank form {@code dd/MM/yy} /
 * {@code dd-MM-yy} ({@code 26} → 2026), each optionally with a
 * {@code HH:mm[:ss]} time part. Date-only values resolve to the received
 * time-of-day (see {@link #resolveTransactionDate}).
 *
 * <p>Strict resolution rejects impossible calendar dates ({@code 31/02/2026})
 * instead of silently rolling them forward to a real date — a rolled date
 * would land transactions in the wrong budget month.
 */
@Component
public class TransactionDateParser {

    private static DateTimeFormatter strict(String pattern) {
        return DateTimeFormatter.ofPattern(pattern).withResolverStyle(ResolverStyle.STRICT);
    }

    private static final List<DateTimeFormatter> DATE_FORMATS = List.of(
            strict("dd/MM/uuuu"),
            strict("dd-MM-uuuu"),
            strict("dd/MM/uu"),
            strict("dd-MM-uu"),
            DateTimeFormatter.ISO_LOCAL_DATE
    );

    private static final List<DateTimeFormatter> DATE_TIME_FORMATS = List.of(
            strict("dd/MM/uuuu HH:mm:ss"),
            strict("dd/MM/uuuu HH:mm"),
            strict("dd-MM-uuuu HH:mm:ss"),
            strict("dd-MM-uuuu HH:mm"),
            strict("dd/MM/uu HH:mm:ss"),
            strict("dd/MM/uu HH:mm"),
            strict("dd-MM-uu HH:mm:ss"),
            strict("dd-MM-uu HH:mm"),
            DateTimeFormatter.ISO_LOCAL_DATE_TIME
    );

    /**
     * Resolves a transaction instant from the SMS received time and the
     * timestamp written in the body. The body date is authoritative: a body
     * with a date and time wins outright; a date-only body keeps its date and
     * takes the received time-of-day (or {@code 00:00:00} when unavailable).
     * Without a body timestamp the received instant is used, and with neither
     * the current time.
     */
    public Instant resolveTransactionDate(Instant receivedAt, String rawTimestamp,
                                          java.time.ZoneId defaultZone) {
        if (rawTimestamp != null && !rawTimestamp.isBlank()) {
            String t = rawTimestamp.trim();
            Instant dateTime = parseDateTime(t, defaultZone);
            if (dateTime != null) {
                return dateTime;
            }
            LocalDate dateOnly = parseDateOnly(t);
            if (dateOnly != null) {
                java.time.LocalTime time = receivedAt != null
                        ? LocalDateTime.ofInstant(receivedAt, defaultZone).toLocalTime()
                        : java.time.LocalTime.MIDNIGHT;
                // The body's date is authoritative; the received time-of-day
                // completes it (midnight when no received time is available).
                return dateOnly.atTime(time).atZone(defaultZone).toInstant();
            }
        }
        return receivedAt != null ? receivedAt : Instant.now();
    }

    /** @return the parsed date+time instant, or null when the value carries no time. */
    private Instant parseDateTime(String value, java.time.ZoneId defaultZone) {
        try {
            return Instant.parse(value);
        } catch (DateTimeParseException ignored) {
        }
        try {
            return OffsetDateTime.parse(value).toInstant();
        } catch (DateTimeParseException ignored) {
        }
        for (DateTimeFormatter f : DATE_TIME_FORMATS) {
            try {
                return LocalDateTime.parse(value, f).atZone(defaultZone).toInstant();
            } catch (DateTimeParseException ignored) {
            }
        }
        return null;
    }

    /** @return the parsed date, or null when the value is not a supported date-only format. */
    private LocalDate parseDateOnly(String value) {
        for (DateTimeFormatter f : DATE_FORMATS) {
            try {
                return LocalDate.parse(value, f);
            } catch (DateTimeParseException ignored) {
            }
        }
        return null;
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
}