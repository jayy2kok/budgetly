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
@Document(collection = "transactions")
public class TransactionDocument {

    @Id
    private String id;

    @Indexed
    private String familyGroupId;

    private String createdByUserId;

    @Indexed
    private String categoryId;

    private double amount;

    @Builder.Default
    private String currency = "INR";

    private String merchant;
    private String description;

    @Builder.Default
    private String type = "EXPENSE";  // EXPENSE | INCOME | SUBSCRIPTION

    @Builder.Default
    private String splitMethod = "PERSONAL";  // PERSONAL | PERCENT | SHARE

    private Map<String, Double> splitConfig;

    @Builder.Default
    private String sourceType = "MANUAL";  // MANUAL | REGEX_LOCAL | LLM_SERVER

    private String sourceRawText;
    private String matchedPatternId;
    private String notes;

    @Indexed
    private Instant transactionDate;

    @Builder.Default
    private Instant createdAt = Instant.now();
}
