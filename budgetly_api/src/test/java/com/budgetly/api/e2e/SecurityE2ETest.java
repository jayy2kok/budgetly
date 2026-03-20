package com.budgetly.api.e2e;

import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.UserDocument;
import io.restassured.RestAssured;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * E2E tests for security enforcement and cross-cutting concerns.
 */
class SecurityE2ETest extends BaseE2ETest {

    // ── No Token → Rejected ─────────────────────────────────────

    @Test
    void protectedEndpoint_noToken_returnsUnauthorized() {
        givenNoAuth()
                .get("/auth/me")
                .then()
                .statusCode(anyOf(is(401), is(403)));
    }

    @Test
    void protectedEndpoint_noToken_familyEndpoint() {
        givenNoAuth()
                .get("/families/some-id")
                .then()
                .statusCode(anyOf(is(401), is(403)));
    }

    @Test
    void protectedEndpoint_noToken_transactionEndpoint() {
        givenNoAuth()
                .get("/families/some-fid/transactions")
                .then()
                .statusCode(anyOf(is(401), is(403)));
    }

    // ── Malformed Token → Rejected ──────────────────────────────

    @Test
    void protectedEndpoint_malformedToken_returnsUnauthorized() {
        RestAssured.given()
                .contentType("application/json")
                .header("Authorization", "Bearer this.is.not.a.valid.jwt")
                .basePath("/api/v1")
                .get("/auth/me")
                .then()
                .statusCode(anyOf(is(401), is(403)));
    }

    @Test
    void protectedEndpoint_expiredFormatToken_returnsUnauthorized() {
        RestAssured.given()
                .contentType("application/json")
                .header("Authorization", "Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0Iiwi" +
                        "aWF0IjoxNjAwMDAwMDAwLCJleHAiOjE2MDAwMDAwMDF9.invalid-signature")
                .basePath("/api/v1")
                .get("/auth/me")
                .then()
                .statusCode(anyOf(is(401), is(403)));
    }

    // ── Public Endpoints Accessible ─────────────────────────────

    @Test
    void healthEndpoint_noAuth_returns200() {
        RestAssured.given()
                .basePath("")
                .get("/actuator/health")
                .then()
                .statusCode(200)
                .body("status", equalTo("UP"));
    }

    @Test
    void googleSignIn_noAuth_isPublic() {
        // POST /auth/google is public (no auth required)
        // We don't send a valid body, but it should NOT return 401/403
        givenNoAuth()
                .body(Map.of("idToken", "any-token"))
                .post("/auth/google")
                .then()
                // Should get 400 (bad token) not 401/403
                .statusCode(not(anyOf(is(401), is(403))));
    }

    // ── Cross-Family Isolation ──────────────────────────────────

    @Test
    void crossFamilyIsolation_cannotAccessOtherFamilyData() {
        UserDocument userA = seedUser("g-sec-1a", "User A", "a@sec.com");
        UserDocument userB = seedUser("g-sec-1b", "User B", "b@sec.com");
        FamilyGroupDocument familyA = seedFamily(userA.getId(), "Family A");
        FamilyGroupDocument familyB = seedFamily(userB.getId(), "Family B");

        // User A tries to access Family B
        givenAuth(userA.getId())
                .get("/families/" + familyB.getId())
                .then()
                .statusCode(403);

        // User B tries to list transactions in Family A
        givenAuth(userB.getId())
                .get("/families/" + familyA.getId() + "/transactions")
                .then()
                .statusCode(403);

        // User A tries to create category in Family B
        givenAuth(userA.getId())
                .body(Map.of("name", "Hack", "icon", "💀"))
                .post("/families/" + familyB.getId() + "/categories")
                .then()
                .statusCode(403);
    }

    @Test
    void crossFamilyIsolation_cannotAccessOtherFamilyDashboard() {
        UserDocument userA = seedUser("g-sec-2a", "User 2A", "2a@sec.com");
        UserDocument userB = seedUser("g-sec-2b", "User 2B", "2b@sec.com");
        FamilyGroupDocument familyA = seedFamily(userA.getId(), "Family 2A");

        givenAuth(userB.getId())
                .get("/families/" + familyA.getId() + "/dashboard")
                .then()
                .statusCode(403);

        givenAuth(userB.getId())
                .get("/families/" + familyA.getId() + "/budget/summary")
                .then()
                .statusCode(403);
    }
}
