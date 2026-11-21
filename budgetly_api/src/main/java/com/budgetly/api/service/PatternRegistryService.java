package com.budgetly.api.service;

import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.document.FamilyMemberDocument;
import com.budgetly.api.exception.ForbiddenException;
import com.budgetly.api.exception.ResourceNotFoundException;
import com.budgetly.api.generated.model.*;
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
    private final RejectedPatternRepository rejectedPatternRepository;
    private final FamilyGroupService familyGroupService;
    private final FamilyMemberRepository familyMemberRepository;
    private final AnchorParserService anchorParserService;

    @Value("${pattern.report-threshold:5}")
    private int reportThreshold;

    @Value("${pattern.promote-usage-threshold:3}")
    private int promoteUsageThreshold;

    /** Active patterns visible to the caller's family: global + the family's own patterns. */
    public List<SmsPattern> getPatterns(Instant since, String userId) {
        String familyGroupId = callerFamilyGroupId(userId);
        List<SmsPatternDocument> docs = since != null
                ? patternRepository.findActiveGlobalOrFamilySince(familyGroupId, since)
                : patternRepository.findActiveGlobalOrFamily(familyGroupId);
        return docs.stream().map(this::toDto).collect(Collectors.toList());
    }

    /** Sender → pattern-count map, restricted to patterns visible to the caller's family. */
    public List<Map<String, Object>> getPatternSenders(String userId) {
        String familyGroupId = callerFamilyGroupId(userId);
        List<SmsPatternDocument> active = patternRepository.findActiveGlobalOrFamily(familyGroupId);
        Map<String, Long> senderCounts = active.stream()
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
     * amount; a duplicate active template for the same sender returns 409.
     */
    public SmsPattern createPattern(String userId, CreatePatternRequest request) {
        String sender = requireText(request.getSender(), "sender is required");
        String template = requireText(request.getTemplate(), "template is required");
        String sampleMessage = requireText(request.getSampleMessage(), "sampleMessage is required");

        validateTemplate(template, sampleMessage, request.getExtractionMap());

        if (patternRepository.existsBySenderAndTemplateAndActiveTrue(sender, template)) {
            throw new IllegalStateException("A pattern with this template already exists for sender " + sender);
        }

        String familyGroupId = callerFamilyGroupId(userId);
        SmsPatternDocument doc = SmsPatternDocument.builder()
                .sender(sender)
                .template(template)
                .extractionMap(extractionMapOf(request.getExtractionMap()))
                .sampleMessage(sampleMessage)
                .categoryName(cleanCategory(request.getCategoryName()))
                .scope(SmsPatternDocument.SCOPE_FAMILY)
                .ownerFamilyGroupId(familyGroupId)
                .createdByUserId(userId)
                .source(SmsPatternDocument.SOURCE_USER)
                .usageCount(0)
                .active(true)
                .build();
        return toDto(patternRepository.save(doc));
    }

    /**
     * Updates a FAMILY-scoped pattern. Only the author or a family admin may
     * edit it; GLOBAL patterns are read-only.
     */
    public SmsPattern updatePattern(String patternId, String userId, UpdatePatternRequest request) {
        SmsPatternDocument doc = requireEditable(patternId, userId);

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

        boolean duplicateByAnother = patternRepository.findBySenderAndActiveTrue(sender).stream()
                .anyMatch(p -> template.equals(p.getTemplate()) && !p.getId().equals(doc.getId()));
        if (duplicateByAnother) {
            throw new IllegalStateException("A pattern with this template already exists for sender " + sender);
        }

        doc.setSender(sender);
        doc.setTemplate(template);
        doc.setSampleMessage(sampleMessage);
        doc.setExtractionMap(extractionMapOf(em));
        if (request.getCategoryName() != null) {
            doc.setCategoryName(cleanCategory(request.getCategoryName()));
        }
        doc.setUpdatedAt(Instant.now());
        return toDto(patternRepository.save(doc));
    }

    /** Deletes a FAMILY-scoped pattern the caller is allowed to manage. */
    public void deletePattern(String patternId, String userId) {
        SmsPatternDocument doc = requireEditable(patternId, userId);
        patternRepository.delete(doc);
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
        doc.setUpdatedAt(Instant.now());
        return toDto(patternRepository.save(doc));
    }

    /**
     * Active templates for a sender, family-first (newest updatedAt) then global
     * (newest updatedAt). Used by the change-stream listener to parse messages.
     */
    public List<SmsPatternDocument> findActiveBySender(String sender, String familyGroupId) {
        if (sender == null) return List.of();
        if (familyGroupId == null) {
            return patternRepository.findBySenderAndActiveTrue(sender);
        }
        List<SmsPatternDocument> docs = patternRepository.findActiveForSenderAndFamily(sender, familyGroupId);
        return docs.stream()
                .sorted(Comparator
                        .comparing((SmsPatternDocument p) -> !SmsPatternDocument.SCOPE_FAMILY.equals(p.getScope()))
                        .thenComparing(SmsPatternDocument::getUpdatedAt,
                                Comparator.nullsLast(Comparator.reverseOrder())))
                .collect(Collectors.toList());
    }

    public SmsPattern toDto(SmsPatternDocument doc) {
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
        if (doc.getCreatedAt() != null) dto.setCreatedAt(doc.getCreatedAt().atOffset(ZoneOffset.UTC));
        if (doc.getUpdatedAt() != null) dto.setUpdatedAt(doc.getUpdatedAt().atOffset(ZoneOffset.UTC));

        dto.setExtractionMap(toExtractionMap(doc.getExtractionMap()));
        return dto;
    }

    // ── Helpers ──────────────────────────────────────────────────

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

    /** Loads a pattern and enforces the author-or-admin edit gate. */
    private SmsPatternDocument requireEditable(String patternId, String userId) {
        SmsPatternDocument doc = patternRepository.findById(patternId)
                .orElseThrow(() -> new ResourceNotFoundException("SmsPattern", patternId));

        if (SmsPatternDocument.SCOPE_GLOBAL.equals(doc.getScope())) {
            throw new ForbiddenException("Global patterns are read-only");
        }
        boolean isAuthor = doc.getCreatedByUserId() != null && doc.getCreatedByUserId().equals(userId);
        if (!isAuthor) {
            requireFamilyAdmin(userId, doc.getOwnerFamilyGroupId());
        }
        return doc;
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
        return em;
    }
}