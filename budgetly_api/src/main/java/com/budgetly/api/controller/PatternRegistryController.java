package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.PatternRegistryApi;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.service.PatternRegistryService;
import lombok.RequiredArgsConstructor;
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
        Instant sinceInstant = since != null ? since.toInstant() : null;
        return ResponseEntity.ok(patternRegistryService.getPatterns(sinceInstant));
    }

    @Override
    public ResponseEntity<List<GetPatternSenders200ResponseInner>> getPatternSenders() {
        List<Map<String, Object>> senders = patternRegistryService.getPatternSenders();
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
}
