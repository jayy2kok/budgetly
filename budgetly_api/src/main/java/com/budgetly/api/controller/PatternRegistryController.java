package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.PatternRegistryApi;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.service.PatternRegistryService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class PatternRegistryController implements PatternRegistryApi {

    private final PatternRegistryService patternRegistryService;

    @Override
    public ResponseEntity<List<SmsPattern>> getPatterns(OffsetDateTime since) {
        String userId = ControllerUtils.getCurrentUserId();
        Instant sinceInstant = since != null ? since.toInstant() : null;
        return ResponseEntity.ok(patternRegistryService.getPatterns(sinceInstant, userId));
    }

    @Override
    public ResponseEntity<List<GetPatternSenders200ResponseInner>> getPatternSenders() {
        String userId = ControllerUtils.getCurrentUserId();
        List<Map<String, Object>> senders = patternRegistryService.getPatternSenders(userId);
        List<GetPatternSenders200ResponseInner> result = senders.stream()
                .map(m -> {
                    GetPatternSenders200ResponseInner item = new GetPatternSenders200ResponseInner();
                    item.setSender((String) m.get("sender"));
                    item.setPatternCount((Integer) m.get("patternCount"));
                    return item;
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    @Override
    public ResponseEntity<ReportPattern200Response> reportPattern(String id, PatternReportRequest patternReportRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        Map<String, Object> result = patternRegistryService.reportPattern(id, userId, patternReportRequest);
        ReportPattern200Response response = new ReportPattern200Response();
        response.setPatternId((String) result.get("patternId"));
        response.setReportCount((Integer) result.get("reportCount"));
        response.setRemoved((Boolean) result.get("removed"));
        return ResponseEntity.ok(response);
    }

    @Override
    public ResponseEntity<PatternStatsResponse> getPatternStats() {
        return ResponseEntity.ok(patternRegistryService.getStats());
    }

    @Override
    public ResponseEntity<SmsPattern> createPattern(CreatePatternRequest createPatternRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(patternRegistryService.createPattern(userId, createPatternRequest));
    }

    @Override
    public ResponseEntity<SmsPattern> updatePattern(String id, UpdatePatternRequest updatePatternRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(patternRegistryService.updatePattern(id, userId, updatePatternRequest));
    }

    @Override
    public ResponseEntity<SmsPattern> disablePattern(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(patternRegistryService.disablePattern(id, userId));
    }

    @Override
    public ResponseEntity<SmsPattern> enablePattern(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(patternRegistryService.enablePattern(id, userId));
    }

    @Override
    public ResponseEntity<SmsPattern> promotePattern(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(patternRegistryService.promotePattern(id, userId));
    }

    @Override
    public ResponseEntity<SmsPattern> updatePatternCategory(String id, UpdatePatternCategoryRequest updatePatternCategoryRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        String categoryName = updatePatternCategoryRequest != null
                ? updatePatternCategoryRequest.getCategoryName()
                : null;
        return ResponseEntity.ok(patternRegistryService.updatePatternCategory(id, userId, categoryName));
    }
}