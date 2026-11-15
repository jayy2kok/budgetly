package com.budgetly.api.listener;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.document.ChangeStreamTokenDocument;
import com.budgetly.api.repository.MessageRepository;
import com.budgetly.api.repository.ChangeStreamTokenRepository;
import com.budgetly.api.service.AnchorParserService;
import com.budgetly.api.service.CategoryResolver;
import com.budgetly.api.service.PatternRegistryService;
import com.budgetly.api.service.TransactionDateParser;
import com.budgetly.api.service.TransactionService;
import com.budgetly.api.llm.LlmAnalysisResult;
import com.budgetly.api.llm.LlmProvider;
import lombok.extern.slf4j.Slf4j;
import org.bson.BsonDocument;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.mongodb.core.MongoTemplate;

import org.springframework.data.mongodb.core.messaging.ChangeStreamRequest;
import org.springframework.data.mongodb.core.messaging.MessageListenerContainer;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.stereotype.Component;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.generated.model.CreateTransactionRequest;
import com.budgetly.api.generated.model.Transaction;
import com.budgetly.api.generated.model.TransactionType;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

@Slf4j
@Component
@ConditionalOnProperty(name = "budgetly.change-stream.enabled", havingValue = "true", matchIfMissing = true)
public class MessageChangeStreamListener {

    private final MongoTemplate mongoTemplate;
    private final MessageRepository messageRepository;
    private final ChangeStreamTokenRepository tokenRepository;
    private final LlmProvider llmProvider;
    private final TransactionService transactionService;
    private final PatternRegistryService patternRegistryService;
    private final AnchorParserService anchorParserService;
    private final TransactionDateParser transactionDateParser;
    private final CategoryResolver categoryResolver;
    private final String collectionName;
    private final String tokenCollectionName;

    private MessageListenerContainer container;

    /**
     * Change-stream lag in milliseconds = how long a bulk-inserted message
     * waited before the consumer finalized it (now − message.createdAt,
     * refreshed on every successful event). Grows while the consumer falls
     * behind the insert rate and those events are queued unread.
     */
    private final AtomicLong changeStreamLagMillis = new AtomicLong();

    public boolean isRunning() {
        return container != null && container.isRunning();
    }

    public MessageChangeStreamListener(
            MongoTemplate mongoTemplate,
            MessageRepository messageRepository,
            ChangeStreamTokenRepository tokenRepository,
            LlmProvider llmProvider,
            TransactionService transactionService,
            PatternRegistryService patternRegistryService,
            AnchorParserService anchorParserService,
            TransactionDateParser transactionDateParser,
            CategoryResolver categoryResolver,
            @Value("${budgetly.change-stream.collection:messages}") String collectionName,
            @Value("${budgetly.change-stream.token-collection:change_stream_tokens}") String tokenCollectionName) {
        this.mongoTemplate = mongoTemplate;
        this.messageRepository = messageRepository;
        this.tokenRepository = tokenRepository;
        this.llmProvider = llmProvider;
        this.transactionService = transactionService;
        this.patternRegistryService = patternRegistryService;
        this.anchorParserService = anchorParserService;
        this.transactionDateParser = transactionDateParser;
        this.categoryResolver = categoryResolver;
        this.collectionName = collectionName;
        this.tokenCollectionName = tokenCollectionName;
        io.micrometer.core.instrument.Metrics.gauge(
                "budgetly.message.change-stream.lag.milliseconds", changeStreamLagMillis);
    }

