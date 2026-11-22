package com.budgetly.api.service;

import java.time.ZoneOffset;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.generated.model.BulkMessageRequest;
import com.budgetly.api.generated.model.BulkMessageResponse;
import com.budgetly.api.generated.model.Message;
import com.budgetly.api.generated.model.MessageStatus;
import com.budgetly.api.generated.model.NonFinancialCategory;
import com.budgetly.api.generated.model.ParseSource;
import com.budgetly.api.repository.MessageRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.util.concurrent.CompletableFuture;

@Slf4j
@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageRepository messageRepository;

    @Value("${budgetly.change-stream.max-batch-size:500}")
    private int maxBatchSize;

    public CompletableFuture<BulkMessageResponse> bulkInsertMessages(String userId, BulkMessageRequest request) {
        if (request.getMessages() == null || request.getMessages().isEmpty()) {
            throw new IllegalArgumentException("Messages list must not be empty");
        }
        if (request.getMessages().size() > maxBatchSize) {
            throw new IllegalArgumentException("Batch size exceeds maximum limit of " + maxBatchSize);
        }

        List<MessageDocument> docs = request.getMessages().stream()
                .map(req -> {
                    MessageDocument.MessageDocumentBuilder b = MessageDocument.builder()
                            .userId(userId)
                            .familyGroupId(request.getFamilyGroupId())
                            .sender(req.getSender())
                            .rawText(req.getRawText())
                            .status(MessageDocument.STATUS_PENDING)
                            .parseSource("LLM_SERVER")
                            .source(MessageDocument.SOURCE_BULK);
                    // Preserve the real SMS timestamp so transactions get the
                    // correct date; the builder default (now) applies if omitted.
                    if (req.getReceivedAt() != null) {
                        b.receivedAt(req.getReceivedAt().toInstant());
                    }
                    return b.build();
                })
                .collect(Collectors.toList());

        List<MessageDocument> savedDocs = messageRepository.saveAll(docs);

        BulkMessageResponse response = new BulkMessageResponse();
        response.setStatus("ACCEPTED");
        response.setAcceptedCount(savedDocs.size());
        response.setMessageIds(savedDocs.stream().map(MessageDocument::getMessageId).collect(Collectors.toList()));
        response.setMessages(savedDocs.stream().map(this::toMessageDto).collect(Collectors.toList()));

        return CompletableFuture.completedFuture(response);
    }

    public Message toMessageDto(MessageDocument doc) {
        Message dto = new Message();
        dto.setId(doc.getId());
        dto.setUserId(doc.getUserId());
        dto.setFamilyGroupId(doc.getFamilyGroupId());
        dto.setSender(doc.getSender());
        dto.setRawText(doc.getRawText());
        dto.setLinkedTransactionId(doc.getLinkedTransactionId());
        if (doc.getStatus() != null) {
            try { dto.setStatus(MessageStatus.fromValue(doc.getStatus())); } catch (Exception ignored) {}
        }
        if (doc.getParseSource() != null) {
            try { dto.setParseSource(ParseSource.fromValue(doc.getParseSource())); } catch (Exception ignored) {}
        }
        if (doc.getNonFinancialCategory() != null) {
            try { dto.setNonFinancialCategory(NonFinancialCategory.fromValue(doc.getNonFinancialCategory())); }
            catch (Exception ignored) {}
        }
        dto.setMatchedPatternId(doc.getMatchedPatternId());
        if (doc.getReceivedAt() != null) dto.setReceivedAt(doc.getReceivedAt().atOffset(ZoneOffset.UTC));
        dto.setErrorMessage(doc.getErrorMessage());
        return dto;
    }
}