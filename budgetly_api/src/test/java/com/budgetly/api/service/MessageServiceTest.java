package com.budgetly.api.service;

import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.llm.LlmAnalysisResult;
import com.budgetly.api.llm.LlmProvider;
import com.budgetly.api.generated.model.BulkMessageRequest;
import com.budgetly.api.generated.model.BulkMessageResponse;
import com.budgetly.api.generated.model.ProcessMessageRequest;
import com.budgetly.api.repository.MessageRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyIterable;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class MessageServiceTest {

    private MessageRepository messageRepository;
    private TransactionService transactionService;
    private PatternRegistryService patternRegistryService;
    private LlmProvider llmProvider;
    private MessageService service;

    @BeforeEach
    void setUp() {
        messageRepository = mock(MessageRepository.class);
        transactionService = mock(TransactionService.class);
        patternRegistryService = mock(PatternRegistryService.class);
        llmProvider = mock(LlmProvider.class);
        service = new MessageService(messageRepository, transactionService,
                patternRegistryService, llmProvider, new TransactionDateParser());
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
        when(llmProvider.analyzeMessage(anyString(), anyString()))
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
                .receivedAt(in.getReceivedAt()).createdAt(in.getCreatedAt()).build();
    }

    private ProcessMessageRequest msg(String sender, String rawText) {
        ProcessMessageRequest r = new ProcessMessageRequest();
        r.setSender(sender);
        r.setRawText(rawText);
        r.setFamilyGroupId("fam-1");
        return r;
    }
}