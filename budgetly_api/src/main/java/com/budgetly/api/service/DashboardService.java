package com.budgetly.api.service;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.document.TransactionDocument;
import com.budgetly.api.exception.ForbiddenException;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.repository.*;
import com.budgetly.api.util.DateUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class DashboardService {

    private final TransactionRepository transactionRepository;
    private final CategoryRepository categoryRepository;
    private final FamilyMemberRepository familyMemberRepository;
    private final MessageRepository messageRepository;

    public DashboardData getDashboard(String userId, String familyId, String month) {
        requireMember(userId, familyId);
        if (month == null || month.isBlank()) month = DateUtils.currentYearMonth();

        Instant start = DateUtils.startOfMonth(month);
        Instant end = DateUtils.endOfMonth(month);

        List<TransactionDocument> allTx = transactionRepository.findByFamilyGroupIdAndDateRangeList(familyId, start, end);
        double totalSpent = allTx.stream()
                .filter(t -> "EXPENSE".equals(t.getType()) || "SUBSCRIPTION".equals(t.getType()))
                .mapToDouble(TransactionDocument::getAmount)
                .sum();

        // Get family budget limit from family group (default 50000)
        double monthlyBudgetLimit = 50000.0;
        // Try to get from DB... for now use default
        double leftToSpend = Math.max(0, monthlyBudgetLimit - totalSpent);

        int daysInMonth = start.atZone(java.time.ZoneOffset.UTC).toLocalDate().lengthOfMonth();
        int dayOfMonth = Math.max(1, Instant.now().atZone(java.time.ZoneOffset.UTC).getDayOfMonth());
        double dailyAverage = totalSpent / dayOfMonth;
        double projectedSpend = dailyAverage * daysInMonth;
        double estimatedSavings = Math.max(0, monthlyBudgetLimit - projectedSpend);

        List<TransactionDocument> recent = transactionRepository
                .findTop5ByFamilyGroupIdOrderByTransactionDateDesc(familyId);

        long pendingCount = messageRepository.countByFamilyGroupIdAndStatus(familyId, "PENDING");

        DashboardData data = new DashboardData();
        data.setMonthlyBudgetLimit(monthlyBudgetLimit);
        data.setTotalSpent(totalSpent);
        data.setLeftToSpend(leftToSpend);
        data.setDailyAverage(dailyAverage);
        data.setProjectedSpend(projectedSpend);
        data.setEstimatedSavings(estimatedSavings);
        data.setPendingMessageCount((int) pendingCount);

        // Recent transactions — keep simple for dashboard
        data.setRecentTransactions(recent.stream()
                .map(t -> {
                    Transaction tx = new Transaction();
                    tx.setId(t.getId());
                    tx.setAmount(t.getAmount());
                    tx.setMerchant(t.getMerchant());
                    tx.setCategoryId(t.getCategoryId());
                    tx.setCurrency(t.getCurrency());
                    if (t.getTransactionDate() != null) {
                        tx.setTransactionDate(t.getTransactionDate().atOffset(java.time.ZoneOffset.UTC));
                    }
                    if (t.getType() != null) {
                        try { tx.setType(TransactionType.fromValue(t.getType())); } catch (Exception ignored) {}
                    }
                    return tx;
                })
                .collect(Collectors.toList()));
        return data;
    }

    public BudgetSummary getBudgetSummary(String userId, String familyId, String month) {
        requireMember(userId, familyId);
        if (month == null || month.isBlank()) month = DateUtils.currentYearMonth();

        Instant start = DateUtils.startOfMonth(month);
        Instant end = DateUtils.endOfMonth(month);

        List<TransactionDocument> allTx = transactionRepository.findByFamilyGroupIdAndDateRangeList(familyId, start, end);
        List<CategoryDocument> categories = categoryRepository.findByFamilyGroupIdOrderBySortOrderAsc(familyId);

        double overallSpent = allTx.stream().mapToDouble(TransactionDocument::getAmount).sum();

        List<CategoryBudgetBreakdown> breakdowns = categories.stream()
                .map(cat -> {
                    double spent = allTx.stream()
                            .filter(t -> cat.getId().equals(t.getCategoryId()))
                            .mapToDouble(TransactionDocument::getAmount)
                            .sum();
                    CategoryBudgetBreakdown bd = new CategoryBudgetBreakdown();
                    Category catDto = new Category();
                    catDto.setId(cat.getId());
                    catDto.setName(cat.getName());
                    catDto.setIcon(cat.getIcon());
                    catDto.setColor(cat.getColor());
                    bd.setCategory(catDto);
                    bd.setBudgetLimit(cat.getBudgetLimit());
                    bd.setSpent(spent);
                    bd.setIsOverBudget(cat.getBudgetLimit() > 0 && spent > cat.getBudgetLimit());
                    return bd;
                })
                .collect(Collectors.toList());

        BudgetSummary summary = new BudgetSummary();
        summary.setMonth(month);
        summary.setOverallLimit(50000.0);
        summary.setOverallSpent(overallSpent);
        summary.setCategoryBreakdowns(breakdowns);
        return summary;
    }

    private void requireMember(String userId, String familyId) {
        if (!familyMemberRepository.existsByUserIdAndFamilyGroupId(userId, familyId)) {
            throw new ForbiddenException("Not a member of this family");
        }
    }
}
