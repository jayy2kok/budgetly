package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.MessagesApi;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class MessageController implements MessagesApi {

    private final MessageService messageService;

    @Override
    public ResponseEntity<ProcessMessageResponse> processMessage(ProcessMessageRequest processMessageRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(messageService.processMessage(userId, processMessageRequest));
    }

    @Override
    public ResponseEntity<List<Message>> getPendingMessages() {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(messageService.getPendingMessages(userId));
    }

    @Override
    public ResponseEntity<List<Message>> getIgnoredMessages() {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(messageService.getIgnoredMessages(userId));
    }

    @Override
    public ResponseEntity<Transaction> confirmMessage(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(messageService.confirmMessage(userId, id));
    }

    @Override
    public ResponseEntity<Message> rejectMessage(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(messageService.rejectMessage(userId, id));
    }

    @Override
    public ResponseEntity<Message> restoreMessage(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(messageService.restoreMessage(userId, id));
    }
}
