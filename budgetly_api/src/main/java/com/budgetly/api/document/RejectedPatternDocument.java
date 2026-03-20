package com.budgetly.api.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "rejected_patterns")
public class RejectedPatternDocument {

    @Id
    private String id;

    @Indexed
    private String patternId;  // FK to pattern_registry

    private String regex;          // Snapshot of the rejected regex
    private String sampleMessage;

    @Builder.Default
    private List<String> reportedByUserIds = new ArrayList<>();

    @Builder.Default
    private int reportCount = 1;

    @Builder.Default
    private Instant rejectedAt = Instant.now();
}
