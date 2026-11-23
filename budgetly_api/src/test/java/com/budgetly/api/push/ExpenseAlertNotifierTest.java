package com.budgetly.api.push;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.budgetly.api.document.DeviceTokenDocument;
import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.FamilyMemberDocument;
import com.budgetly.api.document.TransactionDocument;
import com.budgetly.api.document.UserDocument;
import com.budgetly.api.repository.DeviceTokenRepository;
import com.budgetly.api.repository.FamilyGroupRepository;
import com.budgetly.api.repository.FamilyMemberRepository;
import com.budgetly.api.repository.UserRepository;

/**
 * Unit tests for the alert content + recipient selection logic, with a
 * capturing push transport (see {@link CapturingPushService}).
 */
class ExpenseAlertNotifierTest {

    private FamilyGroupRepository familyGroupRepository;
    private FamilyMemberRepository familyMemberRepository;
    private UserRepository userRepository;
    private DeviceTokenRepository deviceTokenRepository;
    private CapturingPushService pushService;
    private ExpenseAlertNotifier notifier;

    @BeforeEach
    void setUp() {
        familyGroupRepository = org.mockito.Mockito.mock(FamilyGroupRepository.class);
        familyMemberRepository = org.mockito.Mockito.mock(FamilyMemberRepository.class);
        userRepository = org.mockito.Mockito.mock(UserRepository.class);
        deviceTokenRepository = org.mockito.Mockito.mock(DeviceTokenRepository.class);
        pushService = new CapturingPushService();
        notifier = new ExpenseAlertNotifier(familyGroupRepository, familyMemberRepository, userRepository,
                deviceTokenRepository, pushService);
    }

    @Test
    void composeAlert_buildsTitleBodyAndRouteData() {
        TransactionDocument tx = TransactionDocument.builder()
                .id("tx-1")
                .familyGroupId("fam-1")
                .amount(1234.5)
                .currency("INR")
                .merchant("DMart")
                .build();

        ExpenseAlertNotifier.AlertContent content =
                ExpenseAlertNotifier.composeAlert("Sharma Family", "Asha", tx);

        assertEquals("New expense in Sharma Family", content.title());
        assertEquals("Asha added 1,234.50 INR at DMart", content.body());
        assertEquals(ExpenseAlertNotifier.DATA_TYPE, content.data().get(ExpenseAlertNotifier.KEY_TYPE));
        assertEquals("tx-1", content.data().get(ExpenseAlertNotifier.KEY_TRANSACTION_ID));
        assertEquals("fam-1", content.data().get(ExpenseAlertNotifier.KEY_FAMILY_GROUP_ID));
    }

    @Test
    void composeAlert_withoutMerchant_omitsTheAtClause() {
        TransactionDocument tx = TransactionDocument.builder()
                .id("tx-2")
                .familyGroupId("fam-1")
                .amount(500.0)
                .currency("INR")
                .build();

        ExpenseAlertNotifier.AlertContent content =
                ExpenseAlertNotifier.composeAlert("Home", "Ravi", tx);

        assertEquals("Ravi added 500 INR", content.body());
    }

    @Test
    void onTransactionCreated_sendsOnlyToOtherActiveMembers() {
        FamilyGroupDocument family = FamilyGroupDocument.builder()
                .id("fam-1")
                .name("Sharma Family")
                .expenseAlertsEnabled(true)
                .build();
        when(familyGroupRepository.findById("fam-1")).thenReturn(Optional.of(family));
        when(familyMemberRepository.findByFamilyGroupId("fam-1")).thenReturn(List.of(
                member("admin", "ACTIVE"),
                member("member", "ACTIVE"),
                member("removed", "REMOVED")));
        when(userRepository.findById("admin"))
                .thenReturn(Optional.of(UserDocument.builder().displayName("Asha").build()));
        when(deviceTokenRepository.findByUserIdIn(List.of("member")))
                .thenReturn(List.of(device("member-token", "member")));

        notifier.onTransactionCreated(expense("tx-3", "fam-1", "EXPENSE"), "admin");

        assertEquals(1, pushService.sent.size());
        assertEquals("member-token", pushService.sent.getFirst().token());
        assertEquals("Asha added 100 INR at Cafe", pushService.sent.getFirst().body());
    }

    @Test
    void onTransactionCreated_skipsNonExpenseAndDisabledFamilies() {
        notifier.onTransactionCreated(expense("tx-4", "fam-1", "INCOME"), "admin");

        FamilyGroupDocument disabled = FamilyGroupDocument.builder()
                .id("fam-2").name("Quiet").expenseAlertsEnabled(false).build();
        when(familyGroupRepository.findById("fam-2")).thenReturn(Optional.of(disabled));
        notifier.onTransactionCreated(expense("tx-5", "fam-2", "EXPENSE"), "admin");

        assertTrue(pushService.sent.isEmpty());
    }

    @Test
    void onTransactionCreated_providerFailureNeverPropagates() {
        FamilyGroupDocument family = FamilyGroupDocument.builder()
                .id("fam-1").name("Family").expenseAlertsEnabled(true).build();
        when(familyGroupRepository.findById("fam-1")).thenReturn(Optional.of(family));
        when(familyMemberRepository.findByFamilyGroupId("fam-1"))
                .thenReturn(List.of(member("member", "ACTIVE")));
        when(deviceTokenRepository.findByUserIdIn(List.of("member")))
                .thenReturn(List.of(device("boom", "member")));
        pushService.failNext = true;

        org.junit.jupiter.api.Assertions.assertDoesNotThrow(
                () -> notifier.onTransactionCreated(expense("tx-6", "fam-1", "EXPENSE"), "admin"));
    }

    private static FamilyMemberDocument member(String userId, String status) {
        return FamilyMemberDocument.builder().userId(userId).status(status).build();
    }

    private static DeviceTokenDocument device(String token, String userId) {
        return DeviceTokenDocument.builder().token(token).userId(userId).build();
    }

    private static TransactionDocument expense(String id, String familyId, String type) {
        return TransactionDocument.builder()
                .id(id)
                .familyGroupId(familyId)
                .amount(100.0)
                .currency("INR")
                .merchant("Cafe")
                .type(type)
                .build();
    }

    /** Records messages, optionally throwing like an unreachable provider. */
    private static final class CapturingPushService implements PushNotificationService {
        private final List<PushMessage> sent = new java.util.ArrayList<>();
        private boolean failNext;

        @Override
        public void send(List<PushMessage> messages) {
            sent.addAll(messages);
            if (failNext) {
                throw new IllegalStateException("provider down");
            }
        }
    }
}