    @PostConstruct
    public void start() {
        log.info("Starting Message Change Stream Listener...");
        this.container = new org.springframework.data.mongodb.core.messaging.DefaultMessageListenerContainer(mongoTemplate);
        this.container.start();

        ChangeStreamTokenDocument tokenDoc = tokenRepository.findById("message-processor").orElse(null);
        BsonDocument resumeToken = (tokenDoc != null) ? BsonDocument.parse(tokenDoc.getToken()) : null;

        ChangeStreamRequest.ChangeStreamRequestBuilder builder = ChangeStreamRequest.builder()
                .collection(collectionName);

        if (resumeToken != null) {
            builder.resumeToken(resumeToken);
        }

        // Only insert events on PENDING documents that entered via the bulk API.
        // Excluding SOURCE_DIRECT (legacy /messages/process) removes the duplicate-
        // processing race: the process endpoint handles its own docs synchronously.
        builder.filter(
                org.springframework.data.mongodb.core.aggregation.Aggregation.newAggregation(
                        org.springframework.data.mongodb.core.aggregation.Aggregation.match(
                                Criteria.where("operationType").is("insert")
                                        .and("fullDocument.status").is(MessageDocument.STATUS_PENDING)
                                        .and("fullDocument.source").is(MessageDocument.SOURCE_BULK)
                        )
                )
        );

        ChangeStreamRequest request = builder
                .publishTo(m -> {
                    if (m != null && m.getBody() != null) {
                        BsonDocument token = null;
                        if (m.getRaw() instanceof com.mongodb.client.model.changestream.ChangeStreamDocument) {
                            token = ((com.mongodb.client.model.changestream.ChangeStreamDocument<?>) m.getRaw()).getResumeToken();
                        }
                        processEventInternal((MessageDocument) m.getBody(), token);
                    }
                })
                .build();

        this.container.register(request, MessageDocument.class);
    }

    /**
     * Cheap server-side counterpart of the change-stream filter; the filter is
     * the primary guard, this protects against a misconfigured stream.
     */
    static boolean isEligibleForStream(MessageDocument doc) {
        return doc != null
                && MessageDocument.STATUS_PENDING.equals(doc.getStatus())
                && MessageDocument.SOURCE_BULK.equals(doc.getSource());
    }

    // Changed from private to package-private for testing
    void processEventInternal(MessageDocument doc, BsonDocument resumeToken) {

        if (!isEligibleForStream(doc)) {
            log.info("Skipping non-eligible change event for message {} (source={}, status={}); "
                    + "the process endpoint handles DIRECT documents synchronously.",
                    doc.getId(), doc.getSource(), doc.getStatus());
            return;
        }

        log.info("Processing new message event: {}", doc.getMessageId());

        // Log metric: processingStarted
        io.micrometer.core.instrument.Metrics.counter("budgetly.message.processing", "status", "started").increment();

        // 1. Atomic update to IN_PROGRESS
        org.springframework.data.mongodb.core.query.Query query = org.springframework.data.mongodb.core.query.Query.query(
            Criteria.where("_id").is(doc.getId()).and("status").is(MessageDocument.STATUS_PENDING)
        );
        org.springframework.data.mongodb.core.query.Update update = new org.springframework.data.mongodb.core.query.Update()
            .set("status", MessageDocument.STATUS_IN_PROGRESS)
            .set("processingStartedAt", Instant.now());

        MessageDocument updatedDoc = mongoTemplate.findAndModify(
            query, update, org.springframework.data.mongodb.core.FindAndModifyOptions.options().returnNew(true), MessageDocument.class
        );

        if (updatedDoc == null) {
            log.info("Document {} already being processed or status changed.", doc.getMessageId());
            return;
        }

        // 2. Delegate processing
        long startTime = System.currentTimeMillis();
        try {
            // 2a. FAST PATH — try the sender's registered anchor templates first.
            //     A complete literal-anchor match needs no LLM call at all.
            boolean handled = tryAnchorMatch(updatedDoc);
            if (!handled) {
                // 2b. SLOW PATH — LLM analysis then pattern/template generation.
                analyzeWithLlm(updatedDoc);
            }
            // Any terminal transition (IGNORED / CONFIRMED / PROCESSED) is done
            // — stamp completion before persisting.
            updatedDoc.setProcessedAt(Instant.now());
            messageRepository.save(updatedDoc);

            // Save resume token
            if (resumeToken != null) {
                ChangeStreamTokenDocument tokenDoc = new ChangeStreamTokenDocument(
                    "message-processor", resumeToken.toJson(), Instant.now()
                );
                tokenRepository.save(tokenDoc);
            }

            // Log metric: success
            io.micrometer.core.instrument.Metrics.counter("budgetly.message.processing", "status", "success").increment();
            io.micrometer.core.instrument.Metrics.timer("budgetly.message.processing.latency").record(Duration.ofMillis(System.currentTimeMillis() - startTime));

            // Log metric: change-stream lag (time this message waited to be finalized).
            Instant createdAt = updatedDoc.getCreatedAt();
            if (createdAt != null) {
                changeStreamLagMillis.set(Math.max(0, Duration.between(createdAt, Instant.now()).toMillis()));
            }

        } catch (Exception e) {
            updatedDoc.setStatus(MessageDocument.STATUS_FAILED);
            updatedDoc.setErrorMessage(e.getMessage());
            messageRepository.save(updatedDoc);

            // Log metric: failure
            io.micrometer.core.instrument.Metrics.counter("budgetly.message.processing", "status", "failed").increment();
        }
    }

