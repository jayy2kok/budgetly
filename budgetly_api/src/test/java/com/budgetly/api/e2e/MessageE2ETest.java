package com.budgetly.api.e2e;

import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.document.UserDocument;
import com.budgetly.api.llm.LlmAnalysisResult;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.hamcrest.Matchers.*;

/**
 * E2E tests for Message API: /api/v1/messages/*
 */
class MessageE2ETest extends BaseE2ETest {

    // ── Process Message — Financial ─────────────────────────────

    @Test
    void processMessage_financialSms_createsTransaction() {
        UserDocument user = seedUser("g-msg-1", "Msg User", "msg1@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Msg Family");

        // Configure LLM to return a financial result
        llmProvider.setNextResult(
                LlmAnalysisResult.builder()
                        .financial(true)
                        .amount(1500.0)
                        .merchant("Amazon")
                        .transactionType("EXPENSE")
                        .generatedRegex("(?<amount>\\d+).*(?<merchant>\\w+)")
                        .extractionMap(Map.of("amount", "amount", "merchant", "merchant", "timestamp", "timestamp"))
                        .build()
        );

        givenAuth(user.getId())
                .body(Map.of(
                        "familyGroupId", family.getId(),
                        "sender", "HDFCBK",
                        "rawText", "Rs.1500 debited from a/c XX1234 for Amazon on 13-03-26"
                ))
                .post("/messages/process")
                .then()
                .statusCode(200)
                .body("isFinancial", equalTo(true))
                .body("transactionId", notNullValue())
                .body("parsedData.amount", equalTo(1500.0F))
                .body("parsedData.merchant", equalTo("Amazon"));
    }

    // ── Process Message — Non-Financial ─────────────────────────

    @Test
    void processMessage_nonFinancialSms_marksIgnored() {
        UserDocument user = seedUser("g-msg-2", "Msg User 2", "msg2@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Msg Family 2");

        // Default LLM result is non-financial (after resetResult())

        givenAuth(user.getId())
                .body(Map.of(
                        "familyGroupId", family.getId(),
                        "sender", "PROMO",
                        "rawText", "50% OFF on all electronics! Shop now!"
                ))
                .post("/messages/process")
                .then()
                .statusCode(200)
                .body("isFinancial", equalTo(false))
                .body("message.status", equalTo("IGNORED"));
    }

    // ── Get Pending Messages ────────────────────────────────────

    @Test
    void getPendingMessages_returnsOnlyPending() {
        UserDocument user = seedUser("g-msg-3", "Msg User 3", "msg3@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Msg Family 3");
        seedMessage(user.getId(), family.getId(), "SBIUPI", "Rs.200 sent to Flipkart", "PENDING");
        seedMessage(user.getId(), family.getId(), "PROMO", "Win a prize!", "IGNORED");

        givenAuth(user.getId())
                .get("/messages/pending")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(1))
                .body("[0].sender", equalTo("SBIUPI"));
    }

    // ── Get Ignored Messages ────────────────────────────────────

    @Test
    void getIgnoredMessages_returnsIgnoredAndRejected() {
        UserDocument user = seedUser("g-msg-4", "Msg User 4", "msg4@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Msg Family 4");
        seedMessage(user.getId(), family.getId(), "PROMO", "Flash sale!", "IGNORED");
        seedMessage(user.getId(), family.getId(), "OTP", "Your OTP is 1234", "REJECTED");
        seedMessage(user.getId(), family.getId(), "HDFCBK", "Rs.500 credited", "PENDING");

        givenAuth(user.getId())
                .get("/messages/ignored")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(2));
    }

    // ── Confirm Message ─────────────────────────────────────────

    @Test
    void confirmMessage_createsTransaction() {
        UserDocument user = seedUser("g-msg-5", "Msg User 5", "msg5@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Msg Family 5");
        MessageDocument msg = seedMessage(user.getId(), family.getId(), "ICICIBK",
                "Rs.3000 debited for Flipkart", "PENDING");

        // Add parsed data so confirm can build a transaction
        msg.setParsedTransactionData(Map.of("amount", 3000.0, "merchant", "Flipkart"));
        messageRepository.save(msg);

        givenAuth(user.getId())
                .post("/messages/" + msg.getId() + "/confirm")
                .then()
                .statusCode(200)
                .body("amount", equalTo(3000.0F))
                .body("merchant", equalTo("Flipkart"));
    }

    // ── Reject Message ──────────────────────────────────────────

    @Test
    void rejectMessage_changesStatusToRejected() {
        UserDocument user = seedUser("g-msg-6", "Msg User 6", "msg6@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Msg Family 6");
        MessageDocument msg = seedMessage(user.getId(), family.getId(), "SPAM",
                "You have won a lottery!", "PENDING");

        givenAuth(user.getId())
                .post("/messages/" + msg.getId() + "/reject")
                .then()
                .statusCode(200)
                .body("status", equalTo("REJECTED"));
    }

    // ── Restore Message ─────────────────────────────────────────

    @Test
    void restoreMessage_changesStatusToPending() {
        UserDocument user = seedUser("g-msg-7", "Msg User 7", "msg7@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Msg Family 7");
        MessageDocument msg = seedMessage(user.getId(), family.getId(), "HDFCBK",
                "Rs.200 debited", "REJECTED");

        givenAuth(user.getId())
                .post("/messages/" + msg.getId() + "/restore")
                .then()
                .statusCode(200)
                .body("status", equalTo("PENDING"));
    }
}
