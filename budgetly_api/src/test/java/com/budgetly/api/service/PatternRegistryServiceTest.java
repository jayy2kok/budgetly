package com.budgetly.api.service;

import com.budgetly.api.document.FamilyMemberDocument;
import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.exception.ForbiddenException;
import com.budgetly.api.exception.ResourceNotFoundException;
import com.budgetly.api.generated.model.CreatePatternRequest;
import com.budgetly.api.generated.model.ExtractionMap;
import com.budgetly.api.generated.model.FamilyGroup;
import com.budgetly.api.generated.model.PatternScope;
import com.budgetly.api.generated.model.PatternSource;
import com.budgetly.api.generated.model.SmsPattern;
import com.budgetly.api.generated.model.UpdatePatternRequest;
import com.budgetly.api.repository.FamilyMemberRepository;
import com.budgetly.api.repository.PatternRegistryRepository;
import com.budgetly.api.repository.RejectedPatternRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class PatternRegistryServiceTest {

    private PatternRegistryRepository patternRepository;
    private RejectedPatternRepository rejectedPatternRepository;
    private FamilyGroupService familyGroupService;
    private FamilyMemberRepository familyMemberRepository;
    private PatternRegistryService service;

    @BeforeEach
    void setUp() {
        patternRepository = mock(PatternRegistryRepository.class);
        rejectedPatternRepository = mock(RejectedPatternRepository.class);
        familyGroupService = mock(FamilyGroupService.class);
        familyMemberRepository = mock(FamilyMemberRepository.class);
        service = new PatternRegistryService(patternRepository, rejectedPatternRepository,
                familyGroupService, familyMemberRepository, new AnchorParserService());
        ReflectionTestUtils.setField(service, "promoteUsageThreshold", 3);
    }

    private FamilyGroup family(String id) {
        FamilyGroup f = new FamilyGroup();
        f.setId(id);
        return f;
    }

    private SmsPatternDocument familyPattern(String id, String familyGroupId, String createdByUserId,
            long usageCount) {
        return SmsPatternDocument.builder()
                .id(id)
                .sender("HDFCBK")
                .template("Rs.{amount} debited for {merchant}")
                .sampleMessage("Rs.500 debited for Amazon")
                .extractionMap(Map.of("amount", "amount", "merchant", "merchant"))
                .usageCount(usageCount)
                .active(true)
                .scope(SmsPatternDocument.SCOPE_FAMILY)
                .ownerFamilyGroupId(familyGroupId)
                .createdByUserId(createdByUserId)
                .source(SmsPatternDocument.SOURCE_USER)
                .build();
    }

    private CreatePatternRequest createRequest(String template, String sampleMessage, String amountGroup) {
        CreatePatternRequest req = new CreatePatternRequest();
        req.setSender("HDFCBK");
        req.setTemplate(template);
        req.setSampleMessage(sampleMessage);
        if (amountGroup != null) {
            ExtractionMap em = new ExtractionMap();
            em.setAmount(amountGroup);
            req.setExtractionMap(em);
        }
        return req;
    }

    private FamilyMemberDocument member(String userId, String familyGroupId, String role) {
        return FamilyMemberDocument.builder()
                .userId(userId)
                .familyGroupId(familyGroupId)
                .role(role)
                .status("ACTIVE")
                .build();
    }

    // ── createPattern ────────────────────────────────────────────

    @Test
    void createPattern_validTemplate_savesFamilyScopedUserPattern() {
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.existsBySenderAndTemplateAndActiveTrue("HDFCBK", "Rs.{amount} debited for {merchant}"))
                .thenReturn(false);
        when(patternRepository.save(any(SmsPatternDocument.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.createPattern("u1",
                createRequest("Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", "amount"));

        assertThat(result.getScope()).isEqualTo(PatternScope.FAMILY);
        assertThat(result.getSource()).isEqualTo(PatternSource.USER);
        assertThat(result.getOwnerFamilyGroupId()).isEqualTo("fam-1");
        assertThat(result.getCreatedByUserId()).isEqualTo("u1");
    }

    @Test
    void createPattern_templateDoesNotMatchSample_throws() {
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));

        assertThatThrownBy(() -> service.createPattern("u1",
                createRequest("Hello {amount} world", "Rs.500 debited for Amazon", "amount")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void createPattern_missingAmountTag_throws() {
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));

        assertThatThrownBy(() -> service.createPattern("u1",
                createRequest("Spent {merchant}", "Spent Amazon", "amount")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void createPattern_duplicateTemplate_throws() {
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.existsBySenderAndTemplateAndActiveTrue("HDFCBK", "Rs.{amount} debited for {merchant}"))
                .thenReturn(true);

        assertThatThrownBy(() -> service.createPattern("u1",
                createRequest("Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", "amount")))
                .isInstanceOf(IllegalStateException.class);
    }

    // ── updatePattern / deletePattern ownership ──────────────────

    @Test
    void updatePattern_authorAllowed_updatesTemplate() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(patternRepository.findBySenderAndActiveTrue("HDFCBK")).thenReturn(List.of(doc));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        UpdatePatternRequest req = new UpdatePatternRequest();
        req.setTemplate("Rs.{amount} debited at {merchant}");
        req.setSampleMessage("Rs.500 debited at Amazon");
        ExtractionMap em = new ExtractionMap();
        em.setAmount("amount");
        em.setMerchant("merchant");
        req.setExtractionMap(em);

        SmsPattern result = service.updatePattern("p1", "u1", req);

        assertThat(result.getTemplate()).isEqualTo("Rs.{amount} debited at {merchant}");
    }

    @Test
    void updatePattern_otherFamilyMember_forbidden() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyMemberRepository.findByUserIdAndFamilyGroupId("u2", "fam-1"))
                .thenReturn(Optional.of(member("u2", "fam-1", "MEMBER")));

        UpdatePatternRequest req = new UpdatePatternRequest();
        req.setTemplate("Rs.{amount} debited at {merchant}");

        assertThatThrownBy(() -> service.updatePattern("p1", "u2", req))
                .isInstanceOf(ForbiddenException.class);
    }

    @Test
    void updatePattern_globalPattern_readOnly() {
        SmsPatternDocument doc = familyPattern("p1", null, null, 1);
        doc.setScope(SmsPatternDocument.SCOPE_GLOBAL);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));

        UpdatePatternRequest req = new UpdatePatternRequest();
        req.setTemplate("Rs.{amount} debited at {merchant}");

        assertThatThrownBy(() -> service.updatePattern("p1", "u1", req))
                .isInstanceOf(ForbiddenException.class);
    }

    @Test
    void deletePattern_missingPattern_throws() {
        when(patternRepository.findById("nope")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.deletePattern("nope", "u1"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    // ── promotePattern ───────────────────────────────────────────

    @Test
    void promotePattern_belowThreshold_throws() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyMemberRepository.findByUserIdAndFamilyGroupId("u1", "fam-1"))
                .thenReturn(Optional.of(member("u1", "fam-1", "ADMIN")));

        assertThatThrownBy(() -> service.promotePattern("p1", "u1"))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void promotePattern_adminAboveThreshold_promotesToGlobal() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 5);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyMemberRepository.findByUserIdAndFamilyGroupId("u1", "fam-1"))
                .thenReturn(Optional.of(member("u1", "fam-1", "ADMIN")));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.promotePattern("p1", "u1");

        assertThat(result.getScope()).isEqualTo(PatternScope.GLOBAL);
        assertThat(result.getOwnerFamilyGroupId()).isNull();
    }

    @Test
    void promotePattern_nonAdmin_forbidden() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 5);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyMemberRepository.findByUserIdAndFamilyGroupId("u2", "fam-1"))
                .thenReturn(Optional.of(member("u2", "fam-1", "MEMBER")));

        assertThatThrownBy(() -> service.promotePattern("p1", "u2"))
                .isInstanceOf(ForbiddenException.class);
    }

    // ── Precedence ───────────────────────────────────────────────

    @Test
    void findActiveBySender_familyPatternFirstThenGlobal() {
        SmsPatternDocument global = familyPattern("g1", null, null, 1);
        global.setScope(SmsPatternDocument.SCOPE_GLOBAL);
        global.setUpdatedAt(Instant.parse("2026-01-01T00:00:00Z"));
        SmsPatternDocument family = familyPattern("f1", "fam-1", "u1", 1);
        family.setUpdatedAt(Instant.parse("2026-02-01T00:00:00Z"));

        when(patternRepository.findActiveForSenderAndFamily("HDFCBK", "fam-1"))
                .thenReturn(List.of(global, family));

        List<SmsPatternDocument> result = service.findActiveBySender("HDFCBK", "fam-1");

        assertThat(result).extracting(SmsPatternDocument::getId).containsExactly("f1", "g1");
    }

    @Test
    void findActiveBySender_withinFamily_newestUpdatedAtFirst() {
        SmsPatternDocument older = familyPattern("o1", "fam-1", "u1", 1);
        older.setUpdatedAt(Instant.parse("2026-01-01T00:00:00Z"));
        SmsPatternDocument newer = familyPattern("n1", "fam-1", "u1", 1);
        newer.setUpdatedAt(Instant.parse("2026-03-01T00:00:00Z"));

        when(patternRepository.findActiveForSenderAndFamily("HDFCBK", "fam-1"))
                .thenReturn(List.of(older, newer));

        List<SmsPatternDocument> result = service.findActiveBySender("HDFCBK", "fam-1");

        assertThat(result).extracting(SmsPatternDocument::getId).containsExactly("n1", "o1");
    }

    // ── Family-filtered listing ──────────────────────────────────

    @Test
    void getPatterns_filtersToGlobalPlusCallerFamily() {
        SmsPatternDocument global = familyPattern("g1", null, null, 1);
        global.setScope(SmsPatternDocument.SCOPE_GLOBAL);
        SmsPatternDocument family = familyPattern("f1", "fam-1", "u1", 1);

        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.findActiveGlobalOrFamily("fam-1")).thenReturn(List.of(global, family));

        List<SmsPattern> result = service.getPatterns(null, "u1");

        assertThat(result).hasSize(2);
        verify(patternRepository).findActiveGlobalOrFamily("fam-1");
    }
}