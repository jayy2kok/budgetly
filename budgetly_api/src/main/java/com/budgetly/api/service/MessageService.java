package com.budgetly.api.service;

import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.exception.ResourceNotFoundException;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.llm.LlmAnalysisResult;
import com.budgetly.api.llm.LlmProvider;
import com.budgetly.api.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageRepository messageRepository;
    private final TransactionService transactionService;
    private final PatternRegistryService patternRegistryService;
    private final LlmProvider llmProvider;

    public ProcessMessageResponse processMessage(String userId, ProcessMessageRequest request) {
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
        log.debug("LLM result for sender={}: financial={}, amount={}", sender, llmResult.isFinancial(), llmResult.getAmount());

        ProcessMessageResponse response = new ProcessMessageResponse();
        response.setIsFinancial(llmResult.isFinancial());

        if (!llmResult.isFinancial()) {
            // Non-financial → IGNORED
            messageDoc.setStatus("IGNORED");
            messageRepository.save(messageDoc);
            response.setMessage(toMessageDto(messageDoc));
            return response;
        }

        // 3. Build CreateTransactionRequest from LLM result
        CreateTransactionRequest txRequest = buildTransactionRequest(llmResult, familyGroupId);
        response.setParsedData(txRequest);

        // 4. Save pattern if regex was generated
        SmsPatternDocument savedPattern = null;
        if (llmResult.getGeneratedRegex() != null) {
            Map<String, String> em = llmResult.getExtractionMap() != null
                    ? llmResult.getExtractionMap()
                    : Map.of("amount", "amount", "merchant", "merchant", "timestamp", "timestamp");

            savedPattern = SmsPatternDocument.builder()
                    .sender(sender)
                    .regex(llmResult.getGeneratedRegex())
                    .extractionMap(em)
                    .sampleMessage(rawText)
                    .usageCount(1)
                    .active(true)
                    .build();
            savedPattern = patternRegistryService.savePattern(savedPattern);
            response.setGeneratedPattern(patternRegistryService.toDto(savedPattern));
        }

        // 5. Create transaction
        Transaction createdTx = null;
        try {
            String patternId = savedPattern != null ? savedPattern.getId() : null;
            createdTx = transactionService.createTransactionInternal(
                    userId, familyGroupId, txRequest, "LLM_SERVER", rawText, patternId);
            response.setTransactionId(createdTx.getId());
        } catch (Exception e) {
            log.warn("Failed to auto-create transaction from LLM result: {}", e.getMessage());
        }

        // 6. Update message status
        messageDoc.setStatus(createdTx != null ? "CONFIRMED" : "PENDING");
        messageDoc.setLinkedTransactionId(createdTx != null ? createdTx.getId() : null);
        messageDoc.setParseSource("LLM_SERVER");
        messageDoc = messageRepository.save(messageDoc);

        response.setMessage(toMessageDto(messageDoc));
        return response;
    }

    public List<Message> getPendingMessages(String userId) {
        return messageRepository.findByUserIdAndStatus(userId, "PENDING")
                .stream().map(this::toMessageDto).collect(Collectors.toList());
    }

    public List<Message> getIgnoredMessages(String userId) {
        return messageRepository.findByUserIdAndStatusIn(userId, List.of("IGNORED", "REJECTED"))
                .stream().map(this::toMessageDto).collect(Collectors.toList());
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

    private CreateTransactionRequest buildTransactionRequest(LlmAnalysisResult llm, String familyGroupId) {
        CreateTransactionRequest req = new CreateTransactionRequest();
        req.setAmount(llm.getAmount() != null ? llm.getAmount() : 0.0);
        req.setMerchant(llm.getMerchant() != null ? llm.getMerchant() : "Unknown");
        req.setType(TransactionType.fromValue(
                "INCOME".equals(llm.getTransactionType()) ? "INCOME" : "EXPENSE"));
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
