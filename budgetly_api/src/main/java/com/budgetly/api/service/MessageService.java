package com.budgetly.api.service;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.exception.ResourceNotFoundException;
import com.budgetly.api.generated.model.CreateTransactionRequest;
import com.budgetly.api.generated.model.Message;
import com.budgetly.api.generated.model.MessageStatus;
import com.budgetly.api.generated.model.BulkMessageRequest;
import com.budgetly.api.generated.model.BulkMessageResponse;
import com.budgetly.api.generated.model.ParseSource;
import com.budgetly.api.generated.model.ProcessMessageRequest;
import com.budgetly.api.generated.model.ProcessMessageResponse;
import com.budgetly.api.generated.model.Transaction;
import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.generated.model.TransactionType;
import com.budgetly.api.llm.LlmAnalysisResult;
import com.budgetly.api.llm.LlmProvider;
import com.budgetly.api.repository.MessageRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;

import java.util.concurrent.CompletableFuture;

@Slf4j
@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageRepository messageRepository;
    private final TransactionService transactionService;
    private final PatternRegistryService patternRegistryService;
    private final LlmProvider llmProvider;

    @Async
    public CompletableFuture<ProcessMessageResponse> processMessage(String userId, ProcessMessageRequest request) {
        String familyGroupId = request.getFamilyGroupId();
        String sender = request.getSender();
        String rawText = request.getRawText();

        // 1. Save incoming message as PENDING
        MessageDocument messageDoc = MessageDocument.builder()
                .userId(userId)
                .familyGroupId(familyGroupId)
                .sender(sender)
                .rawText(rawText)
                .status("PENDING")
                .parseSource("LLM_SERVER")
                .build();
        messageDoc = messageRepository.save(messageDoc);

        // 2. Invoke LLM
        LlmAnalysisResult llmResult = llmProvider.analyzeMessage(sender, rawText);
        log.debug("Async LLM result for sender={}: financial={}, amount={}", sender, llmResult.isFinancial(), llmResult.getAmount());

        ProcessMessageResponse response = new ProcessMessageResponse();

        if (!llmResult.isFinancial()) {
            messageDoc.setStatus("IGNORED");
            messageRepository.save(messageDoc);

            response.setIsFinancial(false);
            response.setMessage(toMessageDto(messageDoc));
            return CompletableFuture.completedFuture(response);
        }

        CreateTransactionRequest txRequest = buildTransactionRequest(llmResult, familyGroupId);

        // Save pattern if template was generated
        SmsPatternDocument savedPattern = null;
        String template = llmResult.getTemplate();

        if (template != null) {
            Map<String, String> em = llmResult.getExtractionMap() != null
                    ? llmResult.getExtractionMap()
                    : Map.of("amount", "amount", "merchant", "merchant", "timestamp", "timestamp");

            savedPattern = SmsPatternDocument.builder()
                    .sender(sender)
                    .template(template)
                    .extractionMap(em)
                    .sampleMessage(rawText)
                    .usageCount(1)
                    .active(true)
                    .build();
            savedPattern = patternRegistryService.savePattern(savedPattern);
        }

        // Create transaction
        Transaction createdTx = null;
        try {
            String patternId = savedPattern != null ? savedPattern.getId() : null;
            createdTx = transactionService.createTransactionInternal(
                    userId, familyGroupId, txRequest, "LLM_SERVER", rawText, patternId);
        } catch (Exception e) {
            log.warn("Failed to auto-create transaction from LLM result: {}", e.getMessage());
        }

        messageDoc.setStatus(createdTx != null ? "CONFIRMED" : "PENDING");
        messageDoc.setLinkedTransactionId(createdTx != null ? createdTx.getId() : null);
        messageDoc.setMatchedPatternId(savedPattern != null ? savedPattern.getId() : null);
        messageDoc.setParseSource("LLM_SERVER");

        Map<String, Object> parsedDataMap = new HashMap<>();
        if (llmResult.getAmount() != null) parsedDataMap.put("amount", llmResult.getAmount());
        if (llmResult.getMerchant() != null) parsedDataMap.put("merchant", llmResult.getMerchant());
        if (llmResult.getTransactionType() != null) parsedDataMap.put("transactionType", llmResult.getTransactionType());
        messageDoc.setParsedTransactionData(parsedDataMap);

        messageDoc = messageRepository.save(messageDoc);

        response.setIsFinancial(true);
        if (createdTx != null) {
            response.setTransactionId(createdTx.getId());
        }
        response.setParsedData(txRequest);
        response.setMessage(toMessageDto(messageDoc));

        if (savedPattern != null) {
            response.setGeneratedPattern(patternRegistryService.toDto(savedPattern));
        }

        return CompletableFuture.completedFuture(response);
    }

    public List<Message> getPendingMessages(String userId) {
        return messageRepository.findByUserIdAndStatus(userId, "PENDING")
                .stream().map(this::toMessageDto).collect(Collectors.toList());
    }

    public List<Message> getIgnoredMessages(String userId) {
        return messageRepository.findByUserIdAndStatus(userId, "IGNORED")
                .stream().map(this::toMessageDto).collect(Collectors.toList());
    }

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
                .map(req -> MessageDocument.builder()
                        .userId(userId)
                        .familyGroupId(request.getFamilyGroupId())
                        .sender(req.getSender())
                        .rawText(req.getRawText())
                        .status(MessageDocument.STATUS_PENDING)
                        .parseSource("LLM_SERVER")
                        .build())
                .collect(Collectors.toList());

        List<MessageDocument> savedDocs = messageRepository.saveAll(docs);
        
        BulkMessageResponse response = new BulkMessageResponse();
        response.setStatus("ACCEPTED");
        response.setAcceptedCount(savedDocs.size());
        response.setMessageIds(savedDocs.stream().map(MessageDocument::getMessageId).collect(Collectors.toList()));
        response.setMessages(savedDocs.stream().map(this::toMessageDto).collect(Collectors.toList()));
        
        return CompletableFuture.completedFuture(response);
    }

    public Transaction confirmMessage(String userId, String messageId) {
        MessageDocument msg = getMessageForUser(userId, messageId);
        if (!"PENDING".equals(msg.getStatus())) {
            throw new IllegalStateException("Message is not in PENDING status");
        }

        // Build transaction from stored parsed data
        CreateTransactionRequest txRequest = buildFromParsedData(msg);
        Transaction tx = transactionService.createTransactionInternal(
                userId, msg.getFamilyGroupId(), txRequest, "LLM_SERVER", msg.getRawText(), msg.getMatchedPatternId());

        msg.setStatus("CONFIRMED");
        msg.setLinkedTransactionId(tx.getId());
        messageRepository.save(msg);
        return tx;
    }

    public Message rejectMessage(String userId, String messageId) {
        MessageDocument msg = getMessageForUser(userId, messageId);
        msg.setStatus("REJECTED");
        return toMessageDto(messageRepository.save(msg));
    }

    public Message restoreMessage(String userId, String messageId) {
        MessageDocument msg = getMessageForUser(userId, messageId);
        msg.setStatus("PENDING");
        return toMessageDto(messageRepository.save(msg));
    }

    // ── Helpers ──────────────────────────────────────────────────

    private MessageDocument getMessageForUser(String userId, String messageId) {
        return messageRepository.findByIdAndUserId(messageId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Message", messageId));
    }

    private CreateTransactionRequest buildTransactionRequest(LlmAnalysisResult llmResult, String familyGroupId) {
        CreateTransactionRequest req = new CreateTransactionRequest();
        req.setAmount(llmResult.getAmount() != null ? llmResult.getAmount() : 0.0);
        req.setMerchant(llmResult.getMerchant() != null ? llmResult.getMerchant() : "Unknown");
        req.setType(TransactionType.fromValue(
                "INCOME".equals(llmResult.getTransactionType()) ? "INCOME" : "EXPENSE"));
        req.setTransactionDate(Instant.now().atOffset(ZoneOffset.UTC));
        req.setCurrency("INR");
        return req;
    }

    @SuppressWarnings("unchecked")
    private CreateTransactionRequest buildFromParsedData(MessageDocument msg) {
        CreateTransactionRequest req = new CreateTransactionRequest();
        if (msg.getParsedTransactionData() != null) {
            Map<String, Object> data = msg.getParsedTransactionData();
            if (data.containsKey("amount")) req.setAmount(((Number) data.get("amount")).doubleValue());
            if (data.containsKey("merchant")) req.setMerchant((String) data.get("merchant"));
        }
        if (req.getAmount() == null) req.setAmount(0.0);
        if (req.getMerchant() == null) req.setMerchant("Unknown");
        req.setType(TransactionType.EXPENSE);
        req.setTransactionDate(Instant.now().atOffset(ZoneOffset.UTC));
        req.setCurrency("INR");
        return req;
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
        dto.setMatchedPatternId(doc.getMatchedPatternId());
        if (doc.getReceivedAt() != null) dto.setReceivedAt(doc.getReceivedAt().atOffset(ZoneOffset.UTC));
        return dto;
    }
}
