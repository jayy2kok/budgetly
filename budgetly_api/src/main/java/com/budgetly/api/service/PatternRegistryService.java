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
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
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
    private final MongoTemplate mongoTemplate;

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

    /**
     * Flags a pattern as incorrect. A user's report is counted once; when the
     * report count reaches the threshold the pattern is auto-disabled and
     * snapshotted into rejected_patterns. GLOBAL patterns are the shared
     * library, so a report only hides the pattern for the caller's family
     * (FAMILY patterns are reported by their own family and reactivate there).
     */
    public Map<String, Object> reportPattern(String patternId, String userId, PatternReportRequest request) {
        SmsPatternDocument pattern = patternRepository.findById(patternId)
                .orElseThrow(() -> new ResourceNotFoundException("SmsPattern", patternId));
        String familyGroupId = callerFamilyGroupId(userId);

        // A per-user duplicate report would inflate the count; count the user
        // once, and reactivate a pattern reported by this user before so a
        // previously disabled pattern is not resurrected by the threshold.
        if (!addUniqueReporter(patternId, userId)) {
            return reportResult(pattern, familyGroupId, false);
        }

        // $inc keeps concurrent reports from losing updates (read-modify-write
        // would drop one report's count under load).
        int reportCount = incrementReportCount(patternId);
        pattern.setReportCount(reportCount);

        boolean removed = reportCount >= reportThreshold;
        if (removed) {
            pattern.setActive(false);
            pattern.setUpdatedAt(Instant.now());
            patternRepository.save(pattern);
            log.info("Pattern {} auto-disabled after {} reports", patternId, reportCount);
            snapshotRejectedPattern(pattern, request.getSampleMessage(), userId, reportCount);

            if (SmsPatternDocument.SCOPE_GLOBAL.equals(pattern.getScope())) {
                hideForFamily(familyGroupId, patternId, userId);
            }
        }

        return reportResult(pattern, familyGroupId, removed);
    }

    /** Rejects patterns the caller cannot see; FAMILY patterns require the author or a family admin. */
    public Map<String, Object> reportResult(SmsPatternDocument pattern, String familyGroupId, boolean removed) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("patternId", pattern.getId());
        result.put("reportCount", pattern.getReportCount());
        result.put("removed", removed);
        return result;
    }

    private boolean addUniqueReporter(String patternId, String userId) {
        Long added = mongoTemplate.updateFirst(
                Query.query(Criteria.where("_id").is(patternId)),
                new Update().addToSet("reportedByUserIds", userId),
                SmsPatternDocument.class).getModifiedCount();
        return added != null && added > 0;
    }

    private int incrementReportCount(String patternId) {
        SmsPatternDocument updated = mongoTemplate.findAndModify(
                Query.query(Criteria.where("_id").is(patternId)),
                new Update().inc("reportCount", 1),
                org.springframework.data.mongodb.core.FindAndModifyOptions.options().returnNew(true),
                SmsPatternDocument.class);
        return updated != null ? updated.getReportCount() : 0;
    }

    private void snapshotRejectedPattern(SmsPatternDocument pattern, String sampleMessage,
                                         String userId, int reportCount) {
        Optional<RejectedPatternDocument> existing = rejectedPatternRepository.findByPatternId(pattern.getId());
        if (existing.isPresent()) {
            RejectedPatternDocument rp = existing.get();
            if (!rp.getReportedByUserIds().contains(userId)) {
                rp.getReportedByUserIds().add(userId);
            }
            rp.setReportCount(reportCount);
            rejectedPatternRepository.save(rp);
        } else {
            rejectedPatternRepository.save(RejectedPatternDocument.builder()
                    .patternId(pattern.getId())
                    .template(pattern.getTemplate())
                    .sampleMessage(sampleMessage)
                    .reportedByUserIds(new ArrayList<>(List.of(userId)))
                    .reportCount(reportCount)
                    .build());
        }
    }

    /** Statistics for the caller's family: its active patterns plus the active globals it can see. */
    public PatternStatsResponse getStats(String userId) {
        String familyGroupId = callerFamilyGroupId(userId);
        List<SmsPatternDocument> active = patternRepository.findVisibleForFamily(familyGroupId).stream()
                .filter(SmsPatternDocument::isActive)
                .collect(Collectors.toList());
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
     * Sets or clears the caller's category override on a template. A blank or
     * {@code null} name clears the override so future matches fall back to
     * uncategorized. A FAMILY pattern is editable by its author or a family
     * admin; a GLOBAL pattern is never mutated, so the caller's family gets a
     * family copy carrying the category (copy-on-write, like an edit).
     */
    public SmsPattern updatePatternCategory(String patternId, String userId, String categoryName) {
        SmsPatternDocument pattern = patternRepository.findById(patternId)
                .orElseThrow(() -> new ResourceNotFoundException("SmsPattern", patternId));
        String familyGroupId = callerFamilyGroupId(userId);
        String normalized = categoryName == null || categoryName.isBlank() ? null : categoryName.trim();

        if (SmsPatternDocument.SCOPE_GLOBAL.equals(pattern.getScope())) {
            // The category is family-specific: customize the global into the
            // caller's family copy instead of mutating the shared template.
            return customizeGlobalForFamily(pattern, userId,
                    categoryUpdateRequest(normalized));
        }

        requireEditable(pattern, userId);
        pattern.setCategoryName(normalized);
        pattern.setUpdatedAt(Instant.now());
        return toDto(patternRepository.save(pattern), false);
    }

    /** A category-only update request (fixed values, template and sample untouched). */
    private UpdatePatternRequest categoryUpdateRequest(String categoryName) {
        UpdatePatternRequest request = new UpdatePatternRequest();
        // An explicit empty string clears the category; null would mean "leave
        // the stored category unchanged" (see applyUpdate).
        request.setCategoryName(categoryName == null ? "" : categoryName);
        return request;
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
        // A reactivated template was authored here, so it must not keep a link
        // to a global it was copied from (that would make a later edit update
        // the wrong family copy).
        doc.setDerivedFromPatternId(null);
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
            // A family copy created by a prior edit would still shadow the
            // re-enabled global (family-first precedence), so deactivate it.
            patternRepository.findByOwnerFamilyGroupIdAndDerivedFromPatternId(familyGroupId, patternId)
                    .ifPresent(copy -> {
                        copy.setActive(false);
                        copy.setUpdatedAt(Instant.now());
                        patternRepository.save(copy);
                    });
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

        // A promoted pattern becomes the shared template for its sender; a
        // conflicting active GLOBAL would silently lose matches to the
        // family-first precedence rule, so refuse to create that shadow.
        boolean globalDuplicate = patternRepository
                .findBySenderAndTemplateAndScope(doc.getSender(), doc.getTemplate(),
                        SmsPatternDocument.SCOPE_GLOBAL).stream()
                .anyMatch(SmsPatternDocument::isActive);
        if (globalDuplicate) {
            throw new IllegalStateException("An active global pattern with this template already exists for sender "
                    + doc.getSender());
        }

        doc.setScope(SmsPatternDocument.SCOPE_GLOBAL);
        doc.setOwnerFamilyGroupId(null);
        // A promoted pattern is a first-class global, not the copy of another
        // global, so it must not keep a derivedFrom pointer.
        doc.setDerivedFromPatternId(null);
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
        }
        // An existing copy may have been disabled for this family; editing the
        // global again re-activates it — the family is actively using it.
        copy.setActive(true);

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
