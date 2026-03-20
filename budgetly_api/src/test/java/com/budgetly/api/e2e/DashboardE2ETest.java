package com.budgetly.api.e2e;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.UserDocument;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;

import static org.hamcrest.Matchers.*;

/**
 * E2E tests for Dashboard & Budget API: /api/v1/families/{fid}/dashboard, budget
 */
class DashboardE2ETest extends BaseE2ETest {

    // ── Dashboard — No Transactions ─────────────────────────────

    @Test
    void getDashboard_noTransactions_returnsZeroes() {
        UserDocument user = seedUser("g-dash-1", "Dash User", "dash1@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Dash Family");

        givenAuth(user.getId())
                .get("/families/" + family.getId() + "/dashboard")
                .then()
                .statusCode(200)
                .body("totalSpent", equalTo(0.0F))
                .body("monthlyBudgetLimit", greaterThan(0.0F));
    }

    // ── Dashboard — With Transactions ───────────────────────────

    @Test
    void getDashboard_withExpenses_showsCorrectTotals() {
        UserDocument user = seedUser("g-dash-2", "Dash User 2", "dash2@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Dash Family 2");

        seedTransaction(family.getId(), user.getId(), null, 5000, "BigBazaar", "EXPENSE");
        seedTransaction(family.getId(), user.getId(), null, 3000, "Swiggy", "EXPENSE");
        seedTransaction(family.getId(), user.getId(), null, 2000, "Amazon", "SUBSCRIPTION");

        givenAuth(user.getId())
                .get("/families/" + family.getId() + "/dashboard")
                .then()
                .statusCode(200)
                .body("totalSpent", equalTo(10000.0F))
                .body("recentTransactions.size()", greaterThanOrEqualTo(3));
    }

    // ── Budget Summary ──────────────────────────────────────────

    @Test
    void getBudgetSummary_withCategories_showsBreakdown() {
        UserDocument user = seedUser("g-dash-3", "Budget User", "budget1@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Budget Family");
        CategoryDocument groceries = seedCategory(family.getId(), "Groceries", "🛒", 8000);
        CategoryDocument dining = seedCategory(family.getId(), "Dining", "🍕", 5000);

        seedTransaction(family.getId(), user.getId(), groceries.getId(), 6000, "BigBazaar", "EXPENSE");
        seedTransaction(family.getId(), user.getId(), dining.getId(), 6000, "Zomato", "EXPENSE");

        givenAuth(user.getId())
                .get("/families/" + family.getId() + "/budget/summary")
                .then()
                .statusCode(200)
                .body("overallSpent", equalTo(12000.0F))
                .body("categoryBreakdowns.size()", equalTo(2));
    }

    // ── Update Budget ───────────────────────────────────────────

    @Test
    void updateBudget_changesMonthlyLimit() {
        UserDocument user = seedUser("g-dash-4", "Budget Admin", "budget2@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Budget Admin Family");

        givenAuth(user.getId())
                .body(Map.of("monthlyBudgetLimit", 75000.0))
                .put("/families/" + family.getId() + "/budget")
                .then()
                .statusCode(200)
                .body("monthlyBudgetLimit", equalTo(75000.0F));
    }

    // ── Over-Budget Detection ───────────────────────────────────

    @Test
    void budgetSummary_overBudget_flagsCategory() {
        UserDocument user = seedUser("g-dash-5", "Over User", "over@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Over Family");
        CategoryDocument cat = seedCategory(family.getId(), "Entertainment", "🎬", 2000);

        // Spend more than category budget
        seedTransaction(family.getId(), user.getId(), cat.getId(), 3000, "Netflix", "EXPENSE");

        givenAuth(user.getId())
                .get("/families/" + family.getId() + "/budget/summary")
                .then()
                .statusCode(200)
                .body("categoryBreakdowns[0].isOverBudget", equalTo(true))
                .body("categoryBreakdowns[0].spent", equalTo(3000.0F));
    }

    // ── Non-Member Access ───────────────────────────────────────

    @Test
    void getDashboard_nonMember_returns403() {
        UserDocument admin = seedUser("g-dash-6a", "Admin", "dashadmin@test.com");
        UserDocument outsider = seedUser("g-dash-6b", "Outsider", "dashout@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Private Dash");

        givenAuth(outsider.getId())
                .get("/families/" + family.getId() + "/dashboard")
                .then()
                .statusCode(403);
    }
}
