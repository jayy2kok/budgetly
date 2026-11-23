package com.budgetly.api.e2e;

import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.SmsPatternDocument;
import com.budgetly.api.document.UserDocument;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.hamcrest.Matchers.*;

/**
 * E2E tests for Pattern Registry API: /api/v1/patterns/*
 */
class PatternRegistryE2ETest extends BaseE2ETest {

    // ── Get All Patterns ────────────────────────────────────────

    @Test
    void getPatterns_returnsActivePatterns() {
        UserDocument user = seedUser("g-pat-1", "Pat User", "pat1@test.com");
        seedPattern("HDFCBK", "Rs.500 debited for Amazon");
        seedPattern("SBIUPI","Rs.200 sent to PhonePe");

        givenAuth(user.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(2))
                .body("sender", hasItems("HDFCBK", "SBIUPI"));
    }

    // ── Get Patterns — Delta Sync ───────────────────────────────

    @Test
    void getPatterns_withSince_returnsOnlyRecent() {
        UserDocument user = seedUser("g-pat-2", "Delta User", "delta@test.com");

        // Create an old pattern directly with a past date
        SmsPatternDocument oldPattern = SmsPatternDocument.builder()
                .sender("OLDBK")
                .extractionMap(Map.of("amount", "amount"))
                .sampleMessage("Old message")
                .usageCount(1)
                .active(true)
                .createdAt(java.time.Instant.parse("2025-01-01T00:00:00Z"))
                .build();
        patternRegistryRepository.save(oldPattern);

        // Create a recent pattern
        seedPattern("NEWBK",  "New message");

        givenAuth(user.getId())
                .queryParam("since", "2026-01-01T00:00:00Z")
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(1))
                .body("[0].sender", equalTo("NEWBK"));
    }

    // ── Get Pattern Senders ─────────────────────────────────────

    @Test
    void getPatternSenders_returnsSenderCounts() {
        UserDocument user = seedUser("g-pat-3", "Sender User", "sender@test.com");
        seedPattern("HDFCBK",  "sample1");
        seedPattern("HDFCBK","sample2");
        seedPattern("SBIUPI", "sample3");

        givenAuth(user.getId())
                .get("/patterns/senders")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(2))
                .body("find { it.sender == 'HDFCBK' }.patternCount", equalTo(2))
                .body("find { it.sender == 'SBIUPI' }.patternCount", equalTo(1));
    }

    // ── Report Pattern — Below Threshold ────────────────────────

    @Test
    void reportPattern_belowThreshold_notRemoved() {
        UserDocument user = seedUser("g-pat-4", "Report User", "report@test.com");
        SmsPatternDocument pattern = seedPattern("BADPAT","bad sample");

        givenAuth(user.getId())
                .body(Map.of("reason", "Wrong extraction", "sampleMessage", "Actual SMS text"))
                .post("/patterns/" + pattern.getId() + "/report")
                .then()
                .statusCode(200)
                .body("patternId", equalTo(pattern.getId()))
                .body("reportCount", equalTo(1))
                .body("removed", equalTo(false));
    }

    // ── Report Pattern — Reaches Threshold ──────────────────────

    @Test
    void reportPattern_reachesThreshold_autoRemoved() {
        // report-threshold is set to 3 in application-test.yml
        SmsPatternDocument pattern = seedPattern("THRESHOLD","threshold sample");

        // Report from 3 different users (threshold = 3)
        for (int i = 0; i < 3; i++) {
            UserDocument reporter = seedUser("g-pat-5-" + i, "Reporter " + i, "reporter" + i + "@test.com");
            givenAuth(reporter.getId())
                    .body(Map.of("reason", "Bad pattern", "sampleMessage", "Wrong"))
                    .post("/patterns/" + pattern.getId() + "/report");
        }

        // The last report should have triggered removal
        UserDocument checker = seedUser("g-pat-5-check", "Checker", "checker@test.com");
        givenAuth(checker.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + pattern.getId() + "' }", nullValue());
    }

    // ── Get Pattern Stats ───────────────────────────────────────

    @Test
    void getPatternStats_returnsCorrectCounts() {
        UserDocument user = seedUser("g-pat-6", "Stats User", "stats@test.com");
        seedPattern("HDFCBK",  "sample1");
        seedPattern("SBIUPI",  "sample2");

        givenAuth(user.getId())
                .get("/patterns/stats")
                .then()
                .statusCode(200)
                .body("totalPatterns", equalTo(2))
                .body("totalSenders", equalTo(2));
    }

    // ── Create Pattern ──────────────────────────────────────────

    @Test
    void createPattern_validTemplate_createsFamilyScopedPattern() {
        UserDocument user = seedUser("g-pat-7", "Author", "author@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Author Family");

        givenAuth(user.getId())
                .body(Map.of(
                        "sender", "HDFCBK",
                        "template", "Rs.{amount} debited for {merchant}",
                        "sampleMessage", "Rs.500 debited for Amazon",
                        "extractionMap", Map.of("amount", "amount", "merchant", "merchant")))
                .post("/patterns")
                .then()
                .statusCode(201)
                .body("sender", equalTo("HDFCBK"))
                .body("scope", equalTo("FAMILY"))
                .body("source", equalTo("USER"))
                .body("ownerFamilyGroupId", equalTo(family.getId()))
                .body("createdByUserId", equalTo(user.getId()))
                .body("active", equalTo(true))
                .body("usageCount", equalTo(0));
    }

    @Test
    void createPattern_templateDoesNotMatchSample_returns400() {
        UserDocument user = seedUser("g-pat-8", "Bad Author", "bad@test.com");
        seedFamily(user.getId(), "Bad Family");

        givenAuth(user.getId())
                .body(Map.of(
                        "sender", "HDFCBK",
                        "template", "Hello {amount} world",
                        "sampleMessage", "Rs.500 debited for Amazon",
                        "extractionMap", Map.of("amount", "amount")))
                .post("/patterns")
                .then()
                .statusCode(400);
    }

    @Test
    void createPattern_missingAmountTag_returns400() {
        UserDocument user = seedUser("g-pat-9", "NoAmount", "noamount@test.com");
        seedFamily(user.getId(), "NoAmount Family");

        givenAuth(user.getId())
                .body(Map.of(
                        "sender", "HDFCBK",
                        "template", "Spent {merchant}",
                        "sampleMessage", "Spent Amazon",
                        "extractionMap", Map.of("amount", "amount", "merchant", "merchant")))
                .post("/patterns")
                .then()
                .statusCode(400);
    }

    @Test
    void createPattern_duplicateTemplate_returns409() {
        UserDocument user = seedUser("g-pat-10", "Dup Author", "dup@test.com");
        FamilyGroupDocument family = seedFamily(user.getId(), "Dup Family");
        seedFamilyPattern(family.getId(), user.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 1);

        givenAuth(user.getId())
                .body(Map.of(
                        "sender", "HDFCBK",
                        "template", "Rs.{amount} debited for {merchant}",
                        "sampleMessage", "Rs.500 debited for Amazon",
                        "extractionMap", Map.of("amount", "amount", "merchant", "merchant")))
                .post("/patterns")
                .then()
                .statusCode(409);
    }

    @Test
    void createPattern_withFixedValues_returnsAndPersistsThem() {
        UserDocument user = seedUser("g-pat-fixed", "Fixed Author", "fixed@test.com");
        seedFamily(user.getId(), "Fixed Family");

        givenAuth(user.getId())
                .body(Map.of(
                        "sender", "HDFCBK",
                        "template", "Rs.{amount} debited",
                        "sampleMessage", "Rs.500 debited",
                        "extractionMap", Map.of("amount", "amount"),
                        "fixedValues", Map.of(
                                "merchant", "Pan Shop",
                                "accountLast4", "1234",
                                "bankName", "HDFC Bank",
                                "notes", "Monthly")))
                .post("/patterns")
                .then()
                .statusCode(201)
                .body("fixedValues.merchant", equalTo("Pan Shop"))
                .body("fixedValues.accountLast4", equalTo("1234"))
                .body("fixedValues.bankName", equalTo("HDFC Bank"))
                .body("fixedValues.notes", equalTo("Monthly"));
    }

    @Test
    void createPattern_fixedValueForAmount_returns400() {
        UserDocument user = seedUser("g-pat-fixed-bad", "Bad Fixed", "badfixed@test.com");
        seedFamily(user.getId(), "Bad Fixed Family");

        givenAuth(user.getId())
                .body(Map.of(
                        "sender", "HDFCBK",
                        "template", "Rs.{amount} debited",
                        "sampleMessage", "Rs.500 debited",
                        "extractionMap", Map.of("amount", "amount"),
                        "fixedValues", Map.of("amount", "500")))
                .post("/patterns")
                .then()
                .statusCode(400);
    }

    // ── Family isolation ────────────────────────────────────────

    @Test
    void getPatterns_familyScoped_notVisibleToOtherFamily() {
        UserDocument userA = seedUser("g-pat-11-a", "Fam A", "fama@test.com");
        FamilyGroupDocument famA = seedFamily(userA.getId(), "Family A");
        UserDocument userB = seedUser("g-pat-11-b", "Fam B", "famb@test.com");
        FamilyGroupDocument famB = seedFamily(userB.getId(), "Family B");

        // Global pattern is visible to everyone; family-A pattern is private.
        seedPattern("GLOBALBK", "global sample");
        seedFamilyPattern(famA.getId(), userA.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 1);

        givenAuth(userB.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(1))
                .body("[0].sender", equalTo("GLOBALBK"));

        givenAuth(userA.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(2));
    }

    // ── Update / Delete ownership ───────────────────────────────

    @Test
    void updatePattern_authorAllowed_otherFamilyForbidden() {
        UserDocument userA = seedUser("g-pat-12-a", "Owner A", "ownera@test.com");
        FamilyGroupDocument famA = seedFamily(userA.getId(), "Family A");
        UserDocument userB = seedUser("g-pat-12-b", "Intruder B", "intruder@test.com");
        seedFamily(userB.getId(), "Family B");

        SmsPatternDocument pattern = seedFamilyPattern(famA.getId(), userA.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 1);

        givenAuth(userA.getId())
                .body(Map.of(
                        "template", "Rs.{amount} debited at {merchant}",
                        "sampleMessage", "Rs.500 debited at Amazon",
                        "extractionMap", Map.of("amount", "amount", "merchant", "merchant")))
                .put("/patterns/" + pattern.getId())
                .then()
                .statusCode(200)
                .body("template", equalTo("Rs.{amount} debited at {merchant}"));

        givenAuth(userB.getId())
                .body(Map.of("template", "Hacked {amount}"))
                .put("/patterns/" + pattern.getId())
                .then()
                .statusCode(403);
    }

    // ── Global edit = hide for family + family copy ─────────────

    @Test
    void updatePattern_global_createsFamilyCopyAndHidesGlobalForCallerFamily() {
        UserDocument owner = seedUser("g-pat-global-edit", "Owner", "globaledit@test.com");
        FamilyGroupDocument famA = seedFamily(owner.getId(), "Edit Family");
        SmsPatternDocument global = globalWithTemplate();

        givenAuth(owner.getId())
                .body(Map.of(
                        "template", "Rs.{amount} debited at {merchant}",
                        "sampleMessage", "Rs.500 debited at Amazon",
                        "extractionMap", Map.of("amount", "amount", "merchant", "merchant")))
                .put("/patterns/" + global.getId())
                .then()
                .statusCode(200)
                .body("scope", equalTo("FAMILY"))
                .body("ownerFamilyGroupId", equalTo(famA.getId()))
                .body("template", equalTo("Rs.{amount} debited at {merchant}"))
                .body("active", equalTo(true));

        // The caller's family sees the copy and the global is hidden for it.
        givenAuth(owner.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + global.getId() + "' }.hiddenForFamily", equalTo(true))
                .body("find { it.scope == 'FAMILY' }.template", equalTo("Rs.{amount} debited at {merchant}"));

        // Another family keeps the untouched global and cannot see the copy.
        UserDocument other = seedUser("g-pat-global-edit-b", "Other", "globaleditb@test.com");
        seedFamily(other.getId(), "Other Family");
        givenAuth(other.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(1))
                .body("[0].id", equalTo(global.getId()))
                .body("[0].hiddenForFamily", equalTo(false))
                .body("[0].template", equalTo("Rs.{amount} debited for {merchant}"));
    }

    @Test
    void updatePattern_globalTwice_reusesTheSameFamilyCopy() {
        UserDocument owner = seedUser("g-pat-global-edit-twice", "Owner", "globaledittwice@test.com");
        seedFamily(owner.getId(), "Edit Family");
        SmsPatternDocument global = globalWithTemplate();

        String firstCopyId = givenAuth(owner.getId())
                .body(Map.of(
                        "template", "Rs.{amount} debited at {merchant}",
                        "sampleMessage", "Rs.500 debited at Amazon",
                        "extractionMap", Map.of("amount", "amount", "merchant", "merchant")))
                .put("/patterns/" + global.getId())
                .then()
                .statusCode(200)
                .extract().path("id");

        givenAuth(owner.getId())
                .body(Map.of(
                        "template", "Rs.{amount} spent at {merchant}",
                        "sampleMessage", "Rs.500 spent at Amazon",
                        "extractionMap", Map.of("amount", "amount", "merchant", "merchant")))
                .put("/patterns/" + global.getId())
                .then()
                .statusCode(200)
                .body("id", equalTo(firstCopyId))
                .body("template", equalTo("Rs.{amount} spent at {merchant}"));

        givenAuth(owner.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("findAll { it.scope == 'FAMILY' }.size()", equalTo(1));
    }

    // ── Disable / Enable ────────────────────────────────────────

    @Test
    void disableGlobalPattern_hidesItOnlyForTheCallerFamily() {
        UserDocument owner = seedUser("g-pat-disable-global", "Owner", "disableg@test.com");
        seedFamily(owner.getId(), "Disable Family");
        SmsPatternDocument global = globalWithTemplate();

        givenAuth(owner.getId())
                .post("/patterns/" + global.getId() + "/disable")
                .then()
                .statusCode(200)
                .body("hiddenForFamily", equalTo(true));

        givenAuth(owner.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + global.getId() + "' }.hiddenForFamily", equalTo(true));

        UserDocument other = seedUser("g-pat-disable-global-b", "Other", "disablegb@test.com");
        seedFamily(other.getId(), "Other Family");
        givenAuth(other.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + global.getId() + "' }.hiddenForFamily", equalTo(false));

        // Enable un-hides it for the caller's family.
        givenAuth(owner.getId())
                .post("/patterns/" + global.getId() + "/enable")
                .then()
                .statusCode(200)
                .body("hiddenForFamily", equalTo(false));

        givenAuth(owner.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + global.getId() + "' }.hiddenForFamily", equalTo(false));
    }

    @Test
    void disableAndEnableFamilyPattern_togglesActive() {
        UserDocument owner = seedUser("g-pat-disable-family", "Owner", "disablef@test.com");
        FamilyGroupDocument family = seedFamily(owner.getId(), "Family");
        SmsPatternDocument pattern = seedFamilyPattern(family.getId(), owner.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 1);

        givenAuth(owner.getId())
                .post("/patterns/" + pattern.getId() + "/disable")
                .then()
                .statusCode(200)
                .body("active", equalTo(false));

        givenAuth(owner.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + pattern.getId() + "' }.active", equalTo(false));

        givenAuth(owner.getId())
                .post("/patterns/" + pattern.getId() + "/enable")
                .then()
                .statusCode(200)
                .body("active", equalTo(true));

        givenAuth(owner.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + pattern.getId() + "' }.active", equalTo(true));
    }

    @Test
    void disableFamilyPattern_otherFamilyForbidden() {
        UserDocument owner = seedUser("g-pat-disable-own", "Owner", "disableown@test.com");
        FamilyGroupDocument family = seedFamily(owner.getId(), "Family");
        UserDocument intruder = seedUser("g-pat-disable-intruder", "Intruder", "disableintruder@test.com");
        seedFamily(intruder.getId(), "Intruder Family");
        SmsPatternDocument pattern = seedFamilyPattern(family.getId(), owner.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 1);

        givenAuth(intruder.getId())
                .post("/patterns/" + pattern.getId() + "/disable")
                .then()
                .statusCode(403);
    }

    // ── Category override ────────────────────────────────────────

    @Test
    void updatePatternCategory_familyPatternByAuthor_updatesCategory() {
        UserDocument owner = seedUser("g-pat-cat-author", "Owner", "catauthor@test.com");
        FamilyGroupDocument family = seedFamily(owner.getId(), "Cat Family");
        SmsPatternDocument pattern = seedFamilyPattern(family.getId(), owner.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 1);

        givenAuth(owner.getId())
                .body(Map.of("categoryName", "Travel"))
                .patch("/patterns/" + pattern.getId() + "/category")
                .then()
                .statusCode(200)
                .body("id", equalTo(pattern.getId()))
                .body("scope", equalTo("FAMILY"))
                .body("categoryName", equalTo("Travel"));

        givenAuth(owner.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + pattern.getId() + "' }.categoryName", equalTo("Travel"));
    }

    @Test
    void updatePatternCategory_unknownPattern_returns404() {
        UserDocument user = seedUser("g-pat-cat-404", "User", "cat404@test.com");

        givenAuth(user.getId())
                .body(Map.of("categoryName", "Travel"))
                .patch("/patterns/does-not-exist/category")
                .then()
                .statusCode(404);
    }

    @Test
    void updatePatternCategory_familyPatternNonAuthor_returns403() {
        UserDocument owner = seedUser("g-pat-cat-owner", "Owner", "catowner@test.com");
        FamilyGroupDocument family = seedFamily(owner.getId(), "Cat Family");
        SmsPatternDocument pattern = seedFamilyPattern(family.getId(), owner.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 1);

        UserDocument member = seedUser("g-pat-cat-member", "Member", "catmember@test.com");
        seedMember(member.getId(), family.getId());

        givenAuth(member.getId())
                .body(Map.of("categoryName", "Travel"))
                .patch("/patterns/" + pattern.getId() + "/category")
                .then()
                .statusCode(403);
    }

    @Test
    void updatePatternCategory_global_createsFamilyCopyWithCategory() {
        UserDocument owner = seedUser("g-pat-cat-global", "Owner", "catglobal@test.com");
        FamilyGroupDocument family = seedFamily(owner.getId(), "Cat Family");
        SmsPatternDocument global = globalWithTemplate();

        givenAuth(owner.getId())
                .body(Map.of("categoryName", "Travel"))
                .patch("/patterns/" + global.getId() + "/category")
                .then()
                .statusCode(200)
                .body("scope", equalTo("FAMILY"))
                .body("ownerFamilyGroupId", equalTo(family.getId()))
                .body("categoryName", equalTo("Travel"))
                .body("active", equalTo(true));

        // The shared global is not mutated but is hidden for the caller's family.
        givenAuth(owner.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + global.getId() + "' }.hiddenForFamily", equalTo(true))
                .body("find { it.scope == 'FAMILY' }.categoryName", equalTo("Travel"));

        // A different family still matches the untouched global.
        UserDocument other = seedUser("g-pat-cat-global-b", "Other", "catglobalb@test.com");
        seedFamily(other.getId(), "Other Family");
        givenAuth(other.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + global.getId() + "' }.hiddenForFamily", equalTo(false))
                .body("find { it.id == '" + global.getId() + "' }.categoryName", nullValue());
    }

    // ── Report dedupe ────────────────────────────────────────────

    @Test
    void reportPattern_sameUserTwice_countsOnce() {
        UserDocument reporter = seedUser("g-pat-dup-report", "Reporter", "dupreport@test.com");
        SmsPatternDocument pattern = seedPattern("DUPLICATE", "duplicate sample");

        givenAuth(reporter.getId())
                .body(Map.of("reason", "Bad", "sampleMessage", "SMS"))
                .post("/patterns/" + pattern.getId() + "/report")
                .then()
                .statusCode(200)
                .body("reportCount", equalTo(1));

        givenAuth(reporter.getId())
                .body(Map.of("reason", "Still bad", "sampleMessage", "SMS"))
                .post("/patterns/" + pattern.getId() + "/report")
                .then()
                .statusCode(200)
                .body("reportCount", equalTo(1))
                .body("removed", equalTo(false));
    }

    // ── Promote duplicate ────────────────────────────────────────

    @Test
    void promotePattern_activeGlobalDuplicate_returns409() {
        UserDocument admin = seedUser("g-pat-promote-dup", "Admin", "promotedup@test.com");
        FamilyGroupDocument family = seedFamily(admin.getId(), "Promote Family");
        SmsPatternDocument familyPattern = seedFamilyPattern(family.getId(), admin.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 5);
        // An active GLOBAL already serves this sender+template.
        SmsPatternDocument global = SmsPatternDocument.builder()
                .sender("HDFCBK")
                .template("Rs.{amount} debited for {merchant}")
                .sampleMessage("Rs.500 debited for Amazon")
                .extractionMap(Map.of("amount", "amount", "merchant", "merchant"))
                .usageCount(10)
                .active(true)
                .scope(SmsPatternDocument.SCOPE_GLOBAL)
                .source(SmsPatternDocument.SOURCE_LLM)
                .createdAt(java.time.Instant.now())
                .build();
        patternRegistryRepository.save(global);

        givenAuth(admin.getId())
                .post("/patterns/" + familyPattern.getId() + "/promote")
                .then()
                .statusCode(409);
    }

    // ── Enable a hidden GLOBAL deactivates the family copy ───────

    @Test
    void enablePattern_globalWithFamilyCopy_deactivatesTheCopy() {
        UserDocument owner = seedUser("g-pat-enable-copy", "Owner", "enablecopy@test.com");
        FamilyGroupDocument family = seedFamily(owner.getId(), "Enable Family");
        SmsPatternDocument global = globalWithTemplate();

        // Edit the global: creates a family copy and hides the global.
        String copyId = givenAuth(owner.getId())
                .body(Map.of(
                        "template", "Rs.{amount} debited at {merchant}",
                        "sampleMessage", "Rs.500 debited at Amazon",
                        "extractionMap", Map.of("amount", "amount", "merchant", "merchant")))
                .put("/patterns/" + global.getId())
                .then()
                .statusCode(200)
                .extract().path("id");

        // Re-enable the global: the copy stops shadowing it.
        givenAuth(owner.getId())
                .post("/patterns/" + global.getId() + "/enable")
                .then()
                .statusCode(200)
                .body("hiddenForFamily", equalTo(false));

        givenAuth(owner.getId())
                .get("/patterns")
                .then()
                .statusCode(200)
                .body("find { it.id == '" + global.getId() + "' }.hiddenForFamily", equalTo(false))
                .body("find { it.id == '" + copyId + "' }.active", equalTo(false));
    }

    /** Seeds an active GLOBAL pattern with a usable template (seedPattern has none). */
    private SmsPatternDocument globalWithTemplate() {
        SmsPatternDocument global = SmsPatternDocument.builder()
                .sender("HDFCBK")
                .template("Rs.{amount} debited for {merchant}")
                .sampleMessage("Rs.500 debited for Amazon")
                .extractionMap(Map.of("amount", "amount", "merchant", "merchant"))
                .usageCount(5)
                .active(true)
                .reportCount(0)
                .scope(SmsPatternDocument.SCOPE_GLOBAL)
                .source(SmsPatternDocument.SOURCE_LLM)
                .createdAt(java.time.Instant.now())
                .build();
        return patternRegistryRepository.save(global);
    }

    // ── Promote ─────────────────────────────────────────────────

    @Test
    void promotePattern_belowThreshold_returns409() {
        UserDocument admin = seedUser("g-pat-14", "Admin", "admin@test.com");
        FamilyGroupDocument famA = seedFamily(admin.getId(), "Family A");
        SmsPatternDocument pattern = seedFamilyPattern(famA.getId(), admin.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 1);

        givenAuth(admin.getId())
                .post("/patterns/" + pattern.getId() + "/promote")
                .then()
                .statusCode(409);
    }

    @Test
    void promotePattern_aboveThreshold_setsGlobal() {
        UserDocument admin = seedUser("g-pat-15", "Admin2", "admin2@test.com");
        FamilyGroupDocument famA = seedFamily(admin.getId(), "Family A");
        SmsPatternDocument pattern = seedFamilyPattern(famA.getId(), admin.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 5);

        givenAuth(admin.getId())
                .post("/patterns/" + pattern.getId() + "/promote")
                .then()
                .statusCode(200)
                .body("scope", equalTo("GLOBAL"))
                .body("ownerFamilyGroupId", nullValue());
    }

    @Test
    void promotePattern_nonAdmin_returns403() {
        UserDocument admin = seedUser("g-pat-16-a", "Admin", "padmin@test.com");
        FamilyGroupDocument famA = seedFamily(admin.getId(), "Family A");
        SmsPatternDocument pattern = seedFamilyPattern(famA.getId(), admin.getId(), "HDFCBK",
                "Rs.{amount} debited for {merchant}", "Rs.500 debited for Amazon", 5);

        UserDocument member = seedUser("g-pat-16-b", "Member", "pmember@test.com");
        seedMember(member.getId(), famA.getId());

        givenAuth(member.getId())
                .post("/patterns/" + pattern.getId() + "/promote")
                .then()
                .statusCode(403);
    }
}
