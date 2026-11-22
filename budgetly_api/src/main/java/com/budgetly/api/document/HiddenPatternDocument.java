package com.budgetly.api.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/**
 * A family's decision to stop matching a GLOBAL pattern. The global pattern
 * itself is untouched so other families keep using it; the change-stream
 * listener and the on-device cache skip globals listed here for the family.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "hidden_patterns")
@CompoundIndex(name = "family_pattern_unique_idx", def = "{'familyGroupId': 1, 'patternId': 1}", unique = true)
public class HiddenPatternDocument {

    @Id
    private String id;

    private String familyGroupId;

    /** The GLOBAL pattern hidden for {@link #familyGroupId}. */
    private String patternId;

    private String createdByUserId;

    @Builder.Default
    private Instant createdAt = Instant.now();
}
