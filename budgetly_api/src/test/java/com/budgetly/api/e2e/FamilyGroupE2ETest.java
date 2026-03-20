package com.budgetly.api.e2e;

import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.FamilyMemberDocument;
import com.budgetly.api.document.UserDocument;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static io.restassured.RestAssured.given;
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
}
