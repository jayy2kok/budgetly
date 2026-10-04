package com.budgetly.api.listener;

import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.llm.LlmAnalysisResult;
import com.budgetly.api.llm.LlmProvider;
import com.budgetly.api.repository.ChangeStreamTokenRepository;
import com.budgetly.api.repository.MessageRepository;
import com.budgetly.api.service.PatternRegistryService;
import com.budgetly.api.service.TransactionService;
import org.bson.BsonDocument;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.mongodb.core.FindAndModifyOptions;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class MessageChangeStreamListenerTest {

    private MongoTemplate mongoTemplate;
    private MessageRepository messageRepository;
    private ChangeStreamTokenRepository tokenRepository;
    private LlmProvider llmProvider;
    private TransactionService transactionService;
    private PatternRegistryService patternRegistryService;

    private MessageChangeStreamListener listener;

    @BeforeEach
    void setUp() {
        mongoTemplate = mock(MongoTemplate.class);
        messageRepository = mock(MessageRepository.class);
        tokenRepository = mock(ChangeStreamTokenRepository.class);
        llmProvider = mock(LlmProvider.class);
        transactionService = mock(TransactionService.class);
        patternRegistryService = mock(PatternRegistryService.class);

        listener = new MessageChangeStreamListener(
                mongoTemplate, messageRepository, tokenRepository,
                llmProvider, transactionService, patternRegistryService, "messages", "tokens"
        );
    }

    @Test
    void testProcessEventInternal_AtomicUpdateSuccess() {
        MessageDocument doc = MessageDocument.builder().id("msg1").build();
        MessageDocument updatedDoc = MessageDocument.builder().id("msg1").status(MessageDocument.STATUS_IN_PROGRESS).build();

        when(mongoTemplate.findAndModify(any(Query.class), any(Update.class), any(FindAndModifyOptions.class), eq(MessageDocument.class)))
                .thenReturn(updatedDoc);
        when(llmProvider.analyzeMessage(any(), any())).thenReturn(LlmAnalysisResult.builder().financial(false).build());

        listener.processEventInternal(doc, new BsonDocument());

        verify(mongoTemplate).findAndModify(any(Query.class), any(Update.class), any(FindAndModifyOptions.class), eq(MessageDocument.class));
        verify(messageRepository).save(any(MessageDocument.class));
    }
}
