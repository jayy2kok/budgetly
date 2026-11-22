package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.MessagesApi;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.concurrent.CompletableFuture;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class MessageController implements MessagesApi {

    private final MessageService messageService;

    @Override
    public CompletableFuture<ResponseEntity<BulkMessageResponse>> bulkInsertMessages(BulkMessageRequest bulkMessageRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return messageService.bulkInsertMessages(userId, bulkMessageRequest)
                .thenApply(res -> ResponseEntity.status(org.springframework.http.HttpStatus.ACCEPTED).body(res));
    }
}