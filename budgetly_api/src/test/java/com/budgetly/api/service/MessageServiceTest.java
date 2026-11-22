package com.budgetly.api.service;

import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.generated.model.BulkMessageItem;
import com.budgetly.api.generated.model.BulkMessageRequest;
import com.budgetly.api.generated.model.BulkMessageResponse;
import com.budgetly.api.repository.MessageRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyIterable;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class MessageServiceTest {

    private MessageRepository messageRepository;
    private MessageService service;

    @BeforeEach
    void setUp() {
        messageRepository = mock(MessageRepository.class);
        service = new MessageService(messageRepository);
        ReflectionTestUtils.setField(service, "maxBatchSize", 500);
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

    private BulkMessageItem msg(String sender, String rawText) {
        BulkMessageItem r = new BulkMessageItem();
        r.setSender(sender);
        r.setRawText(rawText);
        return r;
    }
}