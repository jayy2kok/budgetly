package com.budgetly.api.e2e;

import com.budgetly.api.document.*;
import com.budgetly.api.repository.*;
import com.budgetly.api.security.JwtTokenProvider;
import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import io.restassured.specification.RequestSpecification;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Import;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.Instant;
import java.util.Map;

/**
 * Base class for all E2E tests.
 * Uses Flapdoodle embedded MongoDB (no Docker required) and a full
 * Spring Boot server on a random port. RestAssured is configured
 * to hit the real HTTP endpoints.
 *
 * External services (GoogleTokenVerifier, LlmProvider) are replaced
 * with real test implementations via TestBeanConfig — no Mockito
 * needed, which avoids Byte Buddy compatibility issues on Java 25+.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Import(TestBeanConfig.class)
public abstract class BaseE2ETest {

    @LocalServerPort
    protected int port;

    @Autowired
    protected JwtTokenProvider jwtTokenProvider;

    @Autowired
    protected MongoTemplate mongoTemplate;

    @Autowired
    protected TestGoogleTokenVerifier googleTokenVerifier;

    @Autowired
    protected TestLlmProvider llmProvider;

    // ── Repositories for direct seeding ────────────────────────
    @Autowired
    protected UserRepository userRepository;

    @Autowired
    protected FamilyGroupRepository familyGroupRepository;

    @Autowired
    protected FamilyMemberRepository familyMemberRepository;

    @Autowired
    protected CategoryRepository categoryRepository;

    @Autowired
    protected TransactionRepository transactionRepository;

    @Autowired
    protected MessageRepository messageRepository;

    @Autowired
    protected PatternRegistryRepository patternRegistryRepository;

    @Autowired
    protected RejectedPatternRepository rejectedPatternRepository;

    // ── Setup ──────────────────────────────────────────────────

    @BeforeEach
    void baseSetUp() {
        RestAssured.port = port;
        RestAssured.basePath = "/api/v1";

        // Reset test doubles between tests
        googleTokenVerifier.clearPayload();
        llmProvider.resetResult();

        // Clean all collections for test isolation
        mongoTemplate.getCollectionNames()
                .forEach(mongoTemplate::dropCollection);
    }

    // ── Auth Helpers ───────────────────────────────────────────

    /** Generate a valid JWT access token for the given user id. */
    protected String getAuthToken(String userId) {
        return jwtTokenProvider.generateAccessToken(userId);
    }

    /** Build a RestAssured request with a valid Bearer token. */
    protected RequestSpecification givenAuth(String userId) {
        return RestAssured.given()
                .contentType(ContentType.JSON)
                .header("Authorization", "Bearer " + getAuthToken(userId));
    }

    /** Build an unauthenticated RestAssured request. */
    protected RequestSpecification givenNoAuth() {
        return RestAssured.given()
                .contentType(ContentType.JSON);
    }

    // ── Data Seeding Helpers ───────────────────────────────────

    /** Seed a user document and return it. */
    protected UserDocument seedUser(String googleId, String displayName, String email) {
        UserDocument user = UserDocument.builder()
                .googleId(googleId)
                .displayName(displayName)
                .email(email)
                .avatarUrl("https://example.com/avatar/" + googleId + ".png")
                .createdAt(Instant.now())
                .build();
        return userRepository.save(user);
    }

    /** Seed a family group with the given user as ADMIN. Returns the family doc. */
    protected FamilyGroupDocument seedFamily(String userId, String name) {
        FamilyGroupDocument family = FamilyGroupDocument.builder()
                .name(name)
                .avatarInitial(name.substring(0, 1).toUpperCase())
                .defaultCurrency("INR")
                .monthlyBudgetLimit(50000.0)
                .createdByUserId(userId)
                .createdAt(Instant.now())
                .build();
        family = familyGroupRepository.save(family);

        // Add creator as ADMIN member
        FamilyMemberDocument member = FamilyMemberDocument.builder()
                .userId(userId)
                .familyGroupId(family.getId())
                .role("ADMIN")
                .status("ACTIVE")
                .joinedAt(Instant.now())
                .build();
        familyMemberRepository.save(member);

        return family;
    }

    /** Add a user as a regular MEMBER to a family. Returns the member doc. */
    protected FamilyMemberDocument seedMember(String userId, String familyGroupId) {
        FamilyMemberDocument member = FamilyMemberDocument.builder()
                .userId(userId)
                .familyGroupId(familyGroupId)
                .role("MEMBER")
                .status("ACTIVE")
                .joinedAt(Instant.now())
                .build();
        return familyMemberRepository.save(member);
    }

    /** Seed a category for a family. Returns the category doc. */
    protected CategoryDocument seedCategory(String familyGroupId, String name, String icon, double budgetLimit) {
        CategoryDocument category = CategoryDocument.builder()
                .familyGroupId(familyGroupId)
                .name(name)
                .icon(icon)
                .budgetLimit(budgetLimit)
                .color("#6366f1")
                .sortOrder(0)
                .build();
        return categoryRepository.save(category);
    }

    /** Seed a transaction. Returns the transaction doc. */
    protected TransactionDocument seedTransaction(String familyGroupId, String userId,
            String categoryId, double amount,
            String merchant, String type) {
        TransactionDocument tx = TransactionDocument.builder()
                .familyGroupId(familyGroupId)
                .createdByUserId(userId)
                .categoryId(categoryId)
                .amount(amount)
                .currency("INR")
                .merchant(merchant)
                .type(type)
                .sourceType("MANUAL")
                .transactionDate(Instant.now())
                .createdAt(Instant.now())
                .build();
        return transactionRepository.save(tx);
    }

    /** Seed a message document. Returns the message doc. */
    protected MessageDocument seedMessage(String userId, String familyGroupId,
            String sender, String rawText, String status) {
        MessageDocument msg = MessageDocument.builder()
                .userId(userId)
                .familyGroupId(familyGroupId)
                .sender(sender)
                .rawText(rawText)
                .status(status)
                .parseSource("LLM_SERVER")
                .receivedAt(Instant.now())
                .build();
        return messageRepository.save(msg);
    }

    /** Seed an SMS pattern document. Returns the pattern doc. */
    protected SmsPatternDocument seedPattern(String sender, String regex, String sampleMessage) {
        SmsPatternDocument pattern = SmsPatternDocument.builder()
                .sender(sender)
                .regex(regex)
                .extractionMap(Map.of("amount", "amount", "merchant", "merchant", "timestamp", "timestamp"))
                .sampleMessage(sampleMessage)
                .usageCount(1)
                .active(true)
                .reportCount(0)
                .createdAt(Instant.now())
                .build();
        return patternRegistryRepository.save(pattern);
    }
}
