package com.budgetly.api.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "pattern_registry")
@CompoundIndex(name = "sender_scope_owner_active_idx", def = "{'sender': 1, 'scope': 1, 'ownerFamilyGroupId': 1, 'active': 1}")
public class SmsPatternDocument {

    /** Pattern visibility scope. GLOBAL patterns serve all families; FAMILY patterns are family-owned. */
    public static final String SCOPE_GLOBAL = "GLOBAL";
    public static final String SCOPE_FAMILY = "FAMILY";

    /** Pattern origin. LLM = learned by the first-sighting pipeline; USER = authored via the pattern builder. */
    public static final String SOURCE_LLM = "LLM";
    public static final String SOURCE_USER = "USER";

    @Id
    private String id;

    @Indexed
    private String sender;   // e.g. "HDFCBK", "SBIUPI"

    private String template; // Anchor template with {tokens}

    // Maps capture group names to transaction fields
    private Map<String, String> extractionMap;

    /**
     * Fixed literal values per transaction field (merchant, accountLast4, notes).
     * A fixed value wins over the value extracted from the template.
     */
    private Map<String, String> fixedValues;

    private String sampleMessage;

    /** User-overridden category name (resolved per-family at transaction time). */
    private String categoryName;

    @Builder.Default
    private long usageCount = 0;

    @Builder.Default
    private boolean active = true;

    @Builder.Default
    private int reportCount = 0;

    /** GLOBAL (serves all families) or FAMILY (family-owned). */
    @Builder.Default
    private String scope = SCOPE_GLOBAL;

    /** Family that authored this pattern; null for GLOBAL patterns. */
    private String ownerFamilyGroupId;

    /** User who authored this pattern; null for LLM-learned patterns. */
    private String createdByUserId;

    /** LLM (first-sighting pipeline) or USER (authored via pattern builder). */
    @Builder.Default
    private String source = SOURCE_LLM;

    @Builder.Default
    private Instant createdAt = Instant.now();

    private Instant updatedAt;
}
