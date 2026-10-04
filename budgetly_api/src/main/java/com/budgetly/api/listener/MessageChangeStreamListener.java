package com.budgetly.api.listener;

import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.document.ChangeStreamTokenDocument;
import com.budgetly.api.repository.MessageRepository;
import com.budgetly.api.repository.ChangeStreamTokenRepository;
import com.budgetly.api.service.TransactionService;
import com.budgetly.api.service.PatternRegistryService;
import com.budgetly.api.llm.LlmAnalysisResult;
import com.budgetly.api.llm.LlmProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.bson.BsonDocument;
import org.bson.Document;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.mongodb.core.MongoClientFactoryBean;
import org.springframework.data.mongodb.core.MongoTemplate;

import org.springframework.data.mongodb.core.messaging.ChangeStreamRequest;
import org.springframework.data.mongodb.core.messaging.MessageListener;
import org.springframework.data.mongodb.core.messaging.MessageListenerContainer;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.stereotype.Component;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.generated.model.CreateTransactionRequest;
import com.budgetly.api.generated.model.Transaction;
import com.budgetly.api.generated.model.TransactionType;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

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
    private final String collectionName;
    private final String tokenCollectionName;

    private MessageListenerContainer container;

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
            @Value("${budgetly.change-stream.collection:messages}") String collectionName,
            @Value("${budgetly.change-stream.token-collection:change_stream_tokens}") String tokenCollectionName) {
        this.mongoTemplate = mongoTemplate;
        this.messageRepository = messageRepository;
        this.tokenRepository = tokenRepository;
        this.llmProvider = llmProvider;
        this.transactionService = transactionService;
        this.patternRegistryService = patternRegistryService;
        this.collectionName = collectionName;
        this.tokenCollectionName = tokenCollectionName;
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

        // Filter: only process insert events on messages still in PENDING status.
        // This avoids processing our own update/replace events (IN_PROGRESS -> PROCESSED)
        // and prevents the listener from re-processing its own mutations.
        builder.filter(
                org.springframework.data.mongodb.core.aggregation.Aggregation.newAggregation(
                        org.springframework.data.mongodb.core.aggregation.Aggregation.match(
                                Criteria.where("operationType").is("insert")
                                        .and("fullDocument.status").is(MessageDocument.STATUS_PENDING)
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

    // Changed from private to package-private for testing
    void processEventInternal(MessageDocument doc, BsonDocument resumeToken) {
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
            LlmAnalysisResult llmResult = llmProvider.analyzeMessage(updatedDoc.getSender(), updatedDoc.getRawText());
            
            if (!llmResult.isFinancial()) {
                updatedDoc.setStatus(MessageDocument.STATUS_IGNORED);
            } else {
                CreateTransactionRequest txRequest = new CreateTransactionRequest();
                txRequest.setAmount(llmResult.getAmount() != null ? llmResult.getAmount() : 0.0);
                txRequest.setMerchant(llmResult.getMerchant() != null ? llmResult.getMerchant() : "Unknown");
                txRequest.setType(TransactionType.fromValue(
                        "INCOME".equals(llmResult.getTransactionType()) ? "INCOME" : "EXPENSE"));
                txRequest.setTransactionDate(Instant.now().atOffset(ZoneOffset.UTC));
                txRequest.setCurrency("INR");

                SmsPatternDocument savedPattern = null;
                String template = llmResult.getTemplate();
                if (template != null) {
                    Map<String, String> em = llmResult.getExtractionMap() != null
                            ? llmResult.getExtractionMap()
                            : Map.of("amount", "amount", "merchant", "merchant", "timestamp", "timestamp");

                    savedPattern = SmsPatternDocument.builder()
                            .sender(updatedDoc.getSender())
                            .template(template)
                            .extractionMap(em)
                            .sampleMessage(updatedDoc.getRawText())
                            .usageCount(1)
                            .active(true)
                            .build();
                    savedPattern = patternRegistryService.savePattern(savedPattern);
                }

                Transaction createdTx = null;
                try {
                    String patternId = savedPattern != null ? savedPattern.getId() : null;
                    createdTx = transactionService.createTransactionInternal(
                            updatedDoc.getUserId(), updatedDoc.getFamilyGroupId(), txRequest, "LLM_SERVER", updatedDoc.getRawText(), patternId);
                } catch (Exception e) {
                    log.warn("Failed to auto-create transaction from LLM result: {}", e.getMessage());
                }

                updatedDoc.setStatus(createdTx != null ? MessageDocument.STATUS_CONFIRMED : MessageDocument.STATUS_PROCESSED);
                updatedDoc.setLinkedTransactionId(createdTx != null ? createdTx.getId() : null);
                updatedDoc.setMatchedPatternId(savedPattern != null ? savedPattern.getId() : null);

                Map<String, Object> parsedDataMap = new HashMap<>();
                if (llmResult.getAmount() != null) parsedDataMap.put("amount", llmResult.getAmount());
                if (llmResult.getMerchant() != null) parsedDataMap.put("merchant", llmResult.getMerchant());
                if (llmResult.getTransactionType() != null) parsedDataMap.put("transactionType", llmResult.getTransactionType());
                updatedDoc.setParsedTransactionData(parsedDataMap);
            }
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
            io.micrometer.core.instrument.Metrics.timer("budgetly.message.processing.latency").record(java.time.Duration.ofMillis(System.currentTimeMillis() - startTime));

        } catch (Exception e) {
            updatedDoc.setStatus(MessageDocument.STATUS_FAILED);
            updatedDoc.setErrorMessage(e.getMessage());
            messageRepository.save(updatedDoc);
            
            // Log metric: failure
            io.micrometer.core.instrument.Metrics.counter("budgetly.message.processing", "status", "failed").increment();
        }
    }

    @PreDestroy
    public void stop() {
        log.info("Stopping Message Change Stream Listener container...");
        if (container != null && container.isRunning()) {
            container.stop();
        }
    }
}
