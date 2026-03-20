package com.budgetly.api.e2e;

import com.budgetly.api.document.UserDocument;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.hamcrest.Matchers.*;

/**
 * E2E tests for Auth API: /api/v1/auth/*
 */
class AuthE2ETest extends BaseE2ETest {

        // ── Google Sign-In ──────────────────────────────────────────

        @Test
        void googleSignIn_validToken_returnsJwt() {
                // Configure test verifier to return a valid payload
                googleTokenVerifier.setNextPayload(createPayload(
                                "google-123", "test@example.com", "Test User", "https://example.com/photo.jpg"));

                givenNoAuth()
                                .body(Map.of("idToken", "valid-google-id-token"))
                                .post("/auth/google")
                                .then()
                                .statusCode(200)
                                .body("accessToken", notNullValue())
                                .body("refreshToken", notNullValue())
                                .body("expiresIn", greaterThan(0))
                                .body("user.email", equalTo("test@example.com"))
                                .body("user.displayName", equalTo("Test User"));
        }

        @Test
        void googleSignIn_invalidToken_returns400() {
                // Verifier returns null (invalid token) — this is the default after
                // clearPayload()
                givenNoAuth()
                                .body(Map.of("idToken", "invalid-token"))
                                .post("/auth/google")
                                .then()
                                .statusCode(400);
        }

        @Test
        void googleSignIn_existingUser_updatesProfile() {
                // Create existing user
                seedUser("google-456", "Old Name", "user@example.com");

                // Verifier returns updated name
                googleTokenVerifier.setNextPayload(createPayload(
                                "google-456", "user@example.com", "New Name", "https://example.com/new-photo.jpg"));

                givenNoAuth()
                                .body(Map.of("idToken", "some-token"))
                                .post("/auth/google")
                                .then()
                                .statusCode(200)
                                .body("user.displayName", equalTo("New Name"));
        }

        // ── Refresh Token ───────────────────────────────────────────

        @Test
        void refreshToken_validRefresh_returnsNewAccessToken() {
                UserDocument user = seedUser("google-rt-1", "Refresh User", "refresh@example.com");
                String refreshToken = jwtTokenProvider.generateRefreshToken(user.getId());

                givenNoAuth()
                                .body(Map.of("refreshToken", refreshToken))
                                .post("/auth/refresh")
                                .then()
                                .body("accessToken", notNullValue())
                                .body("refreshToken", notNullValue())
                                .body("user.email", equalTo("refresh@example.com"));
        }

        @Test
        void refreshToken_invalidToken_returns400() {
                givenNoAuth()
                                .body(Map.of("refreshToken", "totally-invalid-jwt"))
                                .post("/auth/refresh")
                                .then()
                                .statusCode(400);
        }

        // ── Get Current User ────────────────────────────────────────

        @Test
        void getCurrentUser_authenticated_returnsProfile() {
                UserDocument user = seedUser("google-me-1", "Me User", "me@example.com");

                givenAuth(user.getId())
                                .get("/auth/me")
                                .then()
                                .statusCode(200)
                                .body("id", equalTo(user.getId()))
                                .body("email", equalTo("me@example.com"))
                                .body("displayName", equalTo("Me User"));
        }

        @Test
        void getCurrentUser_noAuth_returns401or403() {
                givenNoAuth()
                                .get("/auth/me")
                                .then()
                                .statusCode(anyOf(is(401), is(403)));
        }

        // ── Helper ──────────────────────────────────────────────────

        private GoogleIdToken.Payload createPayload(String subject, String email,
                        String name, String picture) {
                GoogleIdToken.Payload payload = new GoogleIdToken.Payload();
                payload.setSubject(subject);
                payload.setEmail(email);
                payload.set("name", name);
                payload.set("picture", picture);
                return payload;
        }
}