    // ── FAST PATH: server-side anchor-template match ─────────────

    private boolean tryAnchorMatch(MessageDocument doc) {
        List<SmsPatternDocument> patterns = patternRegistryService.findActiveBySender(doc.getSender());
        if (patterns.isEmpty()) {
            return false;
        }

        Map<String, String> parsed = null;
        SmsPatternDocument matched = null;
        for (SmsPatternDocument p : patterns) {
            Map<String, String> result = anchorParserService.parse(p.getTemplate(), doc.getRawText());
            if (result != null) {
                parsed = result;
                matched = p;
                break;
            }
        }

        if (matched == null || parsed == null) {
            return false; // No template anchors match → LLM path.
        }

        Map<String, String> em = matched.getExtractionMap() != null
                ? matched.getExtractionMap()
                : Map.of("amount", "amount", "merchant", "merchant", "timestamp", "timestamp");

        final Double amount = amountOf(parsed, em);
        final String merchant = fieldOf(parsed, em, "merchant");
        final String timestampRaw = fieldOf(parsed, em, "timestamp");
        final String typeRaw = fieldOf(parsed, em, "type");

        if (amount == null || merchant == null) {
            // Anchors matched but the pattern cannot extract all mandatory
            // fields for a transaction → treat like the app does: LLM fallback.
            log.info("Anchor match incomplete for message {} (missing amount/merchant) — LLM fallback.", doc.getMessageId());
            return false;
        }

        // Use the SMS's authoritative receivedAt (correct UTC instant); fall back
        // to the body timestamp only when it is absent.
        Instant txDate = doc.getReceivedAt() != null
                ? doc.getReceivedAt()
                : transactionDateParser
                        .parse(timestampRaw, java.time.ZoneId.of("Asia/Kolkata"))
                        .orElse(Instant.now());
        // Currency lives in the amount text (e.g. "Rs.", "USD"); the pattern
        // usually omits a dedicated {currency} token.
        String currency = TransactionService.currencyFromText(doc.getRawText());

        CreateTransactionRequest txRequest = new CreateTransactionRequest();
        txRequest.setAmount(amount);
        txRequest.setMerchant(merchant);
        txRequest.setType("INCOME".equalsIgnoreCase(typeRaw) ? TransactionType.INCOME : TransactionType.EXPENSE);
        txRequest.setTransactionDate(txDate.atOffset(ZoneOffset.UTC));
        txRequest.setCurrency(currency != null ? currency : "INR");

        matched.setUsageCount(matched.getUsageCount() + 1);
        matched = patternRegistryService.savePattern(matched);

        Transaction createdTx = null;
        try {
            createdTx = transactionService.createTransactionInternal(
                    doc.getUserId(), doc.getFamilyGroupId(), txRequest, "REGEX_LOCAL", doc.getRawText(), matched.getId());
        } catch (Exception e) {
            log.warn("Failed to auto-create transaction from anchor match: {}", e.getMessage());
        }

        doc.setStatus(createdTx != null ? MessageDocument.STATUS_CONFIRMED : MessageDocument.STATUS_PROCESSED);
        doc.setLinkedTransactionId(createdTx != null ? createdTx.getId() : null);
        doc.setMatchedPatternId(matched.getId());
        doc.setParseSource("REGEX_LOCAL");

        Map<String, Object> parsedData = new HashMap<>();
        parsedData.put("amount", amount);
        parsedData.put("merchant", merchant);
        if (timestampRaw != null) parsedData.put("timestamp", timestampRaw);
        doc.setParsedTransactionData(parsedData);

        io.micrometer.core.instrument.Metrics.counter("budgetly.message.pattern.cache-hit").increment();
        log.info("Processed message {} via anchor template {} (no LLM).", doc.getMessageId(), matched.getTemplate());
        return true;
    }

