package com.budgetly.api.listener;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.document.ChangeStreamTokenDocument;
import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.llm.LlmAnalysisResult;
import com.budgetly.api.llm.LlmProvider;
import com.budgetly.api.repository.ChangeStreamTokenRepository;
import com.budgetly.api.repository.MessageRepository;
import com.budgetly.api.service.AnchorParserService;
import com.budgetly.api.service.CategoryResolver;
import com.budgetly.api.service.PatternRegistryService;
import com.budgetly.api.service.TransactionDateParser;
import com.budgetly.api.service.TransactionService;
import com.budgetly.api.generated.model.CreateTransactionRequest;
import com.budgetly.api.generated.model.Transaction;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.Metrics;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.bson.BsonDocument;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.mongodb.core.FindAndModifyOptions;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Unit tests for the change-stream processing state machine
 * (PENDING → IN_PROGRESS → CONFIRMED / PROCESSED / IGNORED / FAILED).
 *
 * <p>The listener contract tested here:
 * <ul>
 *   <li>only the caller that wins the atomic PENDING→IN_PROGRESS findAndModify
 *       proceeds (the others short-circuit — no duplicate processing);</li>
 *   <li>non-financial → IGNORED, financial → CONFIRMED (on tx create) or
 *       PROCESSED (on tx-create failure);</li>
 *   <li>exceptions → FAILED + errorMessage;</li>
 *   <li>resume token persisted iff a token was supplied;</li>
 *   <li>metrics budgetly.message.processing.* incremented.</li>
 * </ul>
 */
class MessageChangeStreamListenerTest {

    private MongoTemplate mongoTemplate;
    private MessageRepository messageRepository;
    private ChangeStreamTokenRepository tokenRepository;
    private LlmProvider llmProvider;
    private TransactionService transactionService;
    private PatternRegistryService patternRegistryService;
    private CategoryResolver categoryResolver;

    private MessageChangeStreamListener listener;

    @BeforeEach
    void setUp() {
        // Bare JUnit runs have no back-end mounted on Micrometer's global
        // composite, so counters would silently no-op. Mount one Simple
        // registry (kept across tests) and clear meters for isolation.
        if (Metrics.globalRegistry.getRegistries().isEmpty()) {
            Metrics.globalRegistry.add(new SimpleMeterRegistry());
        }
        Metrics.globalRegistry.clear();

        mongoTemplate = mock(MongoTemplate.class);
        messageRepository = mock(MessageRepository.class);
        tokenRepository = mock(ChangeStreamTokenRepository.class);
        llmProvider = mock(LlmProvider.class);
        transactionService = mock(TransactionService.class);
        patternRegistryService = mock(PatternRegistryService.class);
        categoryResolver = mock(CategoryResolver.class);

        listener = new MessageChangeStreamListener(
                mongoTemplate, messageRepository, tokenRepository,
                llmProvider, transactionService, patternRegistryService,
                new AnchorParserService(), new TransactionDateParser(),
                categoryResolver, "messages", "tokens"
        );
    }

    private MessageDocument pendingDoc() {
        return MessageDocument.builder()
                .id("msg1")
                .messageId("m-1")
                .userId("u1")
                .familyGroupId("fam-1")
                .sender("HDFCBK")
                .rawText("Spent Rs 500 at Grocery Mart on 01/10/2026")
                .status(MessageDocument.STATUS_PENDING)
                .source(MessageDocument.SOURCE_BULK)
                .build();
    }

    private CategoryDocument category(String id, String name) {
        return CategoryDocument.builder().id(id).name(name).build();
    }

    /** Stub the atomic claim so the returned doc represents the state after claim. */
    private void claimIngress(MessageDocument claimed) {
        when(mongoTemplate.findAndModify(
                any(Query.class), any(Update.class), any(FindAndModifyOptions.class), eq(MessageDocument.class)))
                .thenReturn(claimed);
    }

    private Counter counter(String status) {
        return Metrics.globalRegistry
                .find("budgetly.message.processing")
                .tags("status", status)
                .counter();
    }

    // ── State transitions ─────────────────────────────────────────

