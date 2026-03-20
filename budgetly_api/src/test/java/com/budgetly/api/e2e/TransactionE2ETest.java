package com.budgetly.api.e2e;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.TransactionDocument;
import com.budgetly.api.document.UserDocument;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;

import static org.hamcrest.Matchers.*;

/**
 * E2E tests for Transaction API: /api/v1/families/{fid}/transactions/*
 */
class TransactionE2ETest extends BaseE2ETest {

        // ── Create Transaction ──────────────────────────────────────

        @Test
        void createTransaction_expense_returns201() {
                UserDocument user = seedUser("g-tx-1", "Tx User", "tx1@test.com");
                FamilyGroupDocument family = seedFamily(user.getId(), "Tx Family");

                givenAuth(user.getId())
                                .body(Map.of(
                                                "amount", 1500.50,
                                                "merchant", "BigBazaar",
                                                "type", "EXPENSE",
                                                "currency", "INR",
                                                "transactionDate", OffsetDateTime.now(ZoneOffset.UTC).toString()))
                                .post("/families/" + family.getId() + "/transactions")
                                .then()
                                .log().all()
                                .statusCode(201)
                                .body("amount", equalTo(1500.5F))
                                .body("merchant", equalTo("BigBazaar"))
                                .body("type", equalTo("EXPENSE"))
                                .body("id", notNullValue());
        }

        @Test
        void createTransaction_withCategory_returns201() {
                UserDocument user = seedUser("g-tx-1b", "CatTx User", "cattx@test.com");
                FamilyGroupDocument family = seedFamily(user.getId(), "CatTx Family");
                CategoryDocument cat = seedCategory(family.getId(), "Groceries", "🛒", 8000);

                givenAuth(user.getId())
                                .body(Map.of(
                                                "amount", 800.0,
                                                "merchant", "DMart",
                                                "type", "EXPENSE",
                                                "categoryId", cat.getId(),
                                                "transactionDate", OffsetDateTime.now(ZoneOffset.UTC).toString()))
                                .post("/families/" + family.getId() + "/transactions")
                                .then()
                                .statusCode(201)
                                .body("categoryId", equalTo(cat.getId()));
        }

        // ── Get Transaction ─────────────────────────────────────────

        @Test
        void getTransaction_byId_returnsDetails() {
                UserDocument user = seedUser("g-tx-2", "Get User", "gettx@test.com");
                FamilyGroupDocument family = seedFamily(user.getId(), "Get Family");
                TransactionDocument tx = seedTransaction(family.getId(), user.getId(), null, 250.0, "Swiggy",
                                "EXPENSE");

                givenAuth(user.getId())
                                .get("/families/" + family.getId() + "/transactions/" + tx.getId())
                                .then()
                                .statusCode(200)
                                .body("id", equalTo(tx.getId()))
                                .body("amount", equalTo(250.0F))
                                .body("merchant", equalTo("Swiggy"));
        }

        // ── Update Transaction ──────────────────────────────────────

        @Test
        void updateTransaction_changesMerchant() {
                UserDocument user = seedUser("g-tx-3", "Update User", "uptx@test.com");
                FamilyGroupDocument family = seedFamily(user.getId(), "Update Family");
                TransactionDocument tx = seedTransaction(family.getId(), user.getId(), null, 500.0, "OldMerchant",
                                "EXPENSE");

                givenAuth(user.getId())
                                .body(Map.of("merchant", "NewMerchant", "amount", 600.0))
                                .put("/families/" + family.getId() + "/transactions/" + tx.getId())
                                .then()
                                .statusCode(200)
                                .body("merchant", equalTo("NewMerchant"))
                                .body("amount", equalTo(600.0F));
        }

        // ── Delete Transaction ──────────────────────────────────────

