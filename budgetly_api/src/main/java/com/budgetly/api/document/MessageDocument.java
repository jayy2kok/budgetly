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
@Document(collection = "messages")
public class MessageDocument {

    @Id
    private String id;

    @Indexed
    private String userId;

    @Indexed
    private String familyGroupId;

    private String sender;
    private String rawText;

    @Builder.Default
    private String status = "PENDING";  // PENDING | CONFIRMED | REJECTED | IGNORED

    @Builder.Default
    private String parseSource = "LLM_SERVER";  // REGEX_LOCAL | LLM_SERVER | MANUAL

    private String matchedPatternId;

    // Parsed transaction data (stored as embedded map for flexibility)
    private Map<String, Object> parsedTransactionData;

    private String linkedTransactionId;

    @Builder.Default
    private Instant receivedAt = Instant.now();
}
