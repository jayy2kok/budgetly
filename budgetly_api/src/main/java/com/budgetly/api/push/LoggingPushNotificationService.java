package com.budgetly.api.push;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Default provider: writes what would have been sent to the application log.
 * Used locally and in CI, where no FCM credentials exist.
 */
@Slf4j
@Service
@ConditionalOnProperty(name = "push.provider", havingValue = "log", matchIfMissing = true)
public class LoggingPushNotificationService implements PushNotificationService {

    @Override
    public void send(List<PushMessage> messages) {
        if (messages == null || messages.isEmpty()) {
            return;
        }
        messages.forEach(message ->
                log.info("Push (log provider) -> {}: {} | {} | data={}",
                        mask(message.token()), message.title(), message.body(), message.data()));
    }

    /** Never log a full registration token. */
    static String mask(String token) {
        if (token == null || token.length() <= 8) {
            return "***";
        }
        return token.substring(0, 4) + "…" + token.substring(token.length() - 4);
    }
}
