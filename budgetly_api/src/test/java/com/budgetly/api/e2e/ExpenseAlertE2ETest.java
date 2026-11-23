package com.budgetly.api.e2e;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.UserDocument;
import com.budgetly.api.push.ExpenseAlertNotifier;
import com.budgetly.api.push.PushMessage;

/**
 * E2E tests for expense-alert push fan-out triggered by transaction creation.
 */
class ExpenseAlertE2ETest extends BaseE2ETest {

    @Test
    void createExpense_alertsEnabled_pushesToOtherMembersDevices() {
        UserDocument admin = seedUser("g-alert-1a", "Asha", "asha@test.com");
        UserDocument member = seedUser("g-alert-1b", "Ravi", "ravi@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Sharma Family");
        seedMember(member.getId(), family.getId());
        registerDevice(member.getId(), "member-token-1");

        String transactionId = createExpense(admin.getId(), family.getId(), 250.5, "Swiggy");

        assertEquals(1, pushNotificationService.sent().size());
        PushMessage message = pushNotificationService.sent().getFirst();
        assertEquals("member-token-1", message.token());
        assertEquals("New expense in Sharma Family", message.title());
        assertTrue(message.body().contains("Asha"));
        assertTrue(message.body().contains("250.50 INR"));
        assertTrue(message.body().contains("Swiggy"));
        assertEquals(ExpenseAlertNotifier.DATA_TYPE, message.data().get(ExpenseAlertNotifier.KEY_TYPE));
        assertEquals(transactionId, message.data().get(ExpenseAlertNotifier.KEY_TRANSACTION_ID));
        assertEquals(family.getId(), message.data().get(ExpenseAlertNotifier.KEY_FAMILY_GROUP_ID));
    }

    @Test
    void createExpense_alertsDisabled_sendsNothing() {
        UserDocument admin = seedUser("g-alert-2a", "Asha", "asha2@test.com");
        UserDocument member = seedUser("g-alert-2b", "Ravi", "ravi2@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Quiet Family");
        family.setExpenseAlertsEnabled(false);
        familyGroupRepository.save(family);
        seedMember(member.getId(), family.getId());
        registerDevice(member.getId(), "member-token-2");

        createExpense(admin.getId(), family.getId(), 99.0, "Cafe");

        assertTrue(pushNotificationService.sent().isEmpty());
    }

    @Test
    void createIncome_neverSendsExpenseAlert() {
        UserDocument admin = seedUser("g-alert-3a", "Asha", "asha3@test.com");
        UserDocument member = seedUser("g-alert-3b", "Ravi", "ravi3@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Income Family");
        seedMember(member.getId(), family.getId());
        registerDevice(member.getId(), "member-token-3");

        givenAuth(admin.getId())
                .body(Map.of(
                        "amount", 50000.0,
                        "merchant", "Employer",
                        "type", "INCOME",
                        "transactionDate", OffsetDateTime.now(ZoneOffset.UTC).toString()))
                .post("/families/" + family.getId() + "/transactions")
                .then()
                .statusCode(201);

        assertTrue(pushNotificationService.sent().isEmpty());
    }

    @Test
    void createExpense_doesNotNotifyTheCreator() {
        UserDocument admin = seedUser("g-alert-4a", "Asha", "asha4@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Solo Family");
        registerDevice(admin.getId(), "admin-token-4");

        createExpense(admin.getId(), family.getId(), 40.0, "Chai");

        assertTrue(pushNotificationService.sent().isEmpty());
    }

    @Test
    void createExpense_memberWithoutRegisteredDevice_isHandledGracefully() {
        UserDocument admin = seedUser("g-alert-5a", "Asha", "asha5@test.com");
        UserDocument member = seedUser("g-alert-5b", "Ravi", "ravi5@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "NoToken Family");
        seedMember(member.getId(), family.getId());

        createExpense(admin.getId(), family.getId(), 75.0, "Metro");

        assertTrue(pushNotificationService.sent().isEmpty());
    }

    private void registerDevice(String userId, String token) {
        givenAuth(userId)
                .body(Map.of("token", token, "platform", "ANDROID"))
                .post("/devices")
                .then()
                .statusCode(204);
    }

    private String createExpense(String userId, String familyId, double amount, String merchant) {
        return givenAuth(userId)
                .body(Map.of(
                        "amount", amount,
                        "merchant", merchant,
                        "type", "EXPENSE",
                        "currency", "INR",
                        "transactionDate", OffsetDateTime.now(ZoneOffset.UTC).toString()))
                .post("/families/" + familyId + "/transactions")
                .then()
                .statusCode(201)
                .extract().path("id");
    }
}
