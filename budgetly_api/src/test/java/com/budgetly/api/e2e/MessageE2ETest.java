package com.budgetly.api.e2e;

import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.MessageDocument;
import com.budgetly.api.document.UserDocument;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.hamcrest.Matchers.*;

/**
 * E2E tests for the Message API: bulk SMS ingestion ({@code /api/v1/messages/bulk}).
 */
class MessageE2ETest extends BaseE2ETest {

    @Test
    void bulkInsertMessages_appShapedPayload_isAccepted() {
        UserDocument user = seedUser("g-msg-bulk", "Bulk User", "bulk@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Bulk Family");

        // Mirror the app's exact payload: familyGroupId at the TOP level and
        // per-message items carrying {sender, rawText, receivedAt}. Regression for
        // the 500 that blocked phone syncs (bulk items used to require familyGroupId)
        // and for the dropped-timestamp bug (receivedAt must reach the doc).
        givenAuth(user.getId())
                .body(Map.of(
                        "familyGroupId", family.getId(),
                        "messages", java.util.List.of(
                                Map.of("sender", "HDFCBK", "rawText", "Spent Rs 500 at BigBazaar on 01/10/2026",
                                        "receivedAt", "2026-10-18T09:30:00+05:30"),
                                Map.of("sender", "SBIUPI", "rawText", "Rs.250 debited for Swiggy")
                        )
                ))
                .post("/messages/bulk")
                .then()
                .statusCode(202)
                .body("status", equalTo("ACCEPTED"))
                .body("acceptedCount", equalTo(2));

        await().atMost(Duration.ofSeconds(15))
                .untilAsserted(() -> assertThat(mongoTemplate.count(
                        org.springframework.data.mongodb.core.query.Query.query(
                                org.springframework.data.mongodb.core.query.Criteria.where("userId").is(user.getId())
                                        .and("familyGroupId").is(family.getId())
                                        .and("source").is(MessageDocument.SOURCE_BULK)),
                        MessageDocument.class)).isEqualTo(2L));

        // The timestamped message must keep its real SMS receivedAt (not the
        // server's receipt time).
        await().atMost(Duration.ofSeconds(15))
                .untilAsserted(() -> {
                    MessageDocument doc = mongoTemplate.findOne(
                            org.springframework.data.mongodb.core.query.Query.query(
                                    org.springframework.data.mongodb.core.query.Criteria.where("userId").is(user.getId())
                                            .and("rawText").is("Spent Rs 500 at BigBazaar on 01/10/2026")),
                            MessageDocument.class);
                    assertThat(doc).isNotNull();
                    assertThat(doc.getReceivedAt()).isEqualTo(java.time.Instant.parse("2026-10-18T04:00:00Z"));
                });
    }
}