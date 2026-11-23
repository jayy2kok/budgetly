package com.budgetly.api.e2e;

import com.budgetly.api.push.PushMessage;
import com.budgetly.api.push.PushNotificationService;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Capturing push transport for E2E tests: records every message instead of
 * calling a real provider, so assertions can inspect tokens and payloads.
 */
public class TestPushNotificationService implements PushNotificationService {

    private final List<PushMessage> sent = Collections.synchronizedList(new ArrayList<>());

    @Override
    public void send(List<PushMessage> messages) {
        if (messages != null) {
            sent.addAll(messages);
        }
    }

    public List<PushMessage> sent() {
        return List.copyOf(sent);
    }

    public void clear() {
        sent.clear();
    }
}