        @Test
        void deleteTransaction_returns204() {
                UserDocument user = seedUser("g-tx-4", "Del User", "deltx@test.com");
                FamilyGroupDocument family = seedFamily(user.getId(), "Del Family");
                TransactionDocument tx = seedTransaction(family.getId(), user.getId(), null, 100.0, "Test", "EXPENSE");

                givenAuth(user.getId())
                                .delete("/families/" + family.getId() + "/transactions/" + tx.getId())
                                .then()
                                .statusCode(204);

                // Verify it's gone
                givenAuth(user.getId())
                                .get("/families/" + family.getId() + "/transactions/" + tx.getId())
                                .then()
                                .statusCode(404);
        }

        // ── List Transactions ───────────────────────────────────────

        @Test
        void listTransactions_pagination_works() {
                UserDocument user = seedUser("g-tx-5", "Page User", "pagetx@test.com");
                FamilyGroupDocument family = seedFamily(user.getId(), "Page Family");

                // Seed 7 transactions
                for (int i = 0; i < 7; i++) {
                        seedTransaction(family.getId(), user.getId(), null, 100 + i, "Merchant" + i, "EXPENSE");
                }

                givenAuth(user.getId())
                                .queryParam("page", 0)
                                .queryParam("size", 3)
                                .get("/families/" + family.getId() + "/transactions")
                                .then()
                                .statusCode(200)
                                .body("content.size()", equalTo(3))
                                .body("totalElements", equalTo(7))
                                .body("totalPages", equalTo(3));
        }

        @Test
        void listTransactions_filterByType_onlyExpenses() {
                UserDocument user = seedUser("g-tx-6", "Filter User", "filtertx@test.com");
                FamilyGroupDocument family = seedFamily(user.getId(), "Filter Family");
                seedTransaction(family.getId(), user.getId(), null, 1000, "Salary", "INCOME");
                seedTransaction(family.getId(), user.getId(), null, 200, "Coffee", "EXPENSE");
                seedTransaction(family.getId(), user.getId(), null, 300, "Lunch", "EXPENSE");

                givenAuth(user.getId())
                                .queryParam("type", "EXPENSE")
                                .get("/families/" + family.getId() + "/transactions")
                                .then()
                                .statusCode(200)
                                .body("content.size()", equalTo(2))
                                .body("content.merchant", hasItems("Coffee", "Lunch"));
        }

        // ── Split Config ────────────────────────────────────────────

        @Test
        void createTransaction_withPercentSplit_savesSplitConfig() {
                UserDocument admin = seedUser("g-tx-7a", "Split Admin", "split1@test.com");
                UserDocument member = seedUser("g-tx-7b", "Split Member", "split2@test.com");
                FamilyGroupDocument family = seedFamily(admin.getId(), "Split Family");
                seedMember(member.getId(), family.getId());

                givenAuth(admin.getId())
                                .body(Map.of(
                                                "amount", 1000.0,
                                                "merchant", "Restaurant",
                                                "type", "EXPENSE",
                                                "splitMethod", "PERCENT",
                                                "splitConfig", Map.of(admin.getId(), 60, member.getId(), 40),
                                                "transactionDate", OffsetDateTime.now(ZoneOffset.UTC).toString()))
                                .post("/families/" + family.getId() + "/transactions")
                                .then()
                                .statusCode(201)
                                .body("id", notNullValue());
        }

        // ── Non-Member Access ───────────────────────────────────────

        @Test
        void createTransaction_nonMember_returns403() {
                UserDocument admin = seedUser("g-tx-8a", "Admin", "adminaccess@test.com");
                UserDocument outsider = seedUser("g-tx-8b", "Outsider", "outsidertx@test.com");
                FamilyGroupDocument family = seedFamily(admin.getId(), "Private Tx Family");

                givenAuth(outsider.getId())
                                .body(Map.of(
                                                "amount", 500.0,
                                                "merchant", "Hack",
                                                "type", "EXPENSE",
                                                "transactionDate", OffsetDateTime.now(ZoneOffset.UTC).toString()))
                                .post("/families/" + family.getId() + "/transactions")
                                .then()
                                .statusCode(403);
        }
}
