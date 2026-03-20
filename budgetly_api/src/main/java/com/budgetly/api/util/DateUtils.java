package com.budgetly.api.util;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;

public class DateUtils {

    private DateUtils() {}

    public static Instant startOfMonth(String yearMonth) {
        // yearMonth = "YYYY-MM"
        return LocalDate.parse(yearMonth + "-01", DateTimeFormatter.ISO_LOCAL_DATE)
                .atStartOfDay(ZoneOffset.UTC)
                .toInstant();
    }

    public static Instant endOfMonth(String yearMonth) {
        LocalDate start = LocalDate.parse(yearMonth + "-01");
        LocalDate end = start.withDayOfMonth(start.lengthOfMonth());
        return end.atTime(23, 59, 59).toInstant(ZoneOffset.UTC);
    }

    public static String currentYearMonth() {
        return LocalDate.now(ZoneOffset.UTC).format(DateTimeFormatter.ofPattern("yyyy-MM"));
    }
}
