package com.budgetly.api.push;

import java.util.Map;

/**
 * One provider-ready push message: the destination token plus the visible
 * content and the data payload the client uses to route the tap.
 */
public record PushMessage(String token, String title, String body, Map<String, String> data) {

    public PushMessage {
        data = data == null ? Map.of() : Map.copyOf(data);
    }
}
