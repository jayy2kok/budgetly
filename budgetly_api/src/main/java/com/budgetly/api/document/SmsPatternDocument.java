package com.budgetly.api.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "pattern_registry")
public class SmsPatternDocument {

    @Id
    private String id;

    @Indexed
    private String sender;   // e.g. "HDFCBK", "SBIUPI"

    private String regex;    // Java/Dart-compatible regex with named capture groups

    // Maps capture group names to transaction fields
    private Map<String, String> extractionMap;

    private String sampleMessage;

    @Builder.Default
    private long usageCount = 0;

    @Builder.Default
    private boolean active = true;

    @Builder.Default
    private int reportCount = 0;

    @Builder.Default
    private Instant createdAt = Instant.now();

    private Instant updatedAt;
}
