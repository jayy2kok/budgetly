package com.budgetly.api.e2e;

import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.FamilyMemberDocument;
import com.budgetly.api.document.UserDocument;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;

/**
 * E2E tests for Family Group API: /api/v1/families/*
 */
class FamilyGroupE2ETest extends BaseE2ETest {

    // ── Create Family ───────────────────────────────────────────

    @Test
    void createFamily_authenticated_returns201() {
        UserDocument user = seedUser("g-fam-1", "Family Admin", "admin@family.com");

        givenAuth(user.getId())
                .body(Map.of(
                        "name", "The Smiths",
                        "defaultCurrency", "INR",
                        "monthlyBudgetLimit", 60000
                ))
                .post("/families")
                .then()
                .statusCode(201)
                .body("name", equalTo("The Smiths"))
                .body("defaultCurrency", equalTo("INR"))
                .body("monthlyBudgetLimit", equalTo(60000.0F))
                .body("id", notNullValue());
    }

    // ── Get My Family (auto-create on first login) ──────────────

    @Test
    void getMyFamily_firstLogin_autoCreatesFamilyWithNoBudget() {
        UserDocument user = seedUser("g-fam-fresh", "Fresh User", "fresh@family.com");

        // First login with no family auto-creates one — and it must NOT
        // receive a default budget (regression: it used to be 50000).
        String familyId = givenAuth(user.getId())
                .get("/families/my")
                .then()
                .statusCode(200)
                .body("monthlyBudgetLimit", equalTo(0.0F))
                .extract().path("id");

        // Dashboard and budget summary must reflect the stored budget.
        givenAuth(user.getId())
                .get("/families/" + familyId + "/dashboard")
                .then()
                .statusCode(200)
                .body("monthlyBudgetLimit", equalTo(0.0F));

        givenAuth(user.getId())
                .get("/families/" + familyId + "/budget/summary")
                .then()
                .statusCode(200)
                .body("overallLimit", equalTo(0.0F));
    }

    // ── Get Family ──────────────────────────────────────────────

    @Test
    void getFamily_asMember_returnsFamily() {
        UserDocument user = seedUser("g-fam-2", "User Two", "two@family.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Family Two");

        givenAuth(user.getId())
                .get("/families/" + family.getId())
                .then()
                .statusCode(200)
                .body("id", equalTo(family.getId()))
                .body("name", equalTo("Family Two"));
    }

    @Test
    void getFamily_nonMember_returns403() {
        UserDocument admin = seedUser("g-fam-3a", "Admin", "admin3@fam.com");
        UserDocument outsider = seedUser("g-fam-3b", "Outsider", "outsider@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Private Family");

        givenAuth(outsider.getId())
                .get("/families/" + family.getId())
                .then()
                .statusCode(403);
    }

    // ── Update Family ───────────────────────────────────────────

    @Test
    void updateFamily_asAdmin_updatesFields() {
        UserDocument admin = seedUser("g-fam-4", "Admin 4", "admin4@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Before Update");

        givenAuth(admin.getId())
                .body(Map.of(
                        "name", "After Update",
                        "expenseAlertsEnabled", false
                ))
                .put("/families/" + family.getId())
                .then()
                .statusCode(200)
                .body("name", equalTo("After Update"))
                .body("expenseAlertsEnabled", equalTo(false));
    }

    @Test
    void updateFamily_asMember_notAdmin_returns403() {
        UserDocument admin = seedUser("g-fam-5a", "Admin 5", "admin5@fam.com");
        UserDocument member = seedUser("g-fam-5b", "Member 5", "member5@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Admin Only");
        seedMember(member.getId(), family.getId());

        givenAuth(member.getId())
                .body(Map.of("name", "Hacky Update"))
                .put("/families/" + family.getId())
                .then()
                .statusCode(403);
    }

    // ── Delete Family ───────────────────────────────────────────

    @Test
    void deleteFamily_asAdmin_returns204() {
        UserDocument admin = seedUser("g-fam-6", "Admin 6", "admin6@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Delete Me");

        givenAuth(admin.getId())
                .delete("/families/" + family.getId())
                .then()
                .statusCode(204);

        // Verify it's gone
        givenAuth(admin.getId())
                .get("/families/" + family.getId())
                .then()
                .statusCode(anyOf(is(404), is(403)));
    }

    // ── Invite & Join ───────────────────────────────────────────

    @Test
    void inviteAndJoin_fullFlow() {
        UserDocument admin = seedUser("g-fam-7a", "Admin 7", "admin7@fam.com");
        UserDocument newMember = seedUser("g-fam-7b", "New Member", "new@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Open Family");

        // Admin generates invite
        String inviteCode = givenAuth(admin.getId())
                .body(Map.of("email", "new@fam.com"))
                .post("/families/" + family.getId() + "/invite")
                .then()
                .statusCode(200)
                .body("inviteCode", notNullValue())
                .extract().path("inviteCode");

        // New member joins with invite code
        givenAuth(newMember.getId())
                .body(Map.of("inviteCode", inviteCode))
                .post("/families/" + family.getId() + "/join")
                .then()
                .statusCode(200)
                .body("userId", equalTo(newMember.getId()))
                .body("role", equalTo("MEMBER"));
    }

