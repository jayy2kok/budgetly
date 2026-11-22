package com.budgetly.api.service;

import com.budgetly.api.document.HiddenPatternDocument;
import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.document.FamilyMemberDocument;
import com.budgetly.api.exception.ForbiddenException;
import com.budgetly.api.exception.ResourceNotFoundException;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.repository.HiddenPatternRepository;
import com.budgetly.api.repository.PatternRegistryRepository;
import com.budgetly.api.repository.FamilyMemberRepository;
import com.budgetly.api.repository.RejectedPatternRepository;
import com.budgetly.api.document.RejectedPatternDocument;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class PatternRegistryService {

    private final PatternRegistryRepository patternRepository;
    private final HiddenPatternRepository hiddenPatternRepository;
    private final RejectedPatternRepository rejectedPatternRepository;
    private final FamilyGroupService familyGroupService;
    private final FamilyMemberRepository familyMemberRepository;
    private final AnchorParserService anchorParserService;

    @Value("${pattern.report-threshold:5}")
    private int reportThreshold;

    @Value("${pattern.promote-usage-threshold:3}")
    private int promoteUsageThreshold;

    /**
     * Patterns the caller's family can see: active GLOBALs plus every pattern
     * owned by the family (disabled ones included, so the registry can offer
     * Enable). GLOBALs the family has hidden carry {@code hiddenForFamily}.
     */
    public List<SmsPattern> getPatterns(Instant since, String userId) {
        String familyGroupId = callerFamilyGroupId(userId);
        List<SmsPatternDocument> docs = since != null
                ? patternRepository.findVisibleForFamilySince(familyGroupId, since)
                : patternRepository.findVisibleForFamily(familyGroupId);
        Set<String> hiddenIds = hiddenPatternIds(familyGroupId);
        return docs.stream()
                .map(doc -> toDto(doc, hiddenIds.contains(doc.getId())))
                .collect(Collectors.toList());
    }

    /** Sender → pattern-count map, restricted to patterns actually matching for the family. */
    public List<Map<String, Object>> getPatternSenders(String userId) {
        String familyGroupId = callerFamilyGroupId(userId);
        Set<String> hiddenIds = hiddenPatternIds(familyGroupId);
        List<SmsPatternDocument> matchable = patternRepository.findVisibleForFamily(familyGroupId).stream()
                .filter(SmsPatternDocument::isActive)
                .filter(doc -> !hiddenIds.contains(doc.getId()))
                .collect(Collectors.toList());
        Map<String, Long> senderCounts = matchable.stream()
                .collect(Collectors.groupingBy(SmsPatternDocument::getSender, Collectors.counting()));
        return senderCounts.entrySet().stream()
                .map(e -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("sender", e.getKey());
                    m.put("patternCount", e.getValue().intValue());
                    return m;
                })
                .sorted(Comparator.comparing(m -> (String) m.get("sender")))
                .collect(Collectors.toList());
    }

    public Map<String, Object> reportPattern(String patternId, String userId, PatternReportRequest request) {
        SmsPatternDocument pattern = patternRepository.findById(patternId)
                .orElseThrow(() -> new ResourceNotFoundException("SmsPattern", patternId));

        pattern.setReportCount(pattern.getReportCount() + 1);

        boolean removed = false;
        if (pattern.getReportCount() >= reportThreshold) {
            pattern.setActive(false);
            removed = true;
            log.info("Pattern {} auto-disabled after {} reports", patternId, pattern.getReportCount());

            // Move to rejected_patterns
            Optional<RejectedPatternDocument> existing = rejectedPatternRepository.findByPatternId(patternId);
            if (existing.isPresent()) {
                RejectedPatternDocument rp = existing.get();
                if (!rp.getReportedByUserIds().contains(userId)) {
                    rp.getReportedByUserIds().add(userId);
                }
                rp.setReportCount(rp.getReportCount() + 1);
                rejectedPatternRepository.save(rp);
            } else {
                RejectedPatternDocument rp = RejectedPatternDocument.builder()
                        .patternId(patternId)
                        .template(pattern.getTemplate())
                        .sampleMessage(request.getSampleMessage())
                        .reportedByUserIds(new ArrayList<>(List.of(userId)))
                        .reportCount(pattern.getReportCount())
                        .build();
                rejectedPatternRepository.save(rp);
            }
        }
        patternRepository.save(pattern);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("patternId", patternId);
        result.put("reportCount", pattern.getReportCount());
        result.put("removed", removed);
        return result;
    }

    public PatternStatsResponse getStats() {
        List<SmsPatternDocument> active = patternRepository.findByActiveTrue();
        long totalUsage = active.stream().mapToLong(SmsPatternDocument::getUsageCount).sum();
        Map<String, long[]> senderStats = new LinkedHashMap<>();
        for (SmsPatternDocument p : active) {
            senderStats.computeIfAbsent(p.getSender(), k -> new long[]{0, 0});
            senderStats.get(p.getSender())[0]++;
            senderStats.get(p.getSender())[1] += p.getUsageCount();
        }

        PatternStatsResponse stats = new PatternStatsResponse();
        stats.setTotalPatterns(active.size());
        stats.setTotalSenders(senderStats.size());
        stats.setTotalUsage(totalUsage);
        // topSenders as list of maps
        return stats;
    }

    public SmsPatternDocument savePattern(SmsPatternDocument doc) {
        return patternRepository.save(doc);
    }

    /**
     * Persists a user's category override on a template. A blank or {@code null}
     * name clears the override so future matches fall back to uncategorized.
     */
    public SmsPattern updatePatternCategory(String patternId, String userId, String categoryName) {
        SmsPatternDocument pattern = patternRepository.findById(patternId)
                .orElseThrow(() -> new ResourceNotFoundException("SmsPattern", patternId));
        pattern.setCategoryName(categoryName == null || categoryName.isBlank() ? null : categoryName.trim());
        pattern.setUpdatedAt(Instant.now());
        return toDto(patternRepository.save(pattern));
    }

    /**
     * Creates a FAMILY-scoped, USER-authored pattern for the caller's family.
     * The template is validated against the sample message and must extract an
     * amount. A duplicate active FAMILY template for the same sender returns
     * 409; an identical GLOBAL pattern does not block (the family may shadow
     * it). Re-creating a disabled family template reactivates it.
     */
    public SmsPattern createPattern(String userId, CreatePatternRequest request) {
        String sender = requireText(request.getSender(), "sender is required");
        String template = requireText(request.getTemplate(), "template is required");
        String sampleMessage = requireText(request.getSampleMessage(), "sampleMessage is required");

        validateTemplate(template, sampleMessage, request.getExtractionMap());

        String familyGroupId = callerFamilyGroupId(userId);
        List<SmsPatternDocument> sameTemplate = patternRepository
                .findByOwnerFamilyGroupIdAndSenderAndTemplate(familyGroupId, sender, template);
        if (sameTemplate.stream().anyMatch(SmsPatternDocument::isActive)) {
            throw new IllegalStateException("A pattern with this template already exists for sender " + sender);
        }

        SmsPatternDocument doc = sameTemplate.stream()
                .filter(p -> !p.isActive())
                .findFirst()
                .orElseGet(SmsPatternDocument::new);
        doc.setSender(sender);
        doc.setTemplate(template);
        doc.setExtractionMap(extractionMapOf(request.getExtractionMap()));
        doc.setFixedValues(cleanFixedValues(request.getFixedValues()));
        doc.setSampleMessage(sampleMessage);
        doc.setCategoryName(cleanCategory(request.getCategoryName()));
        doc.setScope(SmsPatternDocument.SCOPE_FAMILY);
        doc.setOwnerFamilyGroupId(familyGroupId);
        doc.setCreatedByUserId(userId);
        doc.setSource(SmsPatternDocument.SOURCE_USER);
        doc.setActive(true);
        // Match precedence within a scope is "newest updatedAt wins", so a
        // freshly authored pattern must carry the timestamp from the start.
        doc.setUpdatedAt(Instant.now());
        return toDto(patternRepository.save(doc));
    }

    /**
     * Edits a pattern. A FAMILY pattern is updated in place by its author or a
     * family admin. A GLOBAL pattern is never mutated: the caller's family gets
     * a family copy carrying the new values, and the global is hidden for that
     * family only.
     */
    public SmsPattern updatePattern(String patternId, String userId, UpdatePatternRequest request) {
        SmsPatternDocument doc = patternRepository.findById(patternId)
                .orElseThrow(() -> new ResourceNotFoundException("SmsPattern", patternId));

        if (SmsPatternDocument.SCOPE_GLOBAL.equals(doc.getScope())) {
            return customizeGlobalForFamily(doc, userId, request);
        }

        requireEditable(doc, userId);
        applyUpdate(doc, request, callerFamilyGroupId(userId));
        return toDto(patternRepository.save(doc));
    }

    /** Hides a GLOBAL pattern for the caller's family, or deactivates a FAMILY pattern. */
    public SmsPattern disablePattern(String patternId, String userId) {
        SmsPatternDocument doc = patternRepository.findById(patternId)
                .orElseThrow(() -> new ResourceNotFoundException("SmsPattern", patternId));

        if (SmsPatternDocument.SCOPE_GLOBAL.equals(doc.getScope())) {
            String familyGroupId = callerFamilyGroupId(userId);
            hideForFamily(familyGroupId, patternId, userId);
            return toDto(doc, true);
        }

        requireEditable(doc, userId);
        doc.setActive(false);
        doc.setUpdatedAt(Instant.now());
        return toDto(patternRepository.save(doc));
    }

    /** Un-hides a GLOBAL pattern for the caller's family, or reactivates a FAMILY pattern. */
    public SmsPattern enablePattern(String patternId, String userId) {
        SmsPatternDocument doc = patternRepository.findById(patternId)
                .orElseThrow(() -> new ResourceNotFoundException("SmsPattern", patternId));

        if (SmsPatternDocument.SCOPE_GLOBAL.equals(doc.getScope())) {
            String familyGroupId = callerFamilyGroupId(userId);
            hiddenPatternRepository.deleteByFamilyGroupIdAndPatternId(familyGroupId, patternId);
            return toDto(doc, false);
        }

        requireEditable(doc, userId);
        boolean collision = patternRepository.findByOwnerFamilyGroupIdAndSenderAndTemplate(
                        doc.getOwnerFamilyGroupId(), doc.getSender(), doc.getTemplate()).stream()
                .anyMatch(p -> !p.getId().equals(doc.getId()) && p.isActive());
        if (collision) {
            throw new IllegalStateException("A pattern with this template already exists for sender " + doc.getSender());
        }
        doc.setActive(true);
        doc.setUpdatedAt(Instant.now());
        return toDto(patternRepository.save(doc));
    }

    /**
     * Promotes a FAMILY-scoped pattern to the global registry. Family admin
     * only; the pattern must have reached the usage threshold.
     */
    public SmsPattern promotePattern(String patternId, String userId) {
        SmsPatternDocument doc = patternRepository.findById(patternId)
                .orElseThrow(() -> new ResourceNotFoundException("SmsPattern", patternId));

        if (!SmsPatternDocument.SCOPE_FAMILY.equals(doc.getScope())) {
            throw new IllegalStateException("Only family-scoped patterns can be promoted");
        }
        requireFamilyAdmin(userId, doc.getOwnerFamilyGroupId());

        if (doc.getUsageCount() < promoteUsageThreshold) {
            throw new IllegalStateException("Pattern needs at least " + promoteUsageThreshold
                    + " uses to be promoted (currently " + doc.getUsageCount() + ")");
        }

        doc.setScope(SmsPatternDocument.SCOPE_GLOBAL);
        doc.setOwnerFamilyGroupId(null);
        // Family literals (e.g. "Pan Shop") must not leak into the shared library.
        doc.setFixedValues(null);
        doc.setUpdatedAt(Instant.now());
        return toDto(patternRepository.save(doc));
    }

    /**
     * Active templates for a sender, family-first (newest updatedAt) then global
     * (newest updatedAt), excluding GLOBALs the family has hidden. With no
     * family context only GLOBAL patterns are returned.
     */
    public List<SmsPatternDocument> findActiveBySender(String sender, String familyGroupId) {
        if (sender == null) return List.of();
        if (familyGroupId == null) {
            return patternRepository.findBySenderAndActiveTrue(sender).stream()
                    .filter(p -> !SmsPatternDocument.SCOPE_FAMILY.equals(p.getScope()))
                    .sorted(Comparator.comparing(SmsPatternDocument::getUpdatedAt,
                            Comparator.nullsLast(Comparator.reverseOrder())))
                    .collect(Collectors.toList());
        }
        Set<String> hiddenIds = hiddenPatternIds(familyGroupId);
        List<SmsPatternDocument> docs = patternRepository.findActiveForSenderAndFamily(sender, familyGroupId).stream()
                .filter(p -> !hiddenIds.contains(p.getId()))
                .collect(Collectors.toList());
        return docs.stream()
                .sorted(Comparator
                        .comparing((SmsPatternDocument p) -> !SmsPatternDocument.SCOPE_FAMILY.equals(p.getScope()))
                        .thenComparing(SmsPatternDocument::getUpdatedAt,
                                Comparator.nullsLast(Comparator.reverseOrder())))
                .collect(Collectors.toList());
    }

    public SmsPattern toDto(SmsPatternDocument doc) {
        return toDto(doc, false);
    }

    public SmsPattern toDto(SmsPatternDocument doc, boolean hiddenForFamily) {
        SmsPattern dto = new SmsPattern();
        dto.setId(doc.getId());
        dto.setSender(doc.getSender());
        dto.setTemplate(doc.getTemplate());
        dto.setSampleMessage(doc.getSampleMessage());
        dto.setUsageCount(doc.getUsageCount());
        dto.setCategoryName(doc.getCategoryName());
        dto.setScope(PatternScope.fromValue(doc.getScope() != null ? doc.getScope() : SmsPatternDocument.SCOPE_GLOBAL));
        dto.setOwnerFamilyGroupId(doc.getOwnerFamilyGroupId());
        dto.setCreatedByUserId(doc.getCreatedByUserId());
        dto.setSource(PatternSource.fromValue(doc.getSource() != null ? doc.getSource() : SmsPatternDocument.SOURCE_LLM));
        dto.setActive(doc.isActive());
        dto.setHiddenForFamily(hiddenForFamily);
        if (doc.getCreatedAt() != null) dto.setCreatedAt(doc.getCreatedAt().atOffset(ZoneOffset.UTC));
        if (doc.getUpdatedAt() != null) dto.setUpdatedAt(doc.getUpdatedAt().atOffset(ZoneOffset.UTC));

        dto.setExtractionMap(toExtractionMap(doc.getExtractionMap()));
        dto.setFixedValues(doc.getFixedValues() != null
                ? new LinkedHashMap<>(doc.getFixedValues())
                : new LinkedHashMap<>());
        return dto;
    }

    // ── Helpers ──────────────────────────────────────────────────

    /** Applies a validated update to a FAMILY pattern in place. */
    private void applyUpdate(SmsPatternDocument doc, UpdatePatternRequest request, String familyGroupId) {
        String sender = request.getSender() != null
                ? requireText(request.getSender(), "sender cannot be blank")
                : doc.getSender();
        String template = request.getTemplate() != null
                ? requireText(request.getTemplate(), "template cannot be blank")
                : doc.getTemplate();
        String sampleMessage = request.getSampleMessage() != null
                ? request.getSampleMessage()
                : doc.getSampleMessage();
        ExtractionMap em = request.getExtractionMap() != null
                ? request.getExtractionMap()
                : toExtractionMap(doc.getExtractionMap());

        validateTemplate(template, sampleMessage, em);
        requireNoDuplicate(familyGroupId, sender, template, doc.getId());

        doc.setSender(sender);
        doc.setTemplate(template);
        doc.setSampleMessage(sampleMessage);
        doc.setExtractionMap(extractionMapOf(em));
        if (request.getCategoryName() != null) {
            doc.setCategoryName(cleanCategory(request.getCategoryName()));
        }
        applyFixedValues(doc, request);
        doc.setUpdatedAt(Instant.now());
    }

    /**
     * Copy-on-write for a GLOBAL pattern: the family's copy receives the new
     * values and the global is hidden for that family. The copy is written
     * before the hide marker so a failure never leaves the family with no
     * matching pattern.
     */
    private SmsPattern customizeGlobalForFamily(SmsPatternDocument global,
                                                String userId,
                                                UpdatePatternRequest request) {
        String familyGroupId = callerFamilyGroupId(userId);

        SmsPatternDocument copy = patternRepository
                .findByOwnerFamilyGroupIdAndDerivedFromPatternId(familyGroupId, global.getId())
                .orElseGet(SmsPatternDocument::new);
        boolean isNewCopy = copy.getId() == null;

        if (isNewCopy) {
            copy.setScope(SmsPatternDocument.SCOPE_FAMILY);
            copy.setOwnerFamilyGroupId(familyGroupId);
            copy.setCreatedByUserId(userId);
            copy.setSource(SmsPatternDocument.SOURCE_USER);
            copy.setDerivedFromPatternId(global.getId());
            copy.setSender(global.getSender());
            copy.setTemplate(global.getTemplate());
            copy.setExtractionMap(global.getExtractionMap());
            copy.setFixedValues(global.getFixedValues());
            copy.setSampleMessage(global.getSampleMessage());
            copy.setCategoryName(global.getCategoryName());
            copy.setActive(true);
        }

        String sender = request.getSender() != null
                ? requireText(request.getSender(), "sender cannot be blank")
                : copy.getSender();
        String template = request.getTemplate() != null
                ? requireText(request.getTemplate(), "template cannot be blank")
                : copy.getTemplate();
        String sampleMessage = request.getSampleMessage() != null
                ? request.getSampleMessage()
                : copy.getSampleMessage();
        ExtractionMap em = request.getExtractionMap() != null
                ? request.getExtractionMap()
                : toExtractionMap(copy.getExtractionMap());

        validateTemplate(template, sampleMessage, em);
        requireNoDuplicate(familyGroupId, sender, template, copy.getId());

        copy.setSender(sender);
        copy.setTemplate(template);
        copy.setSampleMessage(sampleMessage);
        copy.setExtractionMap(extractionMapOf(em));
        if (request.getCategoryName() != null) {
            copy.setCategoryName(cleanCategory(request.getCategoryName()));
        }
        applyFixedValues(copy, request);
        copy.setUpdatedAt(Instant.now());
        copy = patternRepository.save(copy);

        hideForFamily(familyGroupId, global.getId(), userId);
        return toDto(copy);
    }

    /** fixedValues: omitted/empty leaves them unchanged, JSON null clears them. */
    private void applyFixedValues(SmsPatternDocument doc, UpdatePatternRequest request) {
        // Generated models default the map to an empty map when the field is
        // omitted, so empty means "unchanged"; JSON null explicitly clears it.
        if (request.getFixedValues() == null) {
            doc.setFixedValues(null);
        } else if (!request.getFixedValues().isEmpty()) {
            doc.setFixedValues(cleanFixedValues(request.getFixedValues()));
        }
    }

    private void hideForFamily(String familyGroupId, String patternId, String userId) {
        if (hiddenPatternRepository.findByFamilyGroupIdAndPatternId(familyGroupId, patternId).isPresent()) {
            return;
        }
        hiddenPatternRepository.save(HiddenPatternDocument.builder()
                .familyGroupId(familyGroupId)
                .patternId(patternId)
                .createdByUserId(userId)
                .build());
    }

    private Set<String> hiddenPatternIds(String familyGroupId) {
        return hiddenPatternRepository.findByFamilyGroupId(familyGroupId).stream()
                .map(HiddenPatternDocument::getPatternId)
                .collect(Collectors.toSet());
    }

    /** Resolves the caller's current family (auto-creating a personal family if needed). */
    private String callerFamilyGroupId(String userId) {
        return familyGroupService.getMyFamily(userId).getId();
    }

    private String requireText(String value, String message) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException(message);
        return value.trim();
    }

    private String cleanCategory(String categoryName) {
        return categoryName == null || categoryName.isBlank() ? null : categoryName.trim();
    }

    /** Fields a user may pin to a literal value instead of extracting them. */
    private static final Set<String> FIXABLE_FIELDS = Set.of("merchant", "accountLast4", "bankName", "notes");

    /**
     * Normalises user-supplied fixed values: allowed fields only, blank values
     * dropped. Fields that drive parsing (amount, timestamp, type) are rejected
     * because a literal there would silently corrupt every matching message.
     */
    private Map<String, String> cleanFixedValues(Map<String, String> values) {
        if (values == null || values.isEmpty()) return null;
        Map<String, String> cleaned = new LinkedHashMap<>();
        for (Map.Entry<String, String> entry : values.entrySet()) {
            String field = entry.getKey();
            if (!FIXABLE_FIELDS.contains(field)) {
                throw new IllegalArgumentException(
                        "Fixed values are not supported for field '" + field
                                + "' (allowed: merchant, accountLast4, bankName, notes)");
            }
            if (entry.getValue() != null && !entry.getValue().isBlank()) {
                cleaned.put(field, entry.getValue().trim());
            }
        }
        return cleaned.isEmpty() ? null : cleaned;
    }

    /** Validates a draft template: it must parse the sample message and extract an amount. */
    private void validateTemplate(String template, String sampleMessage, ExtractionMap em) {
        Map<String, String> extracted = anchorParserService.parse(template, sampleMessage);
        if (extracted == null || extracted.isEmpty()) {
            throw new IllegalArgumentException("Template does not match the sample message");
        }
        String amountGroup = em != null ? em.getAmount() : null;
        if (amountGroup == null || !extracted.containsKey(amountGroup)) {
            throw new IllegalArgumentException("Template must extract an amount ({amount})");
        }
    }

    /** Blocks a second active FAMILY template for the same sender. */
    private void requireNoDuplicate(String familyGroupId, String sender, String template, String excludeId) {
        boolean duplicate = patternRepository
                .findByOwnerFamilyGroupIdAndSenderAndTemplate(familyGroupId, sender, template).stream()
                .anyMatch(p -> p.isActive() && !p.getId().equals(excludeId));
        if (duplicate) {
            throw new IllegalStateException("A pattern with this template already exists for sender " + sender);
        }
    }

    /** Enforces the author-or-admin gate on a FAMILY pattern. */
    private void requireEditable(SmsPatternDocument doc, String userId) {
        boolean isAuthor = doc.getCreatedByUserId() != null && doc.getCreatedByUserId().equals(userId);
        if (!isAuthor) {
            requireFamilyAdmin(userId, doc.getOwnerFamilyGroupId());
        }
    }

    private void requireFamilyAdmin(String userId, String familyGroupId) {
        FamilyMemberDocument member = familyMemberRepository
                .findByUserIdAndFamilyGroupId(userId, familyGroupId)
                .orElseThrow(() -> new ForbiddenException("Not a member of this family"));
        if (!"ACTIVE".equals(member.getStatus()) || !"ADMIN".equals(member.getRole())) {
            throw new ForbiddenException("Admin role required for this action");
        }
    }

    /** Converts an OpenAPI ExtractionMap to the document's Map<String,String>. */
    private Map<String, String> extractionMapOf(ExtractionMap em) {
        if (em == null) return null;
        Map<String, String> map = new LinkedHashMap<>();
        map.put("amount", em.getAmount());
        if (em.getMerchant() != null) map.put("merchant", em.getMerchant());
        if (em.getTimestamp() != null) map.put("timestamp", em.getTimestamp());
        if (em.getAccountLast4() != null) map.put("accountLast4", em.getAccountLast4());
        if (em.getType() != null) map.put("type", em.getType());
        if (em.getNotes() != null) map.put("notes", em.getNotes());
        return map;
    }

    /** Converts the document's Map<String,String> to an OpenAPI ExtractionMap (never null). */
    private ExtractionMap toExtractionMap(Map<String, String> source) {
        ExtractionMap em = new ExtractionMap();
        if (source == null) return em;
        em.setAmount(source.get("amount"));
        em.setMerchant(source.get("merchant"));
        em.setTimestamp(source.get("timestamp"));
        em.setAccountLast4(source.get("accountLast4"));
        em.setType(source.get("type"));
        em.setNotes(source.get("notes"));
        return em;
    }
}
