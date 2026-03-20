package com.budgetly.api.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "family_groups")
public class FamilyGroupDocument {

    @Id
    private String id;

    private String name;
    private String avatarInitial;

    @Builder.Default
    private String defaultCurrency = "INR";

    @Builder.Default
    private String regionFormat = "IN";

    @Builder.Default
    private boolean expenseAlertsEnabled = true;

    @Builder.Default
    private double monthlyBudgetLimit = 50000.0;

    private String createdByUserId;

    // Invite code for joining
    @Indexed
    private String inviteCode;

    private Instant inviteCodeExpiresAt;

    @Builder.Default
    private Instant createdAt = Instant.now();
}