    @Test
    void ignoredWhenLlmClassifiesNonFinancial() {
        claimIngress(pendingDoc());
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder()
                        .financial(false)
                        .nonFinancialCategory("PROMO")
                        .build());

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        ArgumentCaptor<MessageDocument> captor = ArgumentCaptor.forClass(MessageDocument.class);
        verify(messageRepository).save(captor.capture());
        assertThat(captor.getValue().getStatus()).isEqualTo(MessageDocument.STATUS_IGNORED);
        assertThat(captor.getValue().getNonFinancialCategory()).isEqualTo("PROMO");
        assertThat(captor.getValue().getProcessedAt()).isNotNull();

        // Anchor fast-path consulted the registry (no active pattern) then
        // classified non-financial — no transaction, no new pattern.
        verify(patternRegistryService).findActiveBySender("HDFCBK", "fam-1");
        verify(patternRegistryService, never()).savePattern(any());
        verifyNoInteractions(transactionService);
        assertThat(counter("started").count()).isEqualTo(1.0);
        assertThat(counter("success").count()).isEqualTo(1.0);
    }

    @Test
    void confirmedWhenFinancialAndTransactionCreated() {
        MessageDocument claimed = pendingDoc();
        claimIngress(claimed);
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder()
                        .financial(true)
                        .amount(500.0)
                        .merchant("Grocery Mart")
                        .transactionType("EXPENSE")
                        .template("Spent Rs {amount} at {merchant} on {timestamp}")
                        .extractionMap(Map.of(
                                "amount", "amount", "merchant", "merchant", "timestamp", "timestamp"))
                        .build());
        Transaction tx = new Transaction();
        tx.setId("tx-1");
        when(transactionService.createTransactionInternal(any(), any(), any(), any(), any(), any()))
                .thenReturn(tx);
        when(patternRegistryService.savePattern(any()))
                .thenAnswer(inv -> {
                    SmsPatternDocument p = inv.getArgument(0);
                    p.setId("pat-1");
                    return p;
                });

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        ArgumentCaptor<MessageDocument> captor = ArgumentCaptor.forClass(MessageDocument.class);
        verify(messageRepository).save(captor.capture());
        MessageDocument saved = captor.getValue();
        assertThat(saved.getStatus()).isEqualTo(MessageDocument.STATUS_CONFIRMED);
        assertThat(saved.getLinkedTransactionId()).isEqualTo("tx-1");
        assertThat(saved.getMatchedPatternId()).isEqualTo("pat-1");
        assertThat(saved.getParsedTransactionData())
                .containsEntry("amount", 500.0)
                .containsEntry("merchant", "Grocery Mart");

        // Pattern cached for the sender with usageCount bumped.
        ArgumentCaptor<SmsPatternDocument> patCaptor = ArgumentCaptor.forClass(SmsPatternDocument.class);
        verify(patternRegistryService).savePattern(patCaptor.capture());
        assertThat(patCaptor.getValue().getSender()).isEqualTo("HDFCBK");
        assertThat(patCaptor.getValue().getTemplate()).contains("{amount}");
        assertThat(patCaptor.getValue().getUsageCount()).isEqualTo(1L);
        assertThat(patCaptor.getValue().isActive()).isTrue();

        assertThat(counter("success").count()).isEqualTo(1.0);
    }

    // ── WORK-006: LLM category → transaction categoryId ──────────

    @Test
    void confirmedWhenFinancialAndCategoryResolved() {
        MessageDocument claimed = pendingDoc();
        claimIngress(claimed);
        when(categoryResolver.familyCategories("fam-1"))
                .thenReturn(List.of(category("cat-1", "Groceries")));
        when(categoryResolver.namesForPrompt(anyList())).thenReturn(List.of("Groceries"));
        when(categoryResolver.categoryIdFor(anyList(), eq("Groceries"))).thenReturn("cat-1");
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder()
                        .financial(true)
                        .amount(500.0)
                        .merchant("Grocery Mart")
                        .transactionType("EXPENSE")
                        .category("Groceries")
                        .build());
        Transaction tx = new Transaction();
        tx.setId("tx-1");
        when(transactionService.createTransactionInternal(any(), any(), any(), any(), any(), any()))
                .thenReturn(tx);

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        ArgumentCaptor<CreateTransactionRequest> txCaptor = ArgumentCaptor.forClass(CreateTransactionRequest.class);
        verify(transactionService).createTransactionInternal(
                eq("u1"), eq("fam-1"), txCaptor.capture(), anyString(), anyString(), any());
        assertThat(txCaptor.getValue().getCategoryId()).isEqualTo("cat-1");
    }

    @Test
    void leavesCategoryNullForUncategorizedLlmResult() {
        claimIngress(pendingDoc());
        when(categoryResolver.familyCategories("fam-1"))
                .thenReturn(List.of(category("cat-1", "Groceries")));
        when(categoryResolver.namesForPrompt(anyList())).thenReturn(List.of("Groceries"));
        when(categoryResolver.categoryIdFor(anyList(), eq("uncategorized"))).thenReturn(null);
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder()
                        .financial(true)
                        .amount(500.0)
                        .merchant("Grocery Mart")
                        .transactionType("EXPENSE")
                        .category("uncategorized")
                        .build());
        Transaction tx = new Transaction();
        tx.setId("tx-1");
        when(transactionService.createTransactionInternal(any(), any(), any(), any(), any(), any()))
                .thenReturn(tx);

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        ArgumentCaptor<CreateTransactionRequest> txCaptor = ArgumentCaptor.forClass(CreateTransactionRequest.class);
        verify(transactionService).createTransactionInternal(
                eq("u1"), eq("fam-1"), txCaptor.capture(), anyString(), anyString(), any());
        assertThat(txCaptor.getValue().getCategoryId()).isNull();
    }

    @Test
    void leavesCategoryNullWhenLlmReturnsUnknownCategory() {
        claimIngress(pendingDoc());
        when(categoryResolver.familyCategories("fam-1"))
                .thenReturn(List.of(category("cat-1", "Groceries")));
        when(categoryResolver.namesForPrompt(anyList())).thenReturn(List.of("Groceries"));
        when(categoryResolver.categoryIdFor(anyList(), eq("Mystery"))).thenReturn(null);
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder()
                        .financial(true)
                        .amount(500.0)
                        .merchant("Grocery Mart")
                        .transactionType("EXPENSE")
                        .category("Mystery")
                        .build());
        Transaction tx = new Transaction();
        tx.setId("tx-1");
        when(transactionService.createTransactionInternal(any(), any(), any(), any(), any(), any()))
                .thenReturn(tx);

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        ArgumentCaptor<CreateTransactionRequest> txCaptor = ArgumentCaptor.forClass(CreateTransactionRequest.class);
        verify(transactionService).createTransactionInternal(
                eq("u1"), eq("fam-1"), txCaptor.capture(), anyString(), anyString(), any());
        assertThat(txCaptor.getValue().getCategoryId()).isNull();
    }

    @Test
    void usesDefaultCategoryListWhenFamilyHasNoCategories() {
        claimIngress(pendingDoc());
        when(categoryResolver.familyCategories("fam-1")).thenReturn(List.of());
        when(categoryResolver.namesForPrompt(anyList())).thenReturn(CategoryResolver.DEFAULT_CATEGORIES);
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder().financial(false).build());

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<String>> captor = ArgumentCaptor.forClass(List.class);
        verify(llmProvider).analyzeMessage(eq("HDFCBK"), anyString(), captor.capture());
        assertThat(captor.getValue()).isEqualTo(CategoryResolver.DEFAULT_CATEGORIES);
    }

    @Test
    void exposesChangeStreamLagAfterSuccessfulProcessing() {
        // Simulate a message that was bulk-inserted 60s before now and only
        // now finalized — the lag gauge should report that ~60s wait.
        Instant createdAt = Instant.now().minusSeconds(60);
        MessageDocument claimed = pendingDoc();
        claimed.setCreatedAt(createdAt);
        claimIngress(claimed);
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder().financial(false).build());

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        verify(messageRepository).save(any());

        Gauge lag = Metrics.globalRegistry
                .find("budgetly.message.change-stream.lag.milliseconds").gauge();
        assertThat(lag).isNotNull();
        assertThat(lag.value()).isBetween(
                (double) Duration.ofSeconds(30).toMillis(),
                (double) Duration.ofSeconds(90).toMillis());
    }

    @Test
    void processedWhenFinancialButTransactionCreationFails() {
        claimIngress(pendingDoc());
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder()
                        .financial(true).amount(500.0).merchant("Grocery Mart").build());
        when(transactionService.createTransactionInternal(any(), any(), any(), any(), any(), any()))
                .thenThrow(new RuntimeException("membership check failed"));

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        ArgumentCaptor<MessageDocument> captor = ArgumentCaptor.forClass(MessageDocument.class);
        verify(messageRepository).save(captor.capture());
        MessageDocument saved = captor.getValue();
        assertThat(saved.getStatus()).isEqualTo(MessageDocument.STATUS_PROCESSED);
        assertThat(saved.getLinkedTransactionId()).isNull();

        assertThat(counter("success").count()).isEqualTo(1.0);
    }

    @Test
    void failedWhenLlmThrows() {
        claimIngress(pendingDoc());
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenThrow(new RuntimeException("LLM outage"));

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        ArgumentCaptor<MessageDocument> captor = ArgumentCaptor.forClass(MessageDocument.class);
        verify(messageRepository).save(captor.capture());
        assertThat(captor.getValue().getStatus()).isEqualTo(MessageDocument.STATUS_FAILED);
        assertThat(captor.getValue().getErrorMessage()).contains("LLM outage");

        verify(patternRegistryService).findActiveBySender("HDFCBK", "fam-1");
        verify(patternRegistryService, never()).savePattern(any());
        verifyNoInteractions(transactionService);
        verify(tokenRepository, never()).save(any());
        assertThat(counter("failed").count()).isEqualTo(1.0);
        assertThat(counter("success")).isNull();
    }

    @Test
    void shortCircuitsWhenAtomicClaimIsLost() {
        // findAndModify matched no PENDING doc → someone else is processing it.
        claimIngress(null);

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        verifyNoInteractions(llmProvider, transactionService, patternRegistryService, tokenRepository);
        verify(messageRepository, never()).save(any());
    }

    @Test
    void skipsDirectSourceDocumentsBeforeClaiming() {
        // Legacy /messages/process docs are DIRECT — the listener must never
        // claim them (WORK-001 duplicate-processing race).
        MessageDocument direct = MessageDocument.builder()
                .id("msg9").userId("u1").sender("HDFCBK")
                .rawText("Spent Rs 500 at Grocery Mart on 01/10/2026")
                .status(MessageDocument.STATUS_PENDING)
                .source(MessageDocument.SOURCE_DIRECT)
                .build();

        listener.processEventInternal(direct, new BsonDocument());

        verify(mongoTemplate, never()).findAndModify(
                any(Query.class), any(Update.class), any(FindAndModifyOptions.class), eq(MessageDocument.class));
        verifyNoInteractions(llmProvider, transactionService, patternRegistryService, tokenRepository);
        verify(messageRepository, never()).save(any());
    }

    // ── WORK-002: server-side anchor match skips the LLM ─────────

    private SmsPatternDocument patternDoc(String template, Map<String, String> extractionMap) {
        return SmsPatternDocument.builder()
                .id("pat-anchor")
                .sender("HDFCBK")
                .template(template)
                .extractionMap(extractionMap)
                .usageCount(3)
                .active(true)
                .build();
    }

    @Test
    void anchorMatchProcessesWithoutLlmAndUsesTimestampAsTransactionDate() {
        claimIngress(pendingDoc());
        when(patternRegistryService.findActiveBySender("HDFCBK", "fam-1")).thenReturn(List.of(
                patternDoc("Spent Rs {amount} at {merchant} on {timestamp}",
                        Map.of("amount", "amount", "merchant", "merchant", "timestamp", "timestamp"))));
        when(patternRegistryService.savePattern(any()))
                .thenAnswer(inv -> inv.getArgument(0));
        Transaction tx = new Transaction();
        tx.setId("tx-anchor");
        when(transactionService.createTransactionInternal(any(), any(), any(), any(), any(), any()))
                .thenReturn(tx);

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        // The LLM must never be reached for a fully-anchored known template.
        verify(llmProvider, never()).analyzeMessage(any(), any(), any());

        // Transaction created from the anchor fields → REGEX_LOCAL. With no
        // receivedAt, the SMS body's date (01/10/2026) is used; it carries no
        // offset, so it is interpreted as Indian local time (Asia/Kolkata,
        // UTC+05:30) → 2026-09-30T18:30:00Z (WORK-003 / timezone fix).
        var txCaptor = ArgumentCaptor.forClass(CreateTransactionRequest.class);
        var sourceCaptor = ArgumentCaptor.forClass(String.class);
        verify(transactionService).createTransactionInternal(
                eq("u1"), eq("fam-1"), txCaptor.capture(), sourceCaptor.capture(), any(), eq("pat-anchor"));
        assertThat(sourceCaptor.getValue()).isEqualTo("REGEX_LOCAL");
        assertThat(txCaptor.getValue().getAmount()).isEqualTo(500.0);
        assertThat(txCaptor.getValue().getTransactionDate().toInstant())
                .isEqualTo(java.time.LocalDate.of(2026, 10, 1).atStartOfDay(
                        java.time.ZoneId.of("Asia/Kolkata")).toInstant());

        // Pattern usage bumped through the registry (3 → 4).
        ArgumentCaptor<SmsPatternDocument> patCaptor = ArgumentCaptor.forClass(SmsPatternDocument.class);
        verify(patternRegistryService).savePattern(patCaptor.capture());
        assertThat(patCaptor.getValue().getUsageCount()).isEqualTo(4L);

        ArgumentCaptor<MessageDocument> msgCaptor = ArgumentCaptor.forClass(MessageDocument.class);
        verify(messageRepository).save(msgCaptor.capture());
        assertThat(msgCaptor.getValue().getStatus()).isEqualTo(MessageDocument.STATUS_CONFIRMED);
        assertThat(msgCaptor.getValue().getParseSource()).isEqualTo("REGEX_LOCAL");
        assertThat(msgCaptor.getValue().getLinkedTransactionId()).isEqualTo("tx-anchor");
        assertThat(msgCaptor.getValue().getParsedTransactionData())
                .containsEntry("amount", 500.0)
                .containsEntry("merchant", "Grocery Mart");

        assertThat(Metrics.globalRegistry.find("budgetly.message.pattern.cache-hit").counter().count())
                .isEqualTo(1.0);
        assertThat(counter("success").count()).isEqualTo(1.0);
    }

    @Test
    void anchorMatchIncompleteFallsBackToLlm() {
        claimIngress(pendingDoc());
        // Template anchors match but only {amount} is present in the template:
        // no merchant/timestamp → treated as incomplete, like the app does.
        when(patternRegistryService.findActiveBySender("HDFCBK", "fam-1")).thenReturn(List.of(
                patternDoc("Rs.{amount} debited", Map.of("amount", "amount"))));
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder().financial(false).build());

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        verify(llmProvider).analyzeMessage(
                        eq("HDFCBK"), eq("Spent Rs 500 at Grocery Mart on 01/10/2026"), anyList());
        verify(transactionService, never()).createTransactionInternal(any(), any(), any(), any(), any(), any());
        assertThat(Metrics.globalRegistry.find("budgetly.message.pattern.cache-hit").counter()).isNull();
    }

    @Test
    void noRegisteredPatternFallsBackToLlm() {
        claimIngress(pendingDoc());
        when(patternRegistryService.findActiveBySender("HDFCBK", "fam-1")).thenReturn(List.of());
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder().financial(false).build());

        listener.processEventInternal(pendingDoc(), new BsonDocument());

        verify(llmProvider).analyzeMessage(eq("HDFCBK"), anyString(), anyList());
        verify(transactionService, never()).createTransactionInternal(any(), any(), any(), any(), any(), any());
    }

    // ── Resume token persistence ──────────────────────────────────

    @Test
    void persistsResumeTokenWhenProvided() {
        claimIngress(pendingDoc());
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder().financial(false).build());
        BsonDocument token = BsonDocument.parse("{ \"token\": 123 }");

        listener.processEventInternal(pendingDoc(), token);

        ArgumentCaptor<ChangeStreamTokenDocument> captor =
                ArgumentCaptor.forClass(ChangeStreamTokenDocument.class);
        verify(tokenRepository).save(captor.capture());
        ChangeStreamTokenDocument saved = captor.getValue();
        assertThat(saved.getId()).isEqualTo("message-processor");
        assertThat(BsonDocument.parse(saved.getToken())).isEqualTo(token);
    }

    @Test
    void doesNotPersistTokenWhenNoneInChangeStreamEvent() {
        claimIngress(pendingDoc());
        when(llmProvider.analyzeMessage(any(), any(), any()))
                .thenReturn(LlmAnalysisResult.builder().financial(false).build());

        listener.processEventInternal(pendingDoc(), null);

        verify(tokenRepository, never()).save(any());
    }

    // ── Lifecycle ─────────────────────────────────────────────────

    @Test
    void stopItsContainerWhenRunning() {
        // Not started → nothing registered yet → stop() must be a no-op, not an NPE.
        listener.stop();
        assertThat(listener.isRunning()).isFalse();
    }
}