package com.budgetly.api.service;

import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.exception.ResourceNotFoundException;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.repository.PatternRegistryRepository;
import com.budgetly.api.repository.RejectedPatternRepository;
import com.budgetly.api.document.RejectedPatternDocument;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class PatternRegistryService {

    private final PatternRegistryRepository patternRepository;
    private final RejectedPatternRepository rejectedPatternRepository;

    @Value("${pattern.report-threshold:5}")
    private int reportThreshold;

    public List<SmsPattern> getPatterns(Instant since) {
        List<SmsPatternDocument> docs = since != null
                ? patternRepository.findByActiveTrueAndCreatedAtAfter(since)
                : patternRepository.findByActiveTrue();
        return docs.stream().map(this::toDto).collect(Collectors.toList());
    }

    public List<Map<String, Object>> getPatternSenders() {
        List<SmsPatternDocument> active = patternRepository.findByActiveTrue();
        Map<String, Long> senderCounts = active.stream()
                .collect(Collectors.groupingBy(SmsPatternDocument::getSender, Collectors.counting()));
        return senderCounts.entrySet().stream()
                .map(e -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("sender", e.getKey());
                    m.put("patternCount", e.getValue().intValue());
                    return m;
                })
                .sorted(Comparator.comparing(m -> (String) m.get("sender")))
                .collect(Collectors.toList());
    }

    public Map<String, Object> reportPattern(String patternId, String userId, PatternReportRequest request) {
        SmsPatternDocument pattern = patternRepository.findById(patternId)
                .orElseThrow(() -> new ResourceNotFoundException("SmsPattern", patternId));

        pattern.setReportCount(pattern.getReportCount() + 1);

        boolean removed = false;
        if (pattern.getReportCount() >= reportThreshold) {
            pattern.setActive(false);
            removed = true;
            log.info("Pattern {} auto-disabled after {} reports", patternId, pattern.getReportCount());

            // Move to rejected_patterns
            Optional<RejectedPatternDocument> existing = rejectedPatternRepository.findByPatternId(patternId);
            if (existing.isPresent()) {
                RejectedPatternDocument rp = existing.get();
                if (!rp.getReportedByUserIds().contains(userId)) {
                    rp.getReportedByUserIds().add(userId);
                }
                rp.setReportCount(rp.getReportCount() + 1);
                rejectedPatternRepository.save(rp);
            } else {
                RejectedPatternDocument rp = RejectedPatternDocument.builder()
                        .patternId(patternId)
                        .regex(pattern.getRegex())
                        .sampleMessage(request.getSampleMessage())
                        .reportedByUserIds(new ArrayList<>(List.of(userId)))
                        .reportCount(pattern.getReportCount())
                        .build();
                rejectedPatternRepository.save(rp);
            }
        }
        patternRepository.save(pattern);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("patternId", patternId);
        result.put("reportCount", pattern.getReportCount());
        result.put("removed", removed);
        return result;
    }

    public PatternStatsResponse getStats() {
        List<SmsPatternDocument> active = patternRepository.findByActiveTrue();
        long totalUsage = active.stream().mapToLong(SmsPatternDocument::getUsageCount).sum();
        Map<String, long[]> senderStats = new LinkedHashMap<>();
        for (SmsPatternDocument p : active) {
            senderStats.computeIfAbsent(p.getSender(), k -> new long[]{0, 0});
            senderStats.get(p.getSender())[0]++;
            senderStats.get(p.getSender())[1] += p.getUsageCount();
        }

        PatternStatsResponse stats = new PatternStatsResponse();
        stats.setTotalPatterns(active.size());
        stats.setTotalSenders(senderStats.size());
        stats.setTotalUsage(totalUsage);
        // topSenders as list of maps
        return stats;
    }

    public SmsPatternDocument savePattern(SmsPatternDocument doc) {
        return patternRepository.save(doc);
    }

    public SmsPattern toDto(SmsPatternDocument doc) {
        SmsPattern dto = new SmsPattern();
        dto.setId(doc.getId());
        dto.setSender(doc.getSender());
        dto.setRegex(doc.getRegex());
        dto.setSampleMessage(doc.getSampleMessage());
        dto.setUsageCount(doc.getUsageCount());
        if (doc.getCreatedAt() != null) dto.setCreatedAt(doc.getCreatedAt().atOffset(ZoneOffset.UTC));

        if (doc.getExtractionMap() != null) {
            ExtractionMap em = new ExtractionMap();
            em.setAmount(doc.getExtractionMap().get("amount"));
            em.setMerchant(doc.getExtractionMap().get("merchant"));
            em.setTimestamp(doc.getExtractionMap().get("timestamp"));
            em.setAccountLast4(doc.getExtractionMap().get("accountLast4"));
            em.setType(doc.getExtractionMap().get("type"));
            dto.setExtractionMap(em);
        }
        return dto;
    }
}
