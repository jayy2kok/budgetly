package com.budgetly.api.service;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.llm.LlmAnalysisResult;
import com.budgetly.api.llm.LlmProvider;
import com.budgetly.api.generated.model.BulkMessageItem;
import com.budgetly.api.generated.model.BulkMessageRequest;
import com.budgetly.api.generated.model.BulkMessageResponse;
import com.budgetly.api.generated.model.CreateTransactionRequest;
import com.budgetly.api.generated.model.Message;
import com.budgetly.api.generated.model.NonFinancialCategory;
import com.budgetly.api.generated.model.ProcessMessageRequest;
import com.budgetly.api.generated.model.Transaction;
import com.budgetly.api.repository.MessageRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyIterable;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class MessageServiceTest {

    private MessageRepository messageRepository;
    private TransactionService transactionService;
    private PatternRegistryService patternRegistryService;
    private LlmProvider llmProvider;
    private CategoryResolver categoryResolver;
    private FamilyGroupService familyGroupService;
    private MessageService service;

    @BeforeEach
    void setUp() {
        messageRepository = mock(MessageRepository.class);
        transactionService = mock(TransactionService.class);
        patternRegistryService = mock(PatternRegistryService.class);
        llmProvider = mock(LlmProvider.class);
        categoryResolver = mock(CategoryResolver.class);
        familyGroupService = mock(FamilyGroupService.class);
        service = new MessageService(messageRepository, transactionService,
                patternRegistryService, llmProvider, new TransactionDateParser(), categoryResolver, familyGroupService);
        ReflectionTestUtils.setField(service, "maxBatchSize", 500);
    }

    // ── WORK-001: source discriminator between ingestion paths ────

    @Test
    void processMessageStampsDirectSource() {
        // Snapshot each save so the captor sees the document as it was at call
        // time (the service mutates and re-saves the SAME instance otherwise,
        // and Mockito captures references, not copies).
        when(messageRepository.save(any(MessageDocument.class)))
                .thenAnswer(inv -> snapshot(inv.getArgument(0, MessageDocument.class)));
        when(llmProvider.analyzeMessage(anyString(), anyString(), any()))
                .thenReturn(LlmAnalysisResult.builder().financial(false).build());

        ProcessMessageRequest req = new ProcessMessageRequest();
        req.setSender("HDFCBK");
        req.setRawText("Spent Rs 500 at Grocery Mart on 01/10/2026");
        req.setFamilyGroupId("fam-1");

        service.processMessage("u1", req).join();

        ArgumentCaptor<MessageDocument> captor = ArgumentCaptor.forClass(MessageDocument.class);
        verify(messageRepository, times(2)).save(captor.capture());
        List<MessageDocument> saved = captor.getAllValues();
        // Every doc this endpoint persists must be DIRECT so the change-stream
        // listener never claims it (the endpoint processes it inline).
        assertThat(saved).allSatisfy(d -> assertThat(d.getSource()).isEqualTo(MessageDocument.SOURCE_DIRECT));
        // First persisted as PENDING then terminal status IGNORED.
        assertThat(saved).anySatisfy(d -> assertThat(d.getStatus()).isEqualTo(MessageDocument.STATUS_PENDING));
        assertThat(saved).anySatisfy(d -> assertThat(d.getStatus()).isEqualTo(MessageDocument.STATUS_IGNORED));
    }

    // ── Issue #28: non-financial classification persisted on IGNORED ────

    @Test
    void processMessagePersistsNonFinancialCategoryForIgnoredSms() {
        when(messageRepository.save(any(MessageDocument.class)))
                .thenAnswer(inv -> snapshot(inv.getArgument(0, MessageDocument.class)));
        when(categoryResolver.familyCategories("fam-1")).thenReturn(List.of());
        when(llmProvider.analyzeMessage(anyString(), anyString(), any()))
                .thenReturn(LlmAnalysisResult.builder()
                        .financial(false)
                        .nonFinancialCategory("OTP")
                        .build());

        service.processMessage("u1", req("SBIBNK", "Your OTP is 482910. Valid for 5 mins.", "fam-1")).join();

        ArgumentCaptor<MessageDocument> captor = ArgumentCaptor.forClass(MessageDocument.class);
        verify(messageRepository, times(2)).save(captor.capture());
        List<MessageDocument> saved = captor.getAllValues();
        // The terminal IGNORED save must carry the LLM's non-financial class.
        // snapshot() copies the category at save time, so this verifies the
        // mapping itself — not the mutated live instance.
        MessageDocument ignored = saved.stream()
                .filter(d -> MessageDocument.STATUS_IGNORED.equals(d.getStatus()))
                .findFirst()
                .orElseThrow();
        assertThat(ignored.getNonFinancialCategory()).isEqualTo("OTP");
    }

    @Test
    void toMessageDtoIncludesNonFinancialCategory() {
        MessageDocument doc = MessageDocument.builder()
                .id("msg-1")
                .userId("u1")
                .sender("AMAZON")
                .rawText("Flash Sale!")
                .status("IGNORED")
                .parseSource("LLM_SERVER")
                .nonFinancialCategory("PROMO")
                .build();

        Message dto = service.toMessageDto(doc);

        assertThat(dto.getNonFinancialCategory()).isEqualTo(NonFinancialCategory.PROMO);
    }

    // ── WORK-006: LLM category → transaction categoryId ──────────

    @Test
    void processMessageSetsCategoryIdFromLlmResult() {
        when(messageRepository.save(any(MessageDocument.class)))
                .thenAnswer(inv -> snapshot(inv.getArgument(0, MessageDocument.class)));
        when(categoryResolver.familyCategories("fam-1"))
                .thenReturn(List.of(category("cat-1", "Groceries")));
        when(categoryResolver.namesForPrompt(anyList()))
                .thenReturn(List.of("Groceries"));
        when(categoryResolver.categoryIdFor(anyList(), eq("Groceries")))
                .thenReturn("cat-1");
        when(llmProvider.analyzeMessage(anyString(), anyString(), any()))
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

        service.processMessage("u1", req("HDFCBK", "Spent Rs 500 at Grocery Mart on 01/10/2026", "fam-1")).join();

        ArgumentCaptor<CreateTransactionRequest> txCaptor = ArgumentCaptor.forClass(CreateTransactionRequest.class);
        verify(transactionService).createTransactionInternal(
                eq("u1"), eq("fam-1"), txCaptor.capture(), anyString(), anyString(), any());
        assertThat(txCaptor.getValue().getCategoryId()).isEqualTo("cat-1");
    }

    @Test
    void processMessageLeavesCategoryNullForUncategorized() {
        when(messageRepository.save(any(MessageDocument.class)))
                .thenAnswer(inv -> snapshot(inv.getArgument(0, MessageDocument.class)));
        when(categoryResolver.familyCategories("fam-1"))
                .thenReturn(List.of(category("cat-1", "Groceries")));
        when(categoryResolver.namesForPrompt(anyList()))
                .thenReturn(List.of("Groceries"));
        when(categoryResolver.categoryIdFor(anyList(), eq("uncategorized")))
                .thenReturn(null);
        when(llmProvider.analyzeMessage(anyString(), anyString(), any()))
                .thenReturn(LlmAnalysisResult.builder()
                        .financial(true)
                        .amount(500.0)
                        .merchant("Grocery Mart")
                        .transactionType("EXPENSE")
                        .category("uncategorized")
                        .build());
        Transaction tx = new Transaction();
        tx.setId("tx-2");
        when(transactionService.createTransactionInternal(any(), any(), any(), any(), any(), any()))
                .thenReturn(tx);

        service.processMessage("u1", req("HDFCBK", "Spent Rs 500 at Grocery Mart on 01/10/2026", "fam-1")).join();

        ArgumentCaptor<CreateTransactionRequest> txCaptor = ArgumentCaptor.forClass(CreateTransactionRequest.class);
        verify(transactionService).createTransactionInternal(
                eq("u1"), eq("fam-1"), txCaptor.capture(), anyString(), anyString(), any());
        assertThat(txCaptor.getValue().getCategoryId()).isNull();
    }

    @Test
    void processMessageUsesDefaultCategoryListWhenFamilyHasNone() {
        when(messageRepository.save(any(MessageDocument.class)))
                .thenAnswer(inv -> snapshot(inv.getArgument(0, MessageDocument.class)));
        when(categoryResolver.familyCategories("fam-1")).thenReturn(List.of());
        when(categoryResolver.namesForPrompt(anyList())).thenReturn(CategoryResolver.DEFAULT_CATEGORIES);
        when(llmProvider.analyzeMessage(anyString(), anyString(), any()))
                .thenReturn(LlmAnalysisResult.builder().financial(false).build());

        service.processMessage("u1", req("HDFCBK", "Spent Rs 500 at Grocery Mart on 01/10/2026", "fam-1")).join();

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<String>> captor = ArgumentCaptor.forClass(List.class);
        verify(llmProvider).analyzeMessage(eq("HDFCBK"), anyString(), captor.capture());
        assertThat(captor.getValue()).isEqualTo(CategoryResolver.DEFAULT_CATEGORIES);
    }

    @Test
    void processMessageLeavesCategoryNullWhenLlmReturnsUnknownCategory() {
        when(messageRepository.save(any(MessageDocument.class)))
                .thenAnswer(inv -> snapshot(inv.getArgument(0, MessageDocument.class)));
        when(categoryResolver.familyCategories("fam-1"))
                .thenReturn(List.of(category("cat-1", "Groceries")));
        when(categoryResolver.namesForPrompt(anyList())).thenReturn(List.of("Groceries"));
        when(categoryResolver.categoryIdFor(anyList(), eq("Mystery"))).thenReturn(null);
        when(llmProvider.analyzeMessage(anyString(), anyString(), any()))
                .thenReturn(LlmAnalysisResult.builder()
                        .financial(true)
                        .amount(500.0)
                        .merchant("Grocery Mart")
                        .transactionType("EXPENSE")
                        .category("Mystery")
                        .build());
        Transaction tx = new Transaction();
        tx.setId("tx-3");
        when(transactionService.createTransactionInternal(any(), any(), any(), any(), any(), any()))
                .thenReturn(tx);

        service.processMessage("u1", req("HDFCBK", "Spent Rs 500 at Grocery Mart on 01/10/2026", "fam-1")).join();

        ArgumentCaptor<CreateTransactionRequest> txCaptor = ArgumentCaptor.forClass(CreateTransactionRequest.class);
        verify(transactionService).createTransactionInternal(
                eq("u1"), eq("fam-1"), txCaptor.capture(), anyString(), anyString(), any());
        assertThat(txCaptor.getValue().getCategoryId()).isNull();
    }

    @Test
    void bulkInsertStampsBulkSourceAndAccepts() {
        when(messageRepository.saveAll(anyIterable()))
                .thenAnswer(inv -> inv.getArgument(0, List.class));

        BulkMessageRequest req = new BulkMessageRequest();
        req.setFamilyGroupId("fam-1");
        req.setMessages(List.of(msg("HDFCBK", "Spent Rs 500 at Grocery Mart"), msg("AXISBK", "Rs.200 debited")));

        BulkMessageResponse response = service.bulkInsertMessages("u1", req).join();

        assertThat(response.getStatus()).isEqualTo("ACCEPTED");
        assertThat(response.getAcceptedCount()).isEqualTo(2);

        ArgumentCaptor<List<MessageDocument>> captor = ArgumentCaptor.forClass(List.class);
        verify(messageRepository).saveAll(captor.capture());
        List<MessageDocument> docs = captor.getValue();
        assertThat(docs).hasSize(2);
        assertThat(docs).allSatisfy(doc -> {
            assertThat(doc.getSource()).isEqualTo(MessageDocument.SOURCE_BULK);
            assertThat(doc.getStatus()).isEqualTo(MessageDocument.STATUS_PENDING);
        });
        assertThat(docs).extracting(MessageDocument::getSender).containsExactly("HDFCBK", "AXISBK");
    }

    @Test
    void bulkInsertCarriesReceivedAtThrough() {
        when(messageRepository.saveAll(anyIterable()))
                .thenAnswer(inv -> inv.getArgument(0, List.class));

        BulkMessageRequest req = new BulkMessageRequest();
        req.setFamilyGroupId("fam-1");
        BulkMessageItem item = msg("HDFCBK", "Spent Rs 500 at Grocery Mart");
        item.setReceivedAt(java.time.OffsetDateTime.parse("2026-10-18T09:30:00+05:30"));
        req.setMessages(List.of(item));

        service.bulkInsertMessages("u1", req).join();

        ArgumentCaptor<List<MessageDocument>> captor = ArgumentCaptor.forClass(List.class);
        verify(messageRepository).saveAll(captor.capture());
        MessageDocument doc = captor.getValue().get(0);
        // The SMS's real timestamp must be preserved (not the server's receipt time).
        assertThat(doc.getReceivedAt()).isEqualTo(java.time.Instant.parse("2026-10-18T04:00:00Z"));
    }

    @Test
    void bulkInsertValidatesEmptyAndOversizedBatches() {
        BulkMessageRequest empty = new BulkMessageRequest();
        empty.setFamilyGroupId("fam-1");
        empty.setMessages(List.of());
        // bulkInsertMessages validates synchronously (it is not async).
        Throwable emptyErr = org.assertj.core.api.Assertions.catchThrowable(
                () -> service.bulkInsertMessages("u1", empty));
        assertThat(emptyErr).isInstanceOf(IllegalArgumentException.class);
        assertThat(emptyErr.getMessage()).contains("must not be empty");

        BulkMessageRequest tooBig = new BulkMessageRequest();
        tooBig.setFamilyGroupId("fam-1");
        tooBig.setMessages(java.util.stream.IntStream.range(0, 501)
                .mapToObj(i -> msg("S" + i, "text " + i)).toList());
        Throwable bigErr = org.assertj.core.api.Assertions.catchThrowable(
                () -> service.bulkInsertMessages("u1", tooBig));
        assertThat(bigErr).isInstanceOf(IllegalArgumentException.class);
        assertThat(bigErr.getMessage()).contains("maximum limit");
    }

    @Test
    void getIgnoredMessagesUsesIgnoredAndRejectedBucketing() {
        when(messageRepository.findByUserIdAndStatusIn(eq("u1"), any(List.class)))
                .thenAnswer(inv -> {
                    @SuppressWarnings("unchecked")
                    List<String> statuses = inv.getArgument(1);
                    return statuses.stream()
                            .filter(s -> "IGNORED".equals(s) || "REJECTED".equals(s))
                            .map(s -> MessageDocument.builder()
                                    .id("IGNORED".equals(s) ? "ig-1" : "rj-1")
                                    .status(s).build())
                            .toList();
                });

        var dto = service.getIgnoredMessages("u1");

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<String>> statusCaptor = ArgumentCaptor.forClass(List.class);
        verify(messageRepository).findByUserIdAndStatusIn(eq("u1"), statusCaptor.capture());
        assertThat(statusCaptor.getValue()).containsExactlyInAnyOrder("IGNORED", "REJECTED");
        assertThat(dto).extracting(d -> d.getId()).containsExactlyInAnyOrder("ig-1", "rj-1");
    }

    private MessageDocument snapshot(MessageDocument in) {
        return MessageDocument.builder()
                .id(in.getId()).messageId(in.getMessageId()).userId(in.getUserId())
                .familyGroupId(in.getFamilyGroupId()).sender(in.getSender()).rawText(in.getRawText())
                .status(in.getStatus()).source(in.getSource()).parseSource(in.getParseSource())
                .nonFinancialCategory(in.getNonFinancialCategory())
                .receivedAt(in.getReceivedAt()).createdAt(in.getCreatedAt()).build();
    }

    private BulkMessageItem msg(String sender, String rawText) {
        BulkMessageItem r = new BulkMessageItem();
        r.setSender(sender);
        r.setRawText(rawText);
        return r;
    }

    private ProcessMessageRequest req(String sender, String rawText, String familyGroupId) {
        ProcessMessageRequest r = new ProcessMessageRequest();
        r.setSender(sender);
        r.setRawText(rawText);
        r.setFamilyGroupId(familyGroupId);
        return r;
    }

    private CategoryDocument category(String id, String name) {
        return CategoryDocument.builder().id(id).name(name).build();
    }
}