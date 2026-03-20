package com.budgetly.api.e2e;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.UserDocument;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.hamcrest.Matchers.*;

/**
 * E2E tests for Category API: /api/v1/families/{fid}/categories/*
 */
class CategoryE2ETest extends BaseE2ETest {

    // ── Create Category ─────────────────────────────────────────

    @Test
    void createCategory_asAdmin_returns201() {
        UserDocument admin = seedUser("g-cat-1", "Cat Admin", "catadmin@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Cat Family");

        givenAuth(admin.getId())
                .body(Map.of(
                        "name", "Groceries",
                        "icon", "🛒",
                        "budgetLimit", 8000,
                        "color", "#10b981",
                        "sortOrder", 1
                ))
                .post("/families/" + family.getId() + "/categories")
                .then()
                .statusCode(201)
                .body("name", equalTo("Groceries"))
                .body("icon", equalTo("🛒"))
                .body("budgetLimit", equalTo(8000.0F))
                .body("id", notNullValue());
    }

    @Test
    void createCategory_asMember_notAdmin_returns403() {
        UserDocument admin = seedUser("g-cat-2a", "Admin", "a-cat@test.com");
        UserDocument member = seedUser("g-cat-2b", "Member", "m-cat@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Restricted");
        seedMember(member.getId(), family.getId());

        givenAuth(member.getId())
                .body(Map.of("name", "Dining", "icon", "🍕"))
                .post("/families/" + family.getId() + "/categories")
                .then()
                .statusCode(403);
    }

    // ── List Categories ─────────────────────────────────────────

    @Test
    void listCategories_returnsSeedCategories() {
        UserDocument admin = seedUser("g-cat-3", "List Admin", "listcat@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "List Family");
        seedCategory(family.getId(), "Transport", "🚗", 5000);
        seedCategory(family.getId(), "Housing", "🏠", 15000);

        givenAuth(admin.getId())
                .get("/families/" + family.getId() + "/categories")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(2))
                .body("name", hasItems("Transport", "Housing"));
    }

    // ── Update Category ─────────────────────────────────────────

    @Test
    void updateCategory_changesFields() {
        UserDocument admin = seedUser("g-cat-4", "Update Admin", "upcat@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Update Family");
        CategoryDocument category = seedCategory(family.getId(), "Old Name", "📦", 3000);

        givenAuth(admin.getId())
                .body(Map.of(
                        "name", "New Name",
                        "budgetLimit", 5000
                ))
                .put("/families/" + family.getId() + "/categories/" + category.getId())
                .then()
                .statusCode(200)
                .body("name", equalTo("New Name"))
                .body("budgetLimit", equalTo(5000.0F));
    }

    // ── Delete Category ─────────────────────────────────────────

    @Test
    void deleteCategory_asAdmin_returns204() {
        UserDocument admin = seedUser("g-cat-5", "Del Admin", "delcat@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Del Family");
        CategoryDocument category = seedCategory(family.getId(), "To Delete", "🗑", 0);

        givenAuth(admin.getId())
                .delete("/families/" + family.getId() + "/categories/" + category.getId())
                .then()
                .statusCode(204);

        // Verify it's gone
        givenAuth(admin.getId())
                .get("/families/" + family.getId() + "/categories")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(0));
    }

    // ── Non-Member Access ───────────────────────────────────────

    @Test
    void listCategories_nonMember_returns403() {
        UserDocument admin = seedUser("g-cat-6a", "Admin 6", "admin6@cat.com");
        UserDocument outsider = seedUser("g-cat-6b", "Outsider", "outsider6@cat.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Private Cat Family");
        seedCategory(family.getId(), "Secret", "🔒", 0);

        givenAuth(outsider.getId())
                .get("/families/" + family.getId() + "/categories")
                .then()
                .statusCode(403);
    }
}
