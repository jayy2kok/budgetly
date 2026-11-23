package com.budgetly.api.push;

import java.util.List;

/**
 * Provider-agnostic push transport.
 *
 * <p>The default {@code log} provider keeps local/CI runs self-contained; the
 * {@code fcm} provider delivers through Firebase Cloud Messaging HTTP v1.
 * Business code depends only on this interface — same seam as
 * {@code LlmProvider} for the LLM providers.
 */
public interface PushNotificationService {

    /**
     * Delivers each message on a best-effort basis. A single provider failure
     * must never abort the caller's transaction; implementations log and
     * continue with the remaining messages.
     */
    void send(List<PushMessage> messages);
}
