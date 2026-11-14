package com.budgetly.api.health;

import com.budgetly.api.listener.MessageChangeStreamListener;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

@Component
public class MessageProcessorHealthIndicator implements HealthIndicator {

    private final MessageChangeStreamListener listener;

    public MessageProcessorHealthIndicator(@Autowired(required = false) MessageChangeStreamListener listener) {
        this.listener = listener;
    }

    @Override
    public Health health() {
        if (listener != null && listener.isRunning()) {
            return Health.up().withDetail("status", "Active").build();
        } else {
            return Health.up().withDetail("status", "Not Running/Disabled").build();
        }
    }
}
