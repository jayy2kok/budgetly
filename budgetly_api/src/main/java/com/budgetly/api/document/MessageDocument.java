package com.budgetly.api.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "messages")
@CompoundIndexes({
    @CompoundIndex(name = "status_createdAt_idx", def = "{'status': 1, 'createdAt': 1}"),
    @CompoundIndex(name = "userId_status_idx", def = "{'userId': 1, 'status': 1}"),
    @CompoundIndex(name = "familyGroupId_status_idx", def = "{'familyGroupId': 1, 'status': 1}")
})
public class MessageDocument {

    public static final String STATUS_PENDING = "PENDING";
    public static final String STATUS_IN_PROGRESS = "IN_PROGRESS";
    public static final String STATUS_PROCESSED = "PROCESSED";
    public static final String STATUS_FAILED = "FAILED";
    public static final String STATUS_CONFIRMED = "CONFIRMED";
    public static final String STATUS_REJECTED = "REJECTED";
    public static final String STATUS_IGNORED = "IGNORED";

    @Id
    private String id;

    @Indexed
    @Builder.Default
    private String messageId = UUID.randomUUID().toString();

    @Indexed
    private String userId;

    @Indexed
    private String familyGroupId;

    private String sender;
    private String rawText;

    @Indexed
    @Builder.Default
    private String status = STATUS_PENDING;

    @Builder.Default
    private String parseSource = "LLM_SERVER";  // REGEX_LOCAL | LLM_SERVER | MANUAL

    private String matchedPatternId;

    // Parsed transaction data (stored as embedded map for flexibility)
    private Map<String, Object> parsedTransactionData;

    private String linkedTransactionId;

    @Indexed
    @Builder.Default
    private Instant createdAt = Instant.now();

    @Builder.Default
    private Instant receivedAt = Instant.now();

    private Instant processingStartedAt;

    private Instant processedAt;

    @Builder.Default
    private int retryCount = 0;

    private String errorMessage;

    private String resumeToken;
}
