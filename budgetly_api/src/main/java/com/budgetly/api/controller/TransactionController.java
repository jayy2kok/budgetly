package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.TransactionsApi;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.service.TransactionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class TransactionController implements TransactionsApi {

    private final TransactionService transactionService;

    @Override
    public ResponseEntity<TransactionPage> listTransactions(
            String fid, TransactionType type, LocalDate startDate, LocalDate endDate,
            String categoryId, String createdByUserId, Integer page, Integer size, String sort) {
        String userId = ControllerUtils.getCurrentUserId();
        String typeStr = type != null ? type.getValue() : null;
        String startStr = startDate != null ? startDate.toString() : null;
        String endStr = endDate != null ? endDate.toString() : null;
        return ResponseEntity.ok(transactionService.listTransactions(
                userId, fid, typeStr, startStr, endStr, categoryId, createdByUserId,
                page != null ? page : 0, size != null ? size : 20, sort));
    }

    @Override
    public ResponseEntity<Transaction> createTransaction(String fid, CreateTransactionRequest createTransactionRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(transactionService.createTransaction(userId, fid, createTransactionRequest));
    }

    @Override
    public ResponseEntity<Transaction> getTransaction(String fid, String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(transactionService.getTransaction(userId, fid, id));
    }

    @Override
    public ResponseEntity<Transaction> updateTransaction(String fid, String id, UpdateTransactionRequest updateTransactionRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(transactionService.updateTransaction(userId, fid, id, updateTransactionRequest));
    }

    @Override
    public ResponseEntity<Void> deleteTransaction(String fid, String id) {
        String userId = ControllerUtils.getCurrentUserId();
        transactionService.deleteTransaction(userId, fid, id);
        return ResponseEntity.noContent().build();
    }
}