    private Double amountOf(Map<String, String> parsed, Map<String, String> em) {
        String raw = fieldOf(parsed, em, "amount");
        if (raw == null) return null;
        try {
            return Double.valueOf(raw.replace(",", "").trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String fieldOf(Map<String, String> parsed, Map<String, String> em, String field) {
        String token = em.get(field);
        String value = (token != null ? parsed.get(token) : parsed.get(field));
        return (value == null || value.isBlank()) ? null : value.trim();
    }

    // ── SLOW PATH: LLM classification + pattern proposal ─────────

    private void analyzeWithLlm(MessageDocument doc) {
        List<CategoryDocument> familyCategories = categoryResolver.familyCategories(doc.getFamilyGroupId());
        List<String> categoryNames = categoryResolver.namesForPrompt(familyCategories);
        LlmAnalysisResult llmResult = llmProvider.analyzeMessage(doc.getSender(), doc.getRawText(), categoryNames);

        if (!llmResult.isFinancial()) {
            doc.setStatus(MessageDocument.STATUS_IGNORED);
            return;
        }

        CreateTransactionRequest txRequest = new CreateTransactionRequest();
        txRequest.setAmount(llmResult.getAmount() != null ? llmResult.getAmount() : 0.0);
        txRequest.setMerchant(llmResult.getMerchant() != null ? llmResult.getMerchant() : "Unknown");
        txRequest.setType("INCOME".equals(llmResult.getTransactionType()) ? TransactionType.INCOME : TransactionType.EXPENSE);
        txRequest.setTransactionDate(transactionDateParser
                .parseOrDefault(doc.getReceivedAt(), llmResult.getRawTimestamp(), java.time.ZoneId.of("Asia/Kolkata"))
                .atOffset(ZoneOffset.UTC));
        String llmCurrency = llmResult.getCurrency();
        txRequest.setCurrency(llmCurrency != null && !llmCurrency.isBlank() ? llmCurrency.toUpperCase(java.util.Locale.ROOT) : "INR");
        String categoryId = categoryResolver.categoryIdFor(familyCategories, llmResult.getCategory());
        if (categoryId != null && !categoryId.isBlank()) {
            txRequest.setCategoryId(categoryId);
        }

        SmsPatternDocument savedPattern = null;
        String template = llmResult.getTemplate();
        if (template != null) {
            Map<String, String> em = llmResult.getExtractionMap() != null
                    ? llmResult.getExtractionMap()
                    : Map.of("amount", "amount", "merchant", "merchant", "timestamp", "timestamp");

            savedPattern = SmsPatternDocument.builder()
                    .sender(doc.getSender())
                    .template(template)
                    .extractionMap(em)
                    .sampleMessage(doc.getRawText())
                    .usageCount(1)
                    .active(true)
                    .build();
            savedPattern = patternRegistryService.savePattern(savedPattern);
        }

        Transaction createdTx = null;
        try {
            String patternId = savedPattern != null ? savedPattern.getId() : null;
            createdTx = transactionService.createTransactionInternal(
                    doc.getUserId(), doc.getFamilyGroupId(), txRequest, "LLM_SERVER", doc.getRawText(), patternId);
        } catch (Exception e) {
            log.warn("Failed to auto-create transaction from LLM result: {}", e.getMessage());
        }

        doc.setStatus(createdTx != null ? MessageDocument.STATUS_CONFIRMED : MessageDocument.STATUS_PROCESSED);
        doc.setLinkedTransactionId(createdTx != null ? createdTx.getId() : null);
        doc.setMatchedPatternId(savedPattern != null ? savedPattern.getId() : null);

        Map<String, Object> parsedDataMap = new HashMap<>();
        if (llmResult.getAmount() != null) parsedDataMap.put("amount", llmResult.getAmount());
        if (llmResult.getMerchant() != null) parsedDataMap.put("merchant", llmResult.getMerchant());
        if (llmResult.getTransactionType() != null) parsedDataMap.put("transactionType", llmResult.getTransactionType());
        if (llmResult.getCategory() != null && !llmResult.getCategory().isBlank()) parsedDataMap.put("category", llmResult.getCategory());
        doc.setParsedTransactionData(parsedDataMap);
    }

    @PreDestroy
    public void stop() {
        log.info("Stopping Message Change Stream Listener container...");
        if (container != null && container.isRunning()) {
            container.stop();
        }
    }
}