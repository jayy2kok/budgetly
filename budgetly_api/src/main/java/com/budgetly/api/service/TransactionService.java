package com.budgetly.api.service;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.document.TransactionDocument;
import com.budgetly.api.exception.ForbiddenException;
import com.budgetly.api.exception.ResourceNotFoundException;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.push.ExpenseAlertNotifier;
import com.budgetly.api.repository.CategoryRepository;
import com.budgetly.api.repository.FamilyMemberRepository;
import com.budgetly.api.repository.TransactionRepository;
import com.budgetly.api.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class TransactionService {

    private final TransactionRepository transactionRepository;
    private final FamilyMemberRepository familyMemberRepository;
    private final CategoryRepository categoryRepository;
    private final UserRepository userRepository;
    private final ExpenseAlertNotifier expenseAlertNotifier;

    public TransactionPage listTransactions(String userId, String familyId,
                                             String type, String startDate, String endDate,
                                             String categoryId, String createdByUserId,
                                             int page, int size, String sort) {
        requireMember(userId, familyId);
        Pageable pageable = buildPageable(page, size, sort);

        Page<TransactionDocument> docPage;
        if (type != null) {
            docPage = transactionRepository.findByFamilyGroupIdAndType(familyId, type, pageable);
        } else if (startDate != null && endDate != null) {
            Instant start = Instant.parse(startDate + "T00:00:00Z");
            Instant end = Instant.parse(endDate + "T23:59:59Z");
            docPage = transactionRepository.findByFamilyGroupIdAndDateRange(familyId, start, end, pageable);
        } else if (categoryId != null) {
            docPage = transactionRepository.findByFamilyGroupIdAndCategoryId(familyId, categoryId, pageable);
        } else {
            docPage = transactionRepository.findByFamilyGroupId(familyId, pageable);
        }

        TransactionPage result = new TransactionPage();
        result.setContent(docPage.getContent().stream().map(this::toDto).collect(Collectors.toList()));
        result.setPage(docPage.getNumber());
        result.setSize(docPage.getSize());
        result.setTotalElements(docPage.getTotalElements());
        result.setTotalPages(docPage.getTotalPages());
        result.setLast(docPage.isLast());
        return result;
    }

    public Transaction createTransaction(String userId, String familyId, CreateTransactionRequest request) {
        requireMember(userId, familyId);
        TransactionDocument doc = TransactionDocument.builder()
                .familyGroupId(familyId)
                .createdByUserId(userId)
                .categoryId(request.getCategoryId())
                .amount(request.getAmount())
                .currency(request.getCurrency() != null ? request.getCurrency() : "INR")
                .merchant(request.getMerchant())
                .description(request.getDescription())
                .type(request.getType() != null ? request.getType().getValue() : "EXPENSE")
                .splitMethod(request.getSplitMethod() != null ? request.getSplitMethod().getValue() : "PERSONAL")
                .splitConfig(request.getSplitConfig() != null ? castSplitConfig(request.getSplitConfig()) : null)
                .sourceType(request.getSourceType() != null ? request.getSourceType().getValue() : "MANUAL")
                .sourceRawText(request.getSourceRawText())
                .matchedPatternId(request.getMatchedPatternId())
                .accountLast4(request.getAccountLast4())
                .bankName(request.getBankName())
                .notes(request.getNotes())
                .transactionDate(request.getTransactionDate() != null
                        ? request.getTransactionDate().toInstant() : Instant.now())
                .build();
        TransactionDocument saved = transactionRepository.save(doc);
        expenseAlertNotifier.onTransactionCreated(saved, userId);
        return toDto(saved);
    }

    public Transaction getTransaction(String userId, String familyId, String transactionId) {
        requireMember(userId, familyId);
        TransactionDocument doc = transactionRepository.findByIdAndFamilyGroupId(transactionId, familyId)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction", transactionId));
        return toDto(doc);
    }

    public Transaction updateTransaction(String userId, String familyId, String transactionId,
                                         UpdateTransactionRequest request) {
        requireMember(userId, familyId);
        TransactionDocument doc = transactionRepository.findByIdAndFamilyGroupId(transactionId, familyId)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction", transactionId));

        if (request.getAmount() != null) doc.setAmount(request.getAmount());
        if (request.getMerchant() != null) doc.setMerchant(request.getMerchant());
        if (request.getDescription() != null) doc.setDescription(request.getDescription());
        if (request.getType() != null) doc.setType(request.getType().getValue());
        if (request.getCategoryId() != null) {
            doc.setCategoryId(request.getCategoryId().isBlank() ? null : request.getCategoryId());
        }
        if (request.getSplitMethod() != null) doc.setSplitMethod(request.getSplitMethod().getValue());
        if (request.getSplitConfig() != null) doc.setSplitConfig(castSplitConfig(request.getSplitConfig()));
        if (request.getNotes() != null) doc.setNotes(request.getNotes());
        if (request.getAccountLast4() != null) doc.setAccountLast4(request.getAccountLast4());
        if (request.getBankName() != null) doc.setBankName(request.getBankName());
        if (request.getTransactionDate() != null) doc.setTransactionDate(request.getTransactionDate().toInstant());

        return toDto(transactionRepository.save(doc));
    }

    public void deleteTransaction(String userId, String familyId, String transactionId) {
        requireMember(userId, familyId);
        TransactionDocument doc = transactionRepository.findByIdAndFamilyGroupId(transactionId, familyId)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction", transactionId));
        transactionRepository.delete(doc);
    }

    // ── Package-level helpers for other services ─────────────────

    public Transaction createTransactionInternal(String userId, String familyId,
                                                  CreateTransactionRequest request,
                                                  String sourceType, String rawText, String patternId) {
        TransactionDocument doc = TransactionDocument.builder()
                .familyGroupId(familyId)
                .createdByUserId(userId)
                .categoryId(request.getCategoryId())
                .amount(request.getAmount())
                .currency(request.getCurrency() != null ? request.getCurrency() : "INR")
                .merchant(request.getMerchant())
                .description(request.getDescription())
                .type(request.getType() != null ? request.getType().getValue() : "EXPENSE")
                .splitMethod(request.getSplitMethod() != null ? request.getSplitMethod().getValue() : "PERSONAL")
                .splitConfig(request.getSplitConfig() != null ? castSplitConfig(request.getSplitConfig()) : null)
                .sourceType(sourceType)
                .sourceRawText(rawText)
                .matchedPatternId(patternId)
                .accountLast4(request.getAccountLast4())
                .bankName(request.getBankName())
                .notes(request.getNotes())
                .transactionDate(request.getTransactionDate() != null
                        ? request.getTransactionDate().toInstant() : Instant.now())
                .build();
        TransactionDocument saved = transactionRepository.save(doc);
        expenseAlertNotifier.onTransactionCreated(saved, userId);
        return toDto(saved);
    }

    // ── Helpers ──────────────────────────────────────────────────

    private static final java.util.regex.Pattern NON_ALPHA = java.util.regex.Pattern.compile("[^A-Za-z]");

    /**
     * Normalises a raw currency hint (e.g. "Rs.", "₹", "USD") to an ISO-4217
     * code, or {@code null} when the text carries no recognisable currency.
     * Used by the anchor fast-path, whose SMS bodies include the amount text.
     */
    public static String currencyFromText(String text) {
        if (text == null || text.isBlank()) {
            return null;
        }
        String up = text.toUpperCase(java.util.Locale.ROOT);
        if (up.contains("RS.") || up.contains("RS ") || up.contains("INR") || up.contains("₹")) {
            return "INR";
        }
        if (up.contains("USD") || up.contains("$")) {
            return "USD";
        }
        if (up.contains("EUR") || up.contains("€")) {
            return "EUR";
        }
        if (up.contains("GBP") || up.contains("£")) {
            return "GBP";
        }
        String letters = NON_ALPHA.matcher(up).replaceAll("");
        if (letters.matches("[A-Z]{3}")) {
            return letters;
        }
        return null;
    }

    private void requireMember(String userId, String familyId) {
        if (!familyMemberRepository.existsByUserIdAndFamilyGroupIdAndStatus(userId, familyId, "ACTIVE")) {
            throw new ForbiddenException("Not a member of this family");
        }
    }

    private Pageable buildPageable(int page, int size, String sort) {
        if (sort == null || sort.isBlank()) {
            return PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "transactionDate"));
        }
        String[] parts = sort.split(",");
        Sort.Direction dir = parts.length > 1 && "asc".equalsIgnoreCase(parts[1])
                ? Sort.Direction.ASC : Sort.Direction.DESC;
        return PageRequest.of(page, size, Sort.by(dir, parts[0]));
    }

    @SuppressWarnings("unchecked")
    private java.util.Map<String, Double> castSplitConfig(Object splitConfig) {
        if (splitConfig instanceof java.util.Map) {
            java.util.Map<?, ?> raw = (java.util.Map<?, ?>) splitConfig;
            java.util.Map<String, Double> result = new java.util.HashMap<>();
            raw.forEach((k, v) -> result.put(String.valueOf(k), ((Number) v).doubleValue()));
            return result;
        }
        return null;
    }

    public Transaction toDto(TransactionDocument doc) {
        Transaction dto = new Transaction();
        dto.setId(doc.getId());
        dto.setFamilyGroupId(doc.getFamilyGroupId());
        dto.setCreatedByUserId(doc.getCreatedByUserId());
        dto.setCategoryId(doc.getCategoryId());
        dto.setAmount(doc.getAmount());
        dto.setCurrency(doc.getCurrency());
        dto.setMerchant(doc.getMerchant());
        dto.setDescription(doc.getDescription());
        if (doc.getType() != null) {
            try { dto.setType(TransactionType.fromValue(doc.getType())); } catch (Exception ignored) {}
        }
        if (doc.getSourceType() != null) {
            try { dto.setSourceType(SourceType.fromValue(doc.getSourceType())); } catch (Exception ignored) {}
        }
        dto.setSourceRawText(doc.getSourceRawText());
        dto.setMatchedPatternId(doc.getMatchedPatternId());
        dto.setAccountLast4(doc.getAccountLast4());
        dto.setBankName(doc.getBankName());
        dto.setNotes(doc.getNotes());
        if (doc.getTransactionDate() != null) dto.setTransactionDate(doc.getTransactionDate().atOffset(ZoneOffset.UTC));
        if (doc.getCreatedAt() != null) dto.setCreatedAt(doc.getCreatedAt().atOffset(ZoneOffset.UTC));

        // Enrich with category and user if needed — kept simple for now
        if (doc.getCategoryId() != null) {
            categoryRepository.findById(doc.getCategoryId()).ifPresent(cat -> {
                Category catDto = new Category();
                catDto.setId(cat.getId());
                catDto.setName(cat.getName());
                catDto.setIcon(cat.getIcon());
                catDto.setColor(cat.getColor());
                dto.setCategory(catDto);
            });
        }
        return dto;
    }
}
