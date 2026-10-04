package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.MessagesApi;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.concurrent.CompletableFuture;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class MessageController implements MessagesApi {

    private final MessageService messageService;

    @Override
    public CompletableFuture<ResponseEntity<ProcessMessageResponse>> processMessage(ProcessMessageRequest processMessageRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return messageService.processMessage(userId, processMessageRequest)
                .thenApply(ResponseEntity::ok);
    }

    @Override
    public CompletableFuture<ResponseEntity<List<Message>>> getPendingMessages() {
        String userId = ControllerUtils.getCurrentUserId();
        return CompletableFuture.completedFuture(ResponseEntity.ok(messageService.getPendingMessages(userId)));
    }

    @Override
    public CompletableFuture<ResponseEntity<List<Message>>> getIgnoredMessages() {
        String userId = ControllerUtils.getCurrentUserId();
        return CompletableFuture.completedFuture(ResponseEntity.ok(messageService.getIgnoredMessages(userId)));
    }

    @Override
    public CompletableFuture<ResponseEntity<Transaction>> confirmMessage(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return CompletableFuture.completedFuture(ResponseEntity.ok(messageService.confirmMessage(userId, id)));
    }

    @Override
    public CompletableFuture<ResponseEntity<Message>> rejectMessage(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return CompletableFuture.completedFuture(ResponseEntity.ok(messageService.rejectMessage(userId, id)));
    }

    @Override
    public CompletableFuture<ResponseEntity<Message>> restoreMessage(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return CompletableFuture.completedFuture(ResponseEntity.ok(messageService.restoreMessage(userId, id)));
    }
}
