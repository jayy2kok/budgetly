package com.budgetly.api.push;

import com.budgetly.api.document.DeviceTokenDocument;
import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.FamilyMemberDocument;
import com.budgetly.api.document.TransactionDocument;
import com.budgetly.api.document.UserDocument;
import com.budgetly.api.repository.DeviceTokenRepository;
import com.budgetly.api.repository.FamilyGroupRepository;
import com.budgetly.api.repository.FamilyMemberRepository;
import com.budgetly.api.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.text.DecimalFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Fans an expense out to the other active members of its family when the
 * family's {@code expenseAlertsEnabled} setting is on.
 *
 * <p>Delivery is best-effort by design: a push failure is logged, never
 * propagated, so creating a transaction cannot fail because a device token is
 * stale or the provider is down.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ExpenseAlertNotifier {

    public static final String DATA_TYPE = "EXPENSE_ALERT";
    public static final String KEY_TYPE = "type";
    public static final String KEY_TRANSACTION_ID = "transactionId";
    public static final String KEY_FAMILY_GROUP_ID = "familyGroupId";

    private final FamilyGroupRepository familyGroupRepository;
    private final FamilyMemberRepository familyMemberRepository;
    private final UserRepository userRepository;
    private final DeviceTokenRepository deviceTokenRepository;
    private final PushNotificationService pushNotificationService;

    /** Content of one alert, separated from transport for unit testing. */
    public record AlertContent(String title, String body, Map<String, String> data) {
    }

    public void onTransactionCreated(TransactionDocument transaction, String actorUserId) {
        try {
            if (!shouldNotify(transaction)) {
                return;
            }
            FamilyGroupDocument family = familyGroupRepository
                    .findById(transaction.getFamilyGroupId())
                    .orElse(null);
            if (family == null || !family.isExpenseAlertsEnabled()) {
                return;
            }

            List<String> recipientUserIds = recipientUserIds(family.getId(), actorUserId);
            if (recipientUserIds.isEmpty()) {
                return;
            }

            List<DeviceTokenDocument> tokens = deviceTokenRepository.findByUserIdIn(recipientUserIds);
            if (tokens.isEmpty()) {
                return;
            }

            AlertContent content = composeAlert(family.getName(), actorName(actorUserId), transaction);
            List<PushMessage> messages = tokens.stream()
                    .map(token -> new PushMessage(token.getToken(), content.title(), content.body(), content.data()))
                    .toList();

            pushNotificationService.send(messages);
            log.debug("Dispatched expense alert for transaction {} to {} device(s)",
                    transaction.getId(), messages.size());
        } catch (RuntimeException e) {
            log.warn("Expense alert dispatch failed for transaction {}: {}",
                    transaction == null ? null : transaction.getId(), e.getMessage());
        }
    }

    private static boolean shouldNotify(TransactionDocument transaction) {
        return transaction != null
                && "EXPENSE".equals(transaction.getType())
                && transaction.getFamilyGroupId() != null;
    }

    private List<String> recipientUserIds(String familyGroupId, String actorUserId) {
        return familyMemberRepository.findByFamilyGroupId(familyGroupId).stream()
                .filter(member -> "ACTIVE".equals(member.getStatus()))
                .map(FamilyMemberDocument::getUserId)
                .filter(userId -> userId != null && !userId.equals(actorUserId))
                .distinct()
                .toList();
    }

    private String actorName(String actorUserId) {
        return userRepository.findById(actorUserId)
                .map(UserDocument::getDisplayName)
                .filter(name -> name != null && !name.isBlank())
                .orElse("A family member");
    }

    /** Builds the user-visible title/body and the tap-routing data payload. */
    static AlertContent composeAlert(String familyName, String actorName, TransactionDocument transaction) {
        String merchant = transaction.getMerchant();
        String body = actorName + " added " + formatAmount(transaction)
                + (merchant == null || merchant.isBlank() ? "" : " at " + merchant);

        Map<String, String> data = new LinkedHashMap<>();
        data.put(KEY_TYPE, DATA_TYPE);
        if (transaction.getId() != null) {
            data.put(KEY_TRANSACTION_ID, transaction.getId());
        }
        if (transaction.getFamilyGroupId() != null) {
            data.put(KEY_FAMILY_GROUP_ID, transaction.getFamilyGroupId());
        }

        String title = familyName == null || familyName.isBlank()
                ? "New expense"
                : "New expense in " + familyName;
        return new AlertContent(title, body, Map.copyOf(data));
    }

    private static String formatAmount(TransactionDocument transaction) {
        Double amount = transaction.getAmount();
        java.text.DecimalFormatSymbols symbols = java.text.DecimalFormatSymbols.getInstance(Locale.US);
        String value;
        if (amount == null) {
            value = "0";
        } else if (amount == Math.rint(amount)) {
            value = new DecimalFormat("#,##0", symbols).format(amount);
        } else {
            value = new DecimalFormat("#,##0.00", symbols).format(amount);
        }
        String currency = transaction.getCurrency() == null ? "INR" : transaction.getCurrency();
        return value + " " + currency.toUpperCase(Locale.ROOT);
    }
}
