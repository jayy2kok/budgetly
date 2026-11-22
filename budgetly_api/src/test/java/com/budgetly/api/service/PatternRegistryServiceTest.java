package com.budgetly.api.service;

import com.budgetly.api.document.FamilyMemberDocument;
import com.budgetly.api.document.HiddenPatternDocument;
import com.budgetly.api.document.RejectedPatternDocument;
import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.exception.ForbiddenException;
import com.budgetly.api.generated.model.CreatePatternRequest;
import com.budgetly.api.generated.model.ExtractionMap;
import com.budgetly.api.generated.model.FamilyGroup;
import com.budgetly.api.generated.model.PatternReportRequest;
import com.budgetly.api.generated.model.PatternScope;
import com.budgetly.api.generated.model.PatternSource;
import com.budgetly.api.generated.model.SmsPattern;
import com.budgetly.api.generated.model.UpdatePatternRequest;
import com.budgetly.api.repository.FamilyMemberRepository;
import com.budgetly.api.repository.HiddenPatternRepository;
import com.budgetly.api.repository.PatternRegistryRepository;
import com.budgetly.api.repository.RejectedPatternRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import com.mongodb.client.result.UpdateResult;
import org.springframework.data.mongodb.core.FindAndModifyOptions;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class PatternRegistryServiceTest {

    private static final String SENDER = "HDFCBK";
    private static final String TEMPLATE = "Rs.{amount} debited for {merchant}";
    private static final String SAMPLE = "Rs.500 debited for Amazon";

    private PatternRegistryRepository patternRepository;
    private HiddenPatternRepository hiddenPatternRepository;
    private RejectedPatternRepository rejectedPatternRepository;
    private FamilyGroupService familyGroupService;
    private FamilyMemberRepository familyMemberRepository;
    private MongoTemplate mongoTemplate;
    private PatternRegistryService service;

    @BeforeEach
    void setUp() {
        patternRepository = mock(PatternRegistryRepository.class);
        hiddenPatternRepository = mock(HiddenPatternRepository.class);
        rejectedPatternRepository = mock(RejectedPatternRepository.class);
        familyGroupService = mock(FamilyGroupService.class);
        familyMemberRepository = mock(FamilyMemberRepository.class);
        mongoTemplate = mock(MongoTemplate.class);
        service = new PatternRegistryService(patternRepository, hiddenPatternRepository,
                rejectedPatternRepository, familyGroupService, familyMemberRepository,
                new AnchorParserService(), mongoTemplate);
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
                .sender(SENDER)
                .template(TEMPLATE)
                .sampleMessage(SAMPLE)
                .extractionMap(Map.of("amount", "amount", "merchant", "merchant"))
                .usageCount(usageCount)
                .active(true)
                .scope(SmsPatternDocument.SCOPE_FAMILY)
                .ownerFamilyGroupId(familyGroupId)
                .createdByUserId(createdByUserId)
                .source(SmsPatternDocument.SOURCE_USER)
                .build();
    }

    private SmsPatternDocument globalPattern(String id) {
        return SmsPatternDocument.builder()
                .id(id)
                .sender(SENDER)
                .template(TEMPLATE)
                .sampleMessage(SAMPLE)
                .extractionMap(Map.of("amount", "amount", "merchant", "merchant"))
                .usageCount(5)
                .active(true)
                .scope(SmsPatternDocument.SCOPE_GLOBAL)
                .source(SmsPatternDocument.SOURCE_LLM)
                .build();
    }

    private CreatePatternRequest createRequest(String template, String sampleMessage, String amountGroup) {
        CreatePatternRequest req = new CreatePatternRequest();
        req.setSender(SENDER);
        req.setTemplate(template);
        req.setSampleMessage(sampleMessage);
        if (amountGroup != null) {
            ExtractionMap em = new ExtractionMap();
            em.setAmount(amountGroup);
            req.setExtractionMap(em);
        }
        return req;
    }

    private UpdatePatternRequest updateRequest(String template, String sampleMessage) {
        UpdatePatternRequest req = new UpdatePatternRequest();
        req.setTemplate(template);
        req.setSampleMessage(sampleMessage);
        ExtractionMap em = new ExtractionMap();
        em.setAmount("amount");
        em.setMerchant("merchant");
        req.setExtractionMap(em);
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
        when(patternRepository.save(any(SmsPatternDocument.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.createPattern("u1", createRequest(TEMPLATE, SAMPLE, "amount"));

        assertThat(result.getScope()).isEqualTo(PatternScope.FAMILY);
        assertThat(result.getSource()).isEqualTo(PatternSource.USER);
        assertThat(result.getOwnerFamilyGroupId()).isEqualTo("fam-1");
        assertThat(result.getCreatedByUserId()).isEqualTo("u1");
        assertThat(result.getUpdatedAt()).isNotNull();
    }

    @Test
    void createPattern_templateDoesNotMatchSample_throws() {
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));

        assertThatThrownBy(() -> service.createPattern("u1",
                createRequest("Hello {amount} world", SAMPLE, "amount")))
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
    void createPattern_duplicateActiveFamilyTemplate_throws() {
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.findByOwnerFamilyGroupIdAndSenderAndTemplate("fam-1", SENDER, TEMPLATE))
                .thenReturn(List.of(familyPattern("p1", "fam-1", "u1", 1)));

        assertThatThrownBy(() -> service.createPattern("u1", createRequest(TEMPLATE, SAMPLE, "amount")))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void createPattern_globalTemplateDoesNotBlock() {
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.createPattern("u1", createRequest(TEMPLATE, SAMPLE, "amount"));

        assertThat(result.getScope()).isEqualTo(PatternScope.FAMILY);
    }

    @Test
    void createPattern_reactivatesInactiveFamilyTemplate() {
        SmsPatternDocument inactive = familyPattern("p-old", "fam-1", "u1", 4);
        inactive.setActive(false);
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.findByOwnerFamilyGroupIdAndSenderAndTemplate("fam-1", SENDER, TEMPLATE))
                .thenReturn(List.of(inactive));
        when(patternRepository.save(any(SmsPatternDocument.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.createPattern("u1", createRequest(TEMPLATE, SAMPLE, "amount"));

        assertThat(result.getId()).isEqualTo("p-old");
        assertThat(result.getActive()).isTrue();
        verify(patternRepository, never()).insert(any(SmsPatternDocument.class));
    }

    @Test
    void createPattern_withFixedValues_persistsThem() {
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        CreatePatternRequest req = createRequest("Rs.{amount} debited", "Rs.500 debited", "amount");
        req.setFixedValues(Map.of(
                "merchant", " Pan Shop ",
                "accountLast4", "1234",
                "bankName", "HDFC Bank",
                "notes", "Rent"));

        SmsPattern result = service.createPattern("u1", req);

        assertThat(result.getFixedValues())
                .containsEntry("merchant", "Pan Shop")
                .containsEntry("accountLast4", "1234")
                .containsEntry("bankName", "HDFC Bank")
                .containsEntry("notes", "Rent");
    }

    @Test
    void createPattern_fixedValueForAmount_throws() {
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));

        CreatePatternRequest req = createRequest("Rs.{amount} debited", "Rs.500 debited", "amount");
        req.setFixedValues(Map.of("amount", "500"));

        assertThatThrownBy(() -> service.createPattern("u1", req))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("amount");
    }

    // ── updatePattern: FAMILY in place ───────────────────────────

    @Test
    void updatePattern_authorAllowed_updatesTemplate() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.updatePattern("p1", "u1",
                updateRequest("Rs.{amount} debited at {merchant}", "Rs.500 debited at Amazon"));

        assertThat(result.getTemplate()).isEqualTo("Rs.{amount} debited at {merchant}");
        assertThat(result.getId()).isEqualTo("p1");
    }

    @Test
    void updatePattern_omittedFixedValues_keepsStoredValues() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        doc.setFixedValues(Map.of("merchant", "Pan Shop"));
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.updatePattern("p1", "u1",
                updateRequest("Rs.{amount} debited at {merchant}", "Rs.500 debited at Amazon"));

        assertThat(result.getFixedValues()).containsEntry("merchant", "Pan Shop");
    }

    @Test
    void updatePattern_nullFixedValues_clearsThem() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        doc.setFixedValues(Map.of("merchant", "Pan Shop"));
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        UpdatePatternRequest req = updateRequest("Rs.{amount} debited at {merchant}", "Rs.500 debited at Amazon");
        req.setFixedValues(null);

        SmsPattern result = service.updatePattern("p1", "u1", req);

        assertThat(result.getFixedValues()).isEmpty();
    }

    @Test
    void updatePattern_nonEmptyFixedValues_replacesThem() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        doc.setFixedValues(Map.of("merchant", "Pan Shop"));
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        UpdatePatternRequest req = updateRequest("Rs.{amount} debited at {merchant}", "Rs.500 debited at Amazon");
        req.setFixedValues(Map.of("accountLast4", "1234"));

        SmsPattern result = service.updatePattern("p1", "u1", req);

        assertThat(result.getFixedValues())
                .containsOnlyKeys("accountLast4")
                .containsEntry("accountLast4", "1234");
    }

    @Test
    void updatePattern_otherFamilyMember_forbidden() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyMemberRepository.findByUserIdAndFamilyGroupId("u2", "fam-1"))
                .thenReturn(Optional.of(member("u2", "fam-1", "MEMBER")));

        assertThatThrownBy(() -> service.updatePattern("p1", "u2",
                updateRequest("Rs.{amount} debited at {merchant}", "Rs.500 debited at Amazon")))
                .isInstanceOf(ForbiddenException.class);
    }

    // ── updatePattern: GLOBAL → family copy + hide ───────────────

    @Test
    void updatePattern_global_createsFamilyCopyAndHidesGlobal() {
        SmsPatternDocument global = globalPattern("g1");
        when(patternRepository.findById("g1")).thenReturn(Optional.of(global));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.updatePattern("g1", "u1",
                updateRequest("Rs.{amount} debited at {merchant}", "Rs.500 debited at Amazon"));

        assertThat(result.getScope()).isEqualTo(PatternScope.FAMILY);
        assertThat(result.getOwnerFamilyGroupId()).isEqualTo("fam-1");
        assertThat(result.getTemplate()).isEqualTo("Rs.{amount} debited at {merchant}");
        // The shared global must not be mutated.
        assertThat(global.getTemplate()).isEqualTo(TEMPLATE);
        assertThat(global.getScope()).isEqualTo(SmsPatternDocument.SCOPE_GLOBAL);

        ArgumentCaptor<HiddenPatternDocument> hidden = ArgumentCaptor.forClass(HiddenPatternDocument.class);
        verify(hiddenPatternRepository).save(hidden.capture());
        assertThat(hidden.getValue().getFamilyGroupId()).isEqualTo("fam-1");
        assertThat(hidden.getValue().getPatternId()).isEqualTo("g1");
    }

    @Test
    void updatePattern_globalTwice_updatesTheSameFamilyCopy() {
        SmsPatternDocument global = globalPattern("g1");
        SmsPatternDocument existingCopy = familyPattern("c1", "fam-1", "u1", 2);
        existingCopy.setDerivedFromPatternId("g1");
        when(patternRepository.findById("g1")).thenReturn(Optional.of(global));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.findByOwnerFamilyGroupIdAndDerivedFromPatternId("fam-1", "g1"))
                .thenReturn(Optional.of(existingCopy));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.updatePattern("g1", "u1",
                updateRequest("Rs.{amount} debited at {merchant}", "Rs.500 debited at Amazon"));

        assertThat(result.getId()).isEqualTo("c1");
        assertThat(existingCopy.getTemplate()).isEqualTo("Rs.{amount} debited at {merchant}");
        // Only the copy is written; no second copy is inserted.
        verify(patternRepository, times(1)).save(any(SmsPatternDocument.class));
    }

    // ── disable / enable ─────────────────────────────────────────

    @Test
    void disablePattern_global_upsertsHideMarker() {
        when(patternRepository.findById("g1")).thenReturn(Optional.of(globalPattern("g1")));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));

        SmsPattern result = service.disablePattern("g1", "u1");

        assertThat(result.getHiddenForFamily()).isTrue();
        verify(hiddenPatternRepository).save(any(HiddenPatternDocument.class));
        // The global itself stays active for other families.
        verify(patternRepository, never()).save(any(SmsPatternDocument.class));
    }

    @Test
    void disablePattern_global_isIdempotent() {
        when(patternRepository.findById("g1")).thenReturn(Optional.of(globalPattern("g1")));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(hiddenPatternRepository.findByFamilyGroupIdAndPatternId("fam-1", "g1"))
                .thenReturn(Optional.of(HiddenPatternDocument.builder()
                        .familyGroupId("fam-1").patternId("g1").build()));

        service.disablePattern("g1", "u1");

        verify(hiddenPatternRepository, never()).save(any(HiddenPatternDocument.class));
    }

    @Test
    void disablePattern_family_deactivates() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.disablePattern("p1", "u1");

        assertThat(result.getActive()).isFalse();
    }

    @Test
    void enablePattern_global_removesHideMarker() {
        when(patternRepository.findById("g1")).thenReturn(Optional.of(globalPattern("g1")));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));

        SmsPattern result = service.enablePattern("g1", "u1");

        assertThat(result.getHiddenForFamily()).isFalse();
        verify(hiddenPatternRepository).deleteByFamilyGroupIdAndPatternId("fam-1", "g1");
    }

    @Test
    void enablePattern_family_collisionThrows() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        doc.setActive(false);
        SmsPatternDocument other = familyPattern("p2", "fam-1", "u1", 1);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(patternRepository.findByOwnerFamilyGroupIdAndSenderAndTemplate("fam-1", SENDER, TEMPLATE))
                .thenReturn(List.of(doc, other));

        assertThatThrownBy(() -> service.enablePattern("p1", "u1"))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void enablePattern_family_reactivates() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        doc.setActive(false);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(patternRepository.findByOwnerFamilyGroupIdAndSenderAndTemplate("fam-1", SENDER, TEMPLATE))
                .thenReturn(List.of(doc));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.enablePattern("p1", "u1");

        assertThat(result.getActive()).isTrue();
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
    void promotePattern_clearsFamilyFixedValues() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 5);
        doc.setFixedValues(Map.of("merchant", "Pan Shop"));
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyMemberRepository.findByUserIdAndFamilyGroupId("u1", "fam-1"))
                .thenReturn(Optional.of(member("u1", "fam-1", "ADMIN")));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.promotePattern("p1", "u1");

        assertThat(result.getFixedValues()).isEmpty();
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

    // ── Precedence and hiding ────────────────────────────────────

    @Test
    void findActiveBySender_familyPatternFirstThenGlobal() {
        SmsPatternDocument global = globalPattern("g1");
        global.setUpdatedAt(Instant.parse("2026-01-01T00:00:00Z"));
        SmsPatternDocument family = familyPattern("f1", "fam-1", "u1", 1);
        family.setUpdatedAt(Instant.parse("2026-02-01T00:00:00Z"));

        when(patternRepository.findActiveForSenderAndFamily(SENDER, "fam-1"))
                .thenReturn(List.of(global, family));

        List<SmsPatternDocument> result = service.findActiveBySender(SENDER, "fam-1");

        assertThat(result).extracting(SmsPatternDocument::getId).containsExactly("f1", "g1");
    }

    @Test
    void findActiveBySender_withinFamily_newestUpdatedAtFirst() {
        SmsPatternDocument older = familyPattern("o1", "fam-1", "u1", 1);
        older.setUpdatedAt(Instant.parse("2026-01-01T00:00:00Z"));
        SmsPatternDocument newer = familyPattern("n1", "fam-1", "u1", 1);
        newer.setUpdatedAt(Instant.parse("2026-03-01T00:00:00Z"));

        when(patternRepository.findActiveForSenderAndFamily(SENDER, "fam-1"))
                .thenReturn(List.of(older, newer));

        List<SmsPatternDocument> result = service.findActiveBySender(SENDER, "fam-1");

        assertThat(result).extracting(SmsPatternDocument::getId).containsExactly("n1", "o1");
    }

    @Test
    void findActiveBySender_excludesGlobalsHiddenForTheFamily() {
        SmsPatternDocument global = globalPattern("g1");
        global.setUpdatedAt(Instant.parse("2026-01-01T00:00:00Z"));
        SmsPatternDocument family = familyPattern("f1", "fam-1", "u1", 1);
        family.setUpdatedAt(Instant.parse("2026-02-01T00:00:00Z"));

        when(patternRepository.findActiveForSenderAndFamily(SENDER, "fam-1"))
                .thenReturn(List.of(global, family));
        when(hiddenPatternRepository.findByFamilyGroupId("fam-1"))
                .thenReturn(List.of(HiddenPatternDocument.builder()
                        .familyGroupId("fam-1").patternId("g1").build()));

        List<SmsPatternDocument> result = service.findActiveBySender(SENDER, "fam-1");

        assertThat(result).extracting(SmsPatternDocument::getId).containsExactly("f1");
    }

    @Test
    void findActiveBySender_withoutFamily_returnsGlobalsOnly() {
        SmsPatternDocument global = globalPattern("g1");
        SmsPatternDocument family = familyPattern("f1", "fam-1", "u1", 1);
        when(patternRepository.findBySenderAndActiveTrue(SENDER)).thenReturn(List.of(global, family));

        List<SmsPatternDocument> result = service.findActiveBySender(SENDER, null);

        assertThat(result).extracting(SmsPatternDocument::getId).containsExactly("g1");
    }

    // ── Registry listing ─────────────────────────────────────────

    @Test
    void getPatterns_returnsVisiblePatternsAndMarksHiddenGlobals() {
        SmsPatternDocument global = globalPattern("g1");
        SmsPatternDocument family = familyPattern("f1", "fam-1", "u1", 1);
        SmsPatternDocument disabled = familyPattern("f2", "fam-1", "u1", 1);
        disabled.setActive(false);

        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.findVisibleForFamily("fam-1")).thenReturn(List.of(global, family, disabled));
        when(hiddenPatternRepository.findByFamilyGroupId("fam-1"))
                .thenReturn(List.of(HiddenPatternDocument.builder()
                        .familyGroupId("fam-1").patternId("g1").build()));

        List<SmsPattern> result = service.getPatterns(null, "u1");

        assertThat(result).hasSize(3);
        assertThat(result.stream().filter(SmsPattern::getHiddenForFamily).map(SmsPattern::getId))
                .containsExactly("g1");
        assertThat(result.stream().filter(p -> !p.getActive()).map(SmsPattern::getId))
                .containsExactly("f2");
    }

    @Test
    void getPatternSenders_countsOnlyMatchablePatterns() {
        SmsPatternDocument global = globalPattern("g1");
        SmsPatternDocument hiddenGlobal = globalPattern("g2");
        hiddenGlobal.setSender("SBIUPI");
        SmsPatternDocument disabled = familyPattern("f1", "fam-1", "u1", 1);
        disabled.setActive(false);

        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.findVisibleForFamily("fam-1")).thenReturn(List.of(global, hiddenGlobal, disabled));
        when(hiddenPatternRepository.findByFamilyGroupId("fam-1"))
                .thenReturn(List.of(HiddenPatternDocument.builder()
                        .familyGroupId("fam-1").patternId("g2").build()));

        List<Map<String, Object>> senders = service.getPatternSenders("u1");

        assertThat(senders).hasSize(1);
        assertThat(senders.get(0)).containsEntry("sender", SENDER).containsEntry("patternCount", 1);
    }

    // ── updatePatternCategory ────────────────────────────────────

    @Test
    void updatePatternCategory_familyAuthor_setsCategory() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.updatePatternCategory("p1", "u1", " Food ");

        assertThat(result.getCategoryName()).isEqualTo("Food");
        assertThat(doc.getCategoryName()).isEqualTo("Food");
    }

    @Test
    void updatePatternCategory_familyBlank_clearsCategory() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        doc.setCategoryName("Food");
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.updatePatternCategory("p1", "u1", "  ");

        assertThat(result.getCategoryName()).isNull();
    }

    @Test
    void updatePatternCategory_familyNonAuthor_forbidden() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyGroupService.getMyFamily("u2")).thenReturn(family("fam-1"));
        when(familyMemberRepository.findByUserIdAndFamilyGroupId("u2", "fam-1"))
                .thenReturn(Optional.of(member("u2", "fam-1", "MEMBER")));

        assertThatThrownBy(() -> service.updatePatternCategory("p1", "u2", "Food"))
                .isInstanceOf(ForbiddenException.class);
    }

    @Test
    void updatePatternCategory_global_copiesCategoryToFamilyCopy() {
        SmsPatternDocument global = globalPattern("g1");
        when(patternRepository.findById("g1")).thenReturn(Optional.of(global));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.updatePatternCategory("g1", "u1", "Travel");

        assertThat(result.getScope()).isEqualTo(PatternScope.FAMILY);
        assertThat(result.getCategoryName()).isEqualTo("Travel");
        // The shared global keeps its own (empty) category.
        assertThat(global.getCategoryName()).isNull();
        ArgumentCaptor<HiddenPatternDocument> hidden = ArgumentCaptor.forClass(HiddenPatternDocument.class);
        verify(hiddenPatternRepository).save(hidden.capture());
        assertThat(hidden.getValue().getPatternId()).isEqualTo("g1");
    }

    @Test
    void updatePatternCategory_globalBlank_clearsFamilyCopyCategory() {
        SmsPatternDocument global = globalPattern("g1");
        when(patternRepository.findById("g1")).thenReturn(Optional.of(global));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.updatePatternCategory("g1", "u1", null);

        assertThat(result.getCategoryName()).isNull();
        assertThat(global.getCategoryName()).isNull();
    }

    // ── reportPattern ────────────────────────────────────────────

    private UpdateResult modifiedCount(long count) {
        UpdateResult result = mock(UpdateResult.class);
        when(result.getModifiedCount()).thenReturn(count);
        return result;
    }

    @Test
    void reportPattern_duplicateReporter_noOp() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        doc.setReportCount(2);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        UpdateResult noOp = modifiedCount(0);
        when(mongoTemplate.updateFirst(any(), any(), eq(SmsPatternDocument.class))).thenReturn(noOp);

        Map<String, Object> result = service.reportPattern("p1", "u1", new PatternReportRequest());

        assertThat(result).containsEntry("removed", false).containsEntry("reportCount", 2);
        // No increment, no save, no hide marker for a no-op report.
        verify(mongoTemplate, never()).findAndModify(any(), any(), any(FindAndModifyOptions.class),
                eq(SmsPatternDocument.class));
        verify(patternRepository, never()).save(any(SmsPatternDocument.class));
    }

    @Test
    void reportPattern_newReporter_removesAtThreshold() {
        ReflectionTestUtils.setField(service, "reportThreshold", 2);
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 1);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        UpdateResult added = modifiedCount(1);
        when(mongoTemplate.updateFirst(any(), any(), eq(SmsPatternDocument.class))).thenReturn(added);
        SmsPatternDocument incremented = familyPattern("p1", "fam-1", "u1", 1);
        incremented.setReportCount(2);
        when(mongoTemplate.findAndModify(any(), any(), any(FindAndModifyOptions.class),
                eq(SmsPatternDocument.class))).thenReturn(incremented);
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));
        when(rejectedPatternRepository.save(any(RejectedPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        Map<String, Object> result = service.reportPattern("p1", "u1", new PatternReportRequest());

        assertThat(result).containsEntry("removed", true).containsEntry("reportCount", 2);
        assertThat(doc.isActive()).isFalse();
        verify(rejectedPatternRepository).save(any(RejectedPatternDocument.class));
    }

    @Test
    void reportPattern_globalRemoval_hidesForFamily() {
        ReflectionTestUtils.setField(service, "reportThreshold", 2);
        SmsPatternDocument doc = globalPattern("g1");
        when(patternRepository.findById("g1")).thenReturn(Optional.of(doc));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        UpdateResult added = modifiedCount(1);
        when(mongoTemplate.updateFirst(any(), any(), eq(SmsPatternDocument.class))).thenReturn(added);
        SmsPatternDocument incremented = globalPattern("g1");
        incremented.setReportCount(2);
        when(mongoTemplate.findAndModify(any(), any(), any(FindAndModifyOptions.class),
                eq(SmsPatternDocument.class))).thenReturn(incremented);
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        service.reportPattern("g1", "u1", new PatternReportRequest());

        ArgumentCaptor<HiddenPatternDocument> hidden = ArgumentCaptor.forClass(HiddenPatternDocument.class);
        verify(hiddenPatternRepository).save(hidden.capture());
        assertThat(hidden.getValue().getFamilyGroupId()).isEqualTo("fam-1");
        assertThat(hidden.getValue().getPatternId()).isEqualTo("g1");
    }

    // ── enablePattern: copy-on-write ─────────────────────────────

    @Test
    void enablePattern_global_deactivatesFamilyCopy() {
        SmsPatternDocument global = globalPattern("g1");
        SmsPatternDocument copy = familyPattern("c1", "fam-1", "u1", 2);
        copy.setDerivedFromPatternId("g1");
        when(patternRepository.findById("g1")).thenReturn(Optional.of(global));
        when(familyGroupService.getMyFamily("u1")).thenReturn(family("fam-1"));
        when(patternRepository.findByOwnerFamilyGroupIdAndDerivedFromPatternId("fam-1", "g1"))
                .thenReturn(Optional.of(copy));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.enablePattern("g1", "u1");

        assertThat(result.getHiddenForFamily()).isFalse();
        verify(hiddenPatternRepository).deleteByFamilyGroupIdAndPatternId("fam-1", "g1");
        // The copy must not keep shadowing the re-enabled global.
        ArgumentCaptor<SmsPatternDocument> saved = ArgumentCaptor.forClass(SmsPatternDocument.class);
        verify(patternRepository).save(saved.capture());
        assertThat(saved.getValue().getId()).isEqualTo("c1");
        assertThat(saved.getValue().isActive()).isFalse();
    }

    // ── promotePattern: global duplicate + derived cleanup ───────

    @Test
    void promotePattern_activeGlobalDuplicate_throws() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 5);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyMemberRepository.findByUserIdAndFamilyGroupId("u1", "fam-1"))
                .thenReturn(Optional.of(member("u1", "fam-1", "ADMIN")));
        when(patternRepository.findBySenderAndTemplateAndScope(SENDER, TEMPLATE, "GLOBAL"))
                .thenReturn(List.of(globalPattern("g9")));

        assertThatThrownBy(() -> service.promotePattern("p1", "u1"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("global");
        verify(patternRepository, never()).save(any(SmsPatternDocument.class));
    }

    @Test
    void promotePattern_inactiveGlobalDuplicate_allowed() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 5);
        SmsPatternDocument inactiveGlobal = globalPattern("g9");
        inactiveGlobal.setActive(false);
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyMemberRepository.findByUserIdAndFamilyGroupId("u1", "fam-1"))
                .thenReturn(Optional.of(member("u1", "fam-1", "ADMIN")));
        when(patternRepository.findBySenderAndTemplateAndScope(SENDER, TEMPLATE, "GLOBAL"))
                .thenReturn(List.of(inactiveGlobal));
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        SmsPattern result = service.promotePattern("p1", "u1");

        assertThat(result.getScope()).isEqualTo(PatternScope.GLOBAL);
    }

    @Test
    void promotePattern_clearsDerivedFromPatternId() {
        SmsPatternDocument doc = familyPattern("p1", "fam-1", "u1", 5);
        doc.setDerivedFromPatternId("g1");
        when(patternRepository.findById("p1")).thenReturn(Optional.of(doc));
        when(familyMemberRepository.findByUserIdAndFamilyGroupId("u1", "fam-1"))
                .thenReturn(Optional.of(member("u1", "fam-1", "ADMIN")));
        when(patternRepository.findBySenderAndTemplateAndScope(SENDER, TEMPLATE, "GLOBAL"))
                .thenReturn(List.of());
        when(patternRepository.save(any(SmsPatternDocument.class))).thenAnswer(inv -> inv.getArgument(0));

        service.promotePattern("p1", "u1");

        ArgumentCaptor<SmsPatternDocument> saved = ArgumentCaptor.forClass(SmsPatternDocument.class);
        verify(patternRepository).save(saved.capture());
        assertThat(saved.getValue().getDerivedFromPatternId()).isNull();
    }
}