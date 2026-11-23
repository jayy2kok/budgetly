package com.budgetly.api.service;

import com.budgetly.api.document.DeviceTokenDocument;
import com.budgetly.api.generated.model.RegisterDeviceRequest;
import com.budgetly.api.repository.DeviceTokenRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;

/**
 * Registration lifecycle for push-notification device tokens.
 *
 * <p>Tokens are keyed by their provider value so a reinstall or a device
 * handed to a different signed-in user moves the token instead of leaving a
 * stale row behind.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DeviceService {

    private final DeviceTokenRepository deviceTokenRepository;

    public void register(String userId, RegisterDeviceRequest request) {
        if (request == null || request.getToken() == null || request.getToken().isBlank()) {
            throw new IllegalArgumentException("token is required");
        }
        if (request.getPlatform() == null) {
            throw new IllegalArgumentException("platform is required");
        }

        String token = request.getToken().trim();
        Instant now = Instant.now();
        DeviceTokenDocument document = deviceTokenRepository.findByToken(token)
                .orElseGet(() -> DeviceTokenDocument.builder()
                        .token(token)
                        .createdAt(now)
                        .build());

        document.setUserId(userId);
        document.setPlatform(request.getPlatform().getValue());
        document.setDeviceId(request.getDeviceId());
        document.setUpdatedAt(now);
        deviceTokenRepository.save(document);
    }

    /**
     * Removes a token on sign-out. Only the owner may delete it; an unknown or
     * foreign token is treated as already removed so logout stays idempotent.
     */
    public void unregister(String userId, String token) {
        if (token == null || token.isBlank()) {
            return;
        }
        deviceTokenRepository.findByToken(token.trim())
                .filter(document -> userId != null && userId.equals(document.getUserId()))
                .ifPresent(deviceTokenRepository::delete);
    }
}
