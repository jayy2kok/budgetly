package com.budgetly.api.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "family_members")
@CompoundIndex(name = "user_family_idx", def = "{'userId': 1, 'familyGroupId': 1}", unique = true)
public class FamilyMemberDocument {

    @Id
    private String id;

    private String userId;
    private String familyGroupId;

    @Builder.Default
    private String role = "MEMBER";   // ADMIN | MEMBER

    @Builder.Default
    private String status = "ACTIVE"; // ACTIVE | INVITED | REMOVED

    @Builder.Default
    private Instant joinedAt = Instant.now();
}