    // ── List Members ────────────────────────────────────────────

    @Test
    void listMembers_includesAdminAndMember() {
        UserDocument admin = seedUser("g-fam-8a", "Admin 8", "admin8@fam.com");
        UserDocument member = seedUser("g-fam-8b", "Member 8", "member8@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Full Family");
        seedMember(member.getId(), family.getId());

        givenAuth(admin.getId())
                .get("/families/" + family.getId() + "/members")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(2));
    }

    // ── Update Member Role ──────────────────────────────────────

    @Test
    void updateMemberRole_toAdmin() {
        UserDocument admin = seedUser("g-fam-9a", "Admin 9", "admin9@fam.com");
        UserDocument member = seedUser("g-fam-9b", "Member 9", "member9@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Role Family");
        FamilyMemberDocument memberDoc = seedMember(member.getId(), family.getId());

        givenAuth(admin.getId())
                .body(Map.of("role", "ADMIN"))
                .put("/families/" + family.getId() + "/members/" + memberDoc.getId())
                .then()
                .statusCode(200)
                .body("role", equalTo("ADMIN"));
    }

    // ── Remove Member ───────────────────────────────────────────

    @Test
    void removeMember_asAdmin_returns204() {
        UserDocument admin = seedUser("g-fam-10a", "Admin 10", "admin10@fam.com");
        UserDocument member = seedUser("g-fam-10b", "Member 10", "member10@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Removal Family");
        FamilyMemberDocument memberDoc = seedMember(member.getId(), family.getId());

        givenAuth(admin.getId())
                .delete("/families/" + family.getId() + "/members/" + memberDoc.getId())
                .then()
                .statusCode(204);
    }

    // ── Rule A: family only deleted when no active members ──────

    @Test
    void deleteFamily_withRemainingMember_keepsFamily() {
        UserDocument admin = seedUser("g-fam-11a", "Admin 11", "admin11@fam.com");
        UserDocument member = seedUser("g-fam-11b", "Member 11", "member11@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Keep Me");
        seedMember(member.getId(), family.getId());

        // Admin leaves — family must survive because a member remains.
        givenAuth(admin.getId())
                .delete("/families/" + family.getId())
                .then()
                .statusCode(204);

        // Family still reachable by the remaining member.
        givenAuth(member.getId())
                .get("/families/" + family.getId())
                .then()
                .statusCode(200)
                .body("id", equalTo(family.getId()));
    }

    @Test
    void deleteFamily_lastMember_removesFamily() {
        UserDocument admin = seedUser("g-fam-12", "Admin 12", "admin12@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Last One");

        givenAuth(admin.getId())
                .delete("/families/" + family.getId())
                .then()
                .statusCode(204);

        givenAuth(admin.getId())
                .get("/families/" + family.getId())
                .then()
                .statusCode(anyOf(is(404), is(403)));
    }

    // ── Rule B: oldest member becomes admin on admin departure ──

    @Test
    void deleteFamily_adminLeaves_oldestMemberBecomesAdmin() {
        UserDocument admin = seedUser("g-fam-13a", "Admin 13", "admin13@fam.com");
        UserDocument first = seedUser("g-fam-13b", "First Member", "first13@fam.com");
        UserDocument second = seedUser("g-fam-13c", "Second Member", "second13@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Succession");

        // first joined before second
        seedMember(first.getId(), family.getId());
        seedMember(second.getId(), family.getId());

        // Admin leaves
        givenAuth(admin.getId())
                .delete("/families/" + family.getId())
                .then()
                .statusCode(204);

        // Members list is still reachable by the remaining members; extract it
        // as plain Java objects (avoids fragile Groovy GPath closures).
        List<Map<String, Object>> members = givenAuth(first.getId())
                .get("/families/" + family.getId() + "/members")
                .then()
                .statusCode(200)
                .extract().jsonPath().getList("$");

        // oldest member (first) was promoted to ADMIN
        Map<String, Object> firstMember = members.stream()
                .filter(m -> first.getId().equals(m.get("userId")))
                .findFirst()
                .orElseThrow(() -> new AssertionError("first member missing from members"));
        assertThat("oldest member should be promoted to ADMIN",
                firstMember.get("role"), equalTo("ADMIN"));

        // second member stays a regular MEMBER
        Map<String, Object> secondMember = members.stream()
                .filter(m -> second.getId().equals(m.get("userId")))
                .findFirst()
                .orElseThrow(() -> new AssertionError("second member missing from members"));
        assertThat("second member should remain a MEMBER",
                secondMember.get("role"), equalTo("MEMBER"));
    }

    // ── Rule: joining with a bad code does not destroy existing family ──

    @Test
    void joinFamily_invalidCode_keepsExistingFamily() {
        UserDocument user = seedUser("g-fam-14", "User 14", "user14@fam.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "My Family");

        // Attempt to join a non-existent family with a bad code.
        givenAuth(user.getId())
                .body(Map.of("inviteCode", "NONEXISTENT"))
                .post("/families/join")
                .then()
                .statusCode(400);

        // Existing family must still be intact.
        givenAuth(user.getId())
                .get("/families/" + family.getId())
                .then()
                .statusCode(200)
                .body("id", equalTo(family.getId()));
    }

    // ── Rule: already a member does not destroy existing family ──

    @Test
    void joinFamily_alreadyMember_keepsExistingFamily() {
        UserDocument admin = seedUser("g-fam-15a", "Admin 15", "admin15@fam.com");
        UserDocument member = seedUser("g-fam-15b", "Member 15", "member15@fam.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "My Family");

        // Generate an invite for the family.
        String inviteCode = givenAuth(admin.getId())
                .body(Map.of("email", "member15@fam.com"))
                .post("/families/" + family.getId() + "/invite")
                .then()
                .statusCode(200)
                .extract().path("inviteCode");

        // Member joins once.
        givenAuth(member.getId())
                .body(Map.of("inviteCode", inviteCode))
                .post("/families/join")
                .then()
                .statusCode(200);

        // Attempting to join again must be rejected without destroying the family.
        givenAuth(member.getId())
                .body(Map.of("inviteCode", inviteCode))
                .post("/families/join")
                .then()
                .statusCode(409);

        // Family must still exist with both members.
        givenAuth(admin.getId())
                .get("/families/" + family.getId() + "/members")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(2));
    }

    // ── Default categories are seeded on family creation ────────

    @Test
    void newFamily_hasDefaultCategoriesImmediately() {
        UserDocument user = seedUser("g-fam-cat", "Category User", "catseed@fam.com");

        // Both entry points — explicit create and auto-create on first login —
        // must produce a usable category list without any extra request.
        String createdFamilyId = givenAuth(user.getId())
                .body(Map.of("name", "Seeded Family"))
                .post("/families")
                .then()
                .statusCode(201)
                .extract().path("id");

        givenAuth(user.getId())
                .get("/families/" + createdFamilyId + "/categories")
                .then()
                .statusCode(200)
                .body("$.size()", greaterThanOrEqualTo(8))
                .body("name", hasItems(
                        "Groceries", "Dining", "Transport", "Housing",
                        "Bills", "Health", "Entertainment", "Shopping"));

        UserDocument freshUser = seedUser("g-fam-cat-auto", "Auto User", "autocat@fam.com");

        String autoFamilyId = givenAuth(freshUser.getId())
                .get("/families/my")
                .then()
                .statusCode(200)
                .extract().path("id");

        givenAuth(freshUser.getId())
                .get("/families/" + autoFamilyId + "/categories")
                .then()
                .statusCode(200)
                .body("$.size()", greaterThanOrEqualTo(8));
    }

    // ── Picking a category persists on the transaction ──────────

    @Test
    void assigningSeededCategoryToTransactionPersists() {
        UserDocument user = seedUser("g-fam-cat-tx", "Tx User", "cat@fam.com");

        String familyId = givenAuth(user.getId())
                .body(Map.of("name", "Category Tx Family"))
                .post("/families")
                .then()
                .statusCode(201)
                .extract().path("id");

        // An uncategorized SMS-parsed expense, as described in the issue.
        String transactionId = givenAuth(user.getId())
                .body(Map.of(
                        "amount", 4710,
                        "merchant", "AMAZON PAY IN U",
                        "type", "EXPENSE",
                        "currency", "INR",
                        "transactionDate", java.time.OffsetDateTime.now(java.time.ZoneOffset.UTC).toString()
                ))
                .post("/families/" + familyId + "/transactions")
                .then()
                .statusCode(201)
                .body("categoryId", nullValue())
                .extract().path("id");

        String groceriesId = givenAuth(user.getId())
                .get("/families/" + familyId + "/categories")
                .then()
                .statusCode(200)
                .extract().path("find { it.name == 'Groceries' }.id");

        givenAuth(user.getId())
                .body(Map.of("categoryId", groceriesId))
                .put("/families/" + familyId + "/transactions/" + transactionId)
                .then()
                .statusCode(200)
                .body("categoryId", equalTo(groceriesId));

        givenAuth(user.getId())
                .get("/families/" + familyId + "/transactions/" + transactionId)
                .then()
                .statusCode(200)
                .body("categoryId", equalTo(groceriesId));

        // The picker's "Uncategorized" row sends an empty string.
        givenAuth(user.getId())
                .body(Map.of("categoryId", ""))
                .put("/families/" + familyId + "/transactions/" + transactionId)
                .then()
                .statusCode(200)
                .body("categoryId", nullValue());
    }
}
