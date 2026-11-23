package com.budgetly.api.e2e;

import static org.hamcrest.Matchers.anyOf;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.budgetly.api.document.DeviceTokenDocument;
import com.budgetly.api.document.UserDocument;

/**
 * E2E tests for device-token registration: POST/DELETE /api/v1/devices.
 */
class DeviceE2ETest extends BaseE2ETest {

    @Test
    void registerDevice_persistsTokenForCaller() {
        UserDocument user = seedUser("g-dev-1", "Device User", "device1@test.com");

        givenAuth(user.getId())
                .body(Map.of("token", "fcm-token-abc", "platform", "ANDROID", "deviceId", "pixel-9a"))
                .post("/devices")
                .then()
                .statusCode(204);

        DeviceTokenDocument stored = deviceTokenRepository.findByToken("fcm-token-abc").orElseThrow();
        assertEquals(user.getId(), stored.getUserId());
        assertEquals("ANDROID", stored.getPlatform());
        assertEquals("pixel-9a", stored.getDeviceId());
    }

    @Test
    void registerDevice_sameTokenTwice_updatesInsteadOfDuplicating() {
        UserDocument user = seedUser("g-dev-2", "Device User", "device2@test.com");

        givenAuth(user.getId())
                .body(Map.of("token", "fcm-token-dup", "platform", "ANDROID"))
                .post("/devices")
                .then()
                .statusCode(204);
        givenAuth(user.getId())
                .body(Map.of("token", "fcm-token-dup", "platform", "IOS"))
                .post("/devices")
                .then()
                .statusCode(204);

        assertEquals(1, deviceTokenRepository.findByUserId(user.getId()).size());
        assertEquals("IOS", deviceTokenRepository.findByToken("fcm-token-dup").orElseThrow().getPlatform());
    }

    @Test
    void registerDevice_missingToken_returns400() {
        UserDocument user = seedUser("g-dev-3", "Device User", "device3@test.com");

        givenAuth(user.getId())
                .body(Map.of("platform", "ANDROID"))
                .post("/devices")
                .then()
                .statusCode(400)
                .body("message", containsString("token"));
    }

    @Test
    void registerDevice_missingPlatform_returns400() {
        UserDocument user = seedUser("g-dev-4", "Device User", "device4@test.com");

        givenAuth(user.getId())
                .body(Map.of("token", "fcm-token-noplatform"))
                .post("/devices")
                .then()
                .statusCode(400)
                .body("message", containsString("platform"));
    }

    @Test
    void registerDevice_unauthenticated_returns401() {
        givenNoAuth()
                .body(Map.of("token", "fcm-token-anon", "platform", "ANDROID"))
                .post("/devices")
                .then()
                .statusCode(anyOf(is(401), is(403)));
    }

    @Test
    void unregisterDevice_removesOwnToken() {
        UserDocument user = seedUser("g-dev-5", "Device User", "device5@test.com");
        givenAuth(user.getId())
                .body(Map.of("token", "fcm-token-del", "platform", "ANDROID"))
                .post("/devices")
                .then()
                .statusCode(204);

        givenAuth(user.getId())
                .delete("/devices/fcm-token-del")
                .then()
                .statusCode(204);

        assertTrue(deviceTokenRepository.findByToken("fcm-token-del").isEmpty());
    }

    @Test
    void unregisterDevice_unknownToken_isIdempotent() {
        UserDocument user = seedUser("g-dev-6", "Device User", "device6@test.com");

        givenAuth(user.getId())
                .delete("/devices/never-registered")
                .then()
                .statusCode(204);
    }

    @Test
    void unregisterDevice_cannotRemoveAnotherUsersToken() {
        UserDocument owner = seedUser("g-dev-7a", "Owner", "owner7@test.com");
        UserDocument other = seedUser("g-dev-7b", "Other", "other7@test.com");
        givenAuth(owner.getId())
                .body(Map.of("token", "fcm-token-owned", "platform", "ANDROID"))
                .post("/devices")
                .then()
                .statusCode(204);

        givenAuth(other.getId())
                .delete("/devices/fcm-token-owned")
                .then()
                .statusCode(204);

        assertTrue(deviceTokenRepository.findByToken("fcm-token-owned").isPresent());
    }
}
